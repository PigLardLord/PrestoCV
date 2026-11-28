import Synchronization
import PrestoCVWorkflowPorts
import PrestoCVIntegration
import CVDesignCatalog

/// A check of the designs that a test drives: the designs it holds come at once, then each verdict the test tells, until
/// the test ends the check. A check that runs again goes on with what the test tells next.
final class DrivenChecking: DesignChecking {
    enum Step: Sendable {
        case verdict(id: String, design: ValidatedDesign?)
        case end
    }

    private let held: [ValidatedDesign]
    private let steps: AsyncStream<Step>, next: AsyncStream<Step>.Continuation
    private let runs = Mutex(0)

    init(holding held: [ValidatedDesign]) {
        self.held = held
        (steps, next) = AsyncStream.makeStream(of: Step.self)
    }

    /// How many checks have started.
    var checks: Int { runs.withLock { $0 } }

    func installed() async -> [ValidatedDesign] { held }

    func check(decided: @Sendable (_ id: String, _ design: ValidatedDesign?) async -> Void) async {
        runs.withLock { $0 += 1 }
        for await step in steps {
            switch step {
            case .verdict(let id, let design): await decided(id, design)
            case .end: return
            }
        }
    }

    /// The check's verdict on one design: the design the store then holds, or none.
    func tell(_ id: String, _ design: ValidatedDesign?) { next.yield(.verdict(id: id, design: design)) }

    /// Ends the check that runs, or the next one.
    func endCheck() { next.yield(.end) }
}

/// The first snapshot of the designs that meets `condition`; none when the designs are released first.
func first(_ designs: CheckedDesigns, where condition: @escaping @Sendable (CheckedDesignsSnapshot) -> Bool) async -> CheckedDesignsSnapshot? {
    for await snapshot in designs.changes({ $0 }) where condition(snapshot) { return snapshot }
    return nil
}

/// Designs whose check is over, with the designs given held from the start.
func checkedDesigns(holding held: [ValidatedDesign], defaultDesign: String) async -> CheckedDesigns {
    let checking = DrivenChecking(holding: held)
    let designs = CheckedDesigns(checking: checking, defaultDesign: defaultDesign)
    designs.start()
    checking.endCheck()
    _ = await first(designs) { $0.status != .checking }
    return designs
}
