import Observation

/// Holds the composition the app shows and can launch it again after a failure. A `Task` runs once and returns the same
/// value on every read, so the app keeps this instead: it owns the current launch, starts a new one only after a failure,
/// and runs one launch at a time, so that a double tap on retry makes one composition (R4, ADR 0008).
@MainActor
@Observable
public final class CompositionHolder {
    /// Where the app's composition stands
    public enum Phase {
        case launching
        case ready(Composition)
        case failed(CompositionFailure)
    }

    public private(set) var phase = Phase.launching

    private var started = false
    private let launch: @Sendable () async -> CompositionState

    public init(launch: @escaping @Sendable () async -> CompositionState) {
        self.launch = launch
    }

    /// Starts the first launch. Later calls change nothing.
    public func start() {
        guard !started else { return }
        started = true
        run()
    }

    /// Starts a new launch when the last one failed and none runs. In any other phase it changes nothing.
    public func retry() {
        guard case .failed = phase else { return }
        run()
    }

    private func run() {
        phase = .launching
        Task {
            switch await launch() {
            case .ready(let composition): phase = .ready(composition)
            case .failed(let failure): phase = .failed(failure)
            }
        }
    }
}
