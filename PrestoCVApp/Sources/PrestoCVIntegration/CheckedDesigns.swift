import Synchronization
import PrestoCVWorkflowPorts
import CVDesignCatalog

/// The check of the bundled designs, as `CheckedDesigns` needs it (R3): the composition root runs it over the design store,
/// the bundled designs and the rendering gate.
public protocol DesignChecking: Sendable {
    /// The designs the store holds and can read now; none when the store cannot be read.
    func installed() async -> [ValidatedDesign]
    /// Checks the bundled designs, the default design first, and tells each one once the store holds its verdict, with the
    /// design the store then holds: none when it did not pass and the store holds no design of that identifier.
    func check(decided: @Sendable (_ id: String, _ design: ValidatedDesign?) async -> Void) async
}

/// The designs as the check has left them so far.
public struct CheckedDesignsSnapshot: Sendable {
    /// The designs a PDF can be made with: the default design first, then the others by identifier.
    public let designs: [ValidatedDesign]
    /// `checking` while the check runs; then `ready` when the default design is among the designs, `unavailable` when not.
    public let status: LookOptionsStatus
    let decided: Set<String>

    /// Whether the design has its verdict: the check told it, or the check is over.
    func isDecided(_ id: String) -> Bool { status != .checking || decided.contains(id) }

    /// Whether the design has its verdict and did not pass, whether or not the rest of the check is over.
    func didNotPass(_ id: String) -> Bool { isDecided(id) && !designs.contains { $0.manifest.id == id } }
}

/// The designs a PDF can be made with while the app is open (#566). The app opens before the bundled designs are checked:
/// the designs the store already holds are offered at once, and each bundled design joins once it passes the check. A
/// design that does not pass is never offered.
/// - The check runs once, in the background, from `start()`; it ends with the check, or when these designs are released.
/// - When the default design does not pass, or the store cannot give it, the status is `unavailable` once the check is
///   over, and `retry()` checks again; a retry that comes while the others are still checked checks again when that check
///   ends. The app still opens: only a PDF cannot be made.
/// - An export waits for its design's verdict (`verdict(on:)`), never for the whole check.
public final class CheckedDesigns: Sendable {
    public let defaultDesign: String
    private let checking: any DesignChecking
    private let shared: Shared

    public init(checking: any DesignChecking, defaultDesign: String) {
        self.checking = checking
        self.defaultDesign = defaultDesign
        shared = Shared()
    }

    deinit {
        let (task, watchers) = shared.state.withLock { state in
            defer { state.watchers = [:] }
            return (state.task, Array(state.watchers.values))
        }
        task?.cancel()
        for watcher in watchers { watcher.finish() }
    }

    /// Starts the check; a second call does nothing.
    public func start() {
        let starts = shared.state.withLock { state in
            guard !state.started else { return false }
            state.started = true
            return true
        }
        if starts { run() }
    }

    /// Checks again when the default design did not pass: at once when the check is over (`unavailable`), or when the check
    /// that still runs ends, and the default design's verdict waits for that check. Does nothing while the default design
    /// has no verdict, or once it passed. The designs offered stay offered.
    public func retry() {
        let retries = shared.state.withLock { state in
            guard state.snapshot(defaultDesign: defaultDesign).didNotPass(defaultDesign) else { return false }
            guard state.status == .unavailable else {
                state.checksAgain = true
                state.decided.remove(defaultDesign)
                state.publish(defaultDesign: defaultDesign)
                return false
            }
            state.status = .checking
            state.decided = Set(state.designs.keys)
            state.publish(defaultDesign: defaultDesign)
            return true
        }
        if retries { run() }
    }

    /// The designs now.
    public var current: CheckedDesignsSnapshot { shared.state.withLock { $0.snapshot(defaultDesign: defaultDesign) } }

