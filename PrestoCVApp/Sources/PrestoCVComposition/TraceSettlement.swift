import Synchronization

/// Where the trace of the launches of one process stands. A launch purges what an earlier install stored once the
/// distribution has answered; a failed launch returns before that, and a retry then starts a new launch over the same
/// folders. The settlement lets the new launch's trace chain wait for the one before it: it records nothing until the
/// earlier launch's trace has settled, so that the purge of an earlier launch never removes what a later launch wrote
/// (ADR 0032). The holder makes one and hands it to every launch it starts; no launch waits on it, only the trace.
public final class TraceSettlement: Sendable {
    private let last = Mutex<Task<Void, Never>?>(nil)

    public init() {}

    /// The task that ends when the last launch's trace has settled, or none for the first launch
    func previous() -> Task<Void, Never>? {
        last.withLock { $0 }
    }

    /// Makes `startup` the task the next launch waits for
    func record(_ startup: Task<Void, Never>) {
        last.withLock { $0 = startup }
    }

    /// Returns once every launch so far has settled its trace: each launch's startup ends after the one before it
    @concurrent public func settled() async {
        await previous()?.value
    }
}
