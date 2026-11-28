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
}

/// The designs a PDF can be made with while the app is open (#566). The app opens before the bundled designs are checked:
/// the designs the store already holds are offered at once, and each bundled design joins once it passes the check. A
/// design that does not pass is never offered.
/// - The check runs once, in the background, from `start()`; it ends with the check, or when these designs are released.
/// - When the default design does not pass, or the store cannot give it, the status is `unavailable`, and `retry()` checks
///   again. The app still opens: only a PDF cannot be made.
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

    /// Checks again when the default design did not pass (`unavailable`); does nothing while a check runs or after one
    /// passed. The designs offered stay offered.
    public func retry() {
        let retries = shared.state.withLock { state in
            guard state.status == .unavailable else { return false }
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

    /// Returns once the design has its verdict: the check told it, or the check is over. A cancelled task, or designs
    /// released meanwhile, give a `CancellationError`.
    @concurrent public func verdict(on id: String) async throws {
        for await decided in changes({ $0.isDecided(id) }) where decided { return }
        throw CancellationError()
    }

    private func run() {
        let shared = shared, checking = checking, defaultDesign = defaultDesign
        let task = Task {
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
            shared.state.withLock { state in
                state.status = state.designs[defaultDesign] == nil ? .unavailable : .ready
                state.publish(defaultDesign: defaultDesign)
            }
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

        /// Tells every watcher, under the lock, so that they see the changes in order.
        func publish(defaultDesign: String) {
            let now = snapshot(defaultDesign: defaultDesign)
            for watcher in watchers.values { watcher.yield(now) }
        }
    }

    let state = Mutex(State())
}