    /// The designs now, then again each time they change, each as `transform` makes it; it ends when these designs are
    /// released.
    public func changes<Value: Sendable>(_ transform: @escaping @Sendable (CheckedDesignsSnapshot) -> Value) -> AsyncStream<Value> {
        let (stream, continuation) = AsyncStream.makeStream(of: Value.self, bufferingPolicy: .bufferingNewest(1))
        let id = shared.state.withLock { state in
            let id = state.nextWatcher
            state.nextWatcher += 1
            state.watchers[id] = Watcher(yield: { continuation.yield(transform($0)) }, finish: { continuation.finish() })
            continuation.yield(transform(state.snapshot(defaultDesign: defaultDesign)))
            return id
        }
        continuation.onTermination = { [weak shared] _ in
            _ = shared?.state.withLock { $0.watchers.removeValue(forKey: id) }
        }
        return stream
    }

    /// Returns once the design has its verdict, the check told it or the check is over, and gives that verdict: whether
    /// the design passed. A retry can take the verdict back later, so a caller judges by the verdict it was given, not
    /// by `current`. A cancelled task, or designs released meanwhile, give a `CancellationError`, even when the design has
    /// its verdict. A cancel ends the wait at once, even while the check is stuck, and takes the wait's watcher out
    /// (`changes(_:)` ends with its task).
    @discardableResult @concurrent public func verdict(on id: String) async throws -> Bool {
        for await case let passed? in changes({ $0.isDecided(id) ? !$0.didNotPass(id) : nil }) {
            // The stream still gives the change it holds after a cancel: a cancelled export must not go on to print.
            try Task.checkCancellation()
            return passed
        }
        throw CancellationError()
    }

    private func run() {
        let shared = shared, checking = checking, defaultDesign = defaultDesign
        let task = Task {
            repeat {
                let installed = await checking.installed()
                shared.state.withLock { state in
                    for design in installed { state.designs[design.manifest.id] = design; state.decided.insert(design.manifest.id) }
                    state.publish(defaultDesign: defaultDesign)
                }
                await checking.check { id, design in
                    shared.state.withLock { state in
                        state.designs[id] = design
                        state.decided.insert(id)
                        state.publish(defaultDesign: defaultDesign)
                    }
                }
            } while shared.state.withLock({ $0.endCheck(defaultDesign: defaultDesign) }) && !Task.isCancelled
        }
        shared.state.withLock { $0.task = task }
    }
}

/// What a watcher of the designs is given.
private struct Watcher: Sendable {
    let yield: @Sendable (CheckedDesignsSnapshot) -> Void
    let finish: @Sendable () -> Void
}

/// The state the check's task and the watchers share; the task holds it, not the designs, so that releasing the designs
/// stops the check.
private final class Shared: Sendable {
    struct State {
        var started = false
        var status = LookOptionsStatus.checking
        var designs: [String: ValidatedDesign] = [:]
        var decided: Set<String> = []
        /// A retry came while the check ran: the check runs again when it ends.
        var checksAgain = false
        var watchers: [Int: Watcher] = [:]
        var nextWatcher = 0
        var task: Task<Void, Never>?

        func snapshot(defaultDesign: String) -> CheckedDesignsSnapshot {
            let ordered = designs.values.sorted { first, second in
                let firstID = first.manifest.id, secondID = second.manifest.id
                if (firstID == defaultDesign) != (secondID == defaultDesign) { return firstID == defaultDesign }
                return firstID < secondID
            }
            return CheckedDesignsSnapshot(designs: ordered, status: status, decided: decided)
        }

        /// Ends a check and returns whether it runs again: after a retry that came while it ran, the designs that did not
        /// pass wait for their verdicts again; otherwise the status follows the default design.
        mutating func endCheck(defaultDesign: String) -> Bool {
            defer { publish(defaultDesign: defaultDesign) }
            guard checksAgain else {
                status = designs[defaultDesign] == nil ? .unavailable : .ready
                return false
            }
            checksAgain = false
            decided = Set(designs.keys)
            return true
        }

        /// Tells every watcher, under the lock, so that they see the changes in order.
        func publish(defaultDesign: String) {
            let now = snapshot(defaultDesign: defaultDesign)
            for watcher in watchers.values { watcher.yield(now) }
        }
    }

    let state = Mutex(State())
}
