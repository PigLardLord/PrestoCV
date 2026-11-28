import DiagnosticLogging
import Synchronization

/// Where the trace of the launches of one process stands. A launch purges what an earlier install stored once the
/// distribution has answered; a failed launch returns before that, and a retry then starts a new launch over the same
/// folders. The settlement lets the new launch's trace chain wait for the one before it: it records nothing until the
/// earlier launch's trace has settled, so that the purge of an earlier launch never removes what a later launch wrote
/// (ADR 0032). The holder makes one and hands it to every launch it starts; no launch waits on it, only the trace.
///
/// It also holds what a launch starts that must outlive a failed launch: the listener of the store's tip transactions
/// (ADR 0040), which the first launch makes and starts and a retry finds again.
public final class TraceSettlement: Sendable {
    private let last = Mutex<Task<Void, Never>?>(nil)
    private let tips = Mutex<(any TipsListening)?>(nil)
    private let traceLogger = Mutex<(any DiagnosticLogger)?>(nil)

    public init() {}

    /// The task that ends when the last launch's trace has settled, or none for the first launch
    func previous() -> Task<Void, Never>? {
        last.withLock { $0 }
    }

    /// Makes `startup` the task the next launch waits for, and `logger` the logger of that launch's trace: the one the
    /// tips listener's entries go to from now on (`tipsLogger`)
    func record(_ startup: Task<Void, Never>, logger: any DiagnosticLogger) {
        last.withLock { $0 = startup }
        traceLogger.withLock { $0 = logger }
    }

    /// The logger of the tips listener. The listener starts before any trace exists, so until a launch has made its trace the
    /// entries go to `fallback`, the unified log only; once a launch has recorded its trace they go to that trace's logger,
    /// which mirrors them into the session events, and a later launch's trace takes over from the earlier one.
    func tipsLogger(fallback: any DiagnosticLogger) -> any DiagnosticLogger {
        SettlementLogger(settlement: self, fallback: fallback)
    }

    fileprivate func currentTraceLogger() -> (any DiagnosticLogger)? {
        traceLogger.withLock { $0 }
    }

    /// The listener of this process: made and started by the first launch, which asks, and given back to every later one
    func tipsListener(make: () -> any TipsListening) -> any TipsListening {
        tips.withLock { held in
            if let held { return held }
            let made = make()
            made.start()
            held = made
            return made
        }
    }

    /// Returns once every launch so far has settled its trace: each launch's startup ends after the one before it
    @concurrent public func settled() async {
        await previous()?.value
    }
}

/// Forwards each entry to the trace logger the settlement holds at that moment, or to `fallback` when there is none yet.
private struct SettlementLogger: DiagnosticLogger {
    let settlement: TraceSettlement
    let fallback: any DiagnosticLogger

    func log(_ entry: LogEntry) {
        (settlement.currentTraceLogger() ?? fallback).log(entry)
    }
}
