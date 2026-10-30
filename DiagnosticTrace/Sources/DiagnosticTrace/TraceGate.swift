import Synchronization

/// Whether the trace may record now.
public protocol TraceGate: Sendable {
    var isOpen: Bool { get }
}

/// A gate that never changes: open for a Debug build, which the composition root decides at compile time.
public struct ConstantGate: TraceGate {
    public let isOpen: Bool

    public init(isOpen: Bool) {
        self.isOpen = isOpen
    }
}

/// How the app was installed, as the store's own record of it says.
public enum DistributionAnswer: String, Sendable, CaseIterable {
    /// TestFlight, verified.
    case sandbox
    /// The App Store, verified.
    case production
    /// Run from Xcode, verified.
    case xcode
    /// A record that did not verify.
    case unverified
    /// The record could not be read, such as on an offline first launch.
    case failed
    /// An environment this app does not know.
    case unknown

    /// Whether the trace may record: for a verified TestFlight install only. Everything else fails closed.
    public var allowsTrace: Bool { self == .sandbox }
}

/// Reads how the app was installed (ADR 0032). It reads the record the system already has, and never asks the person to
/// sign in.
public protocol DistributionReading: Sendable {
    func answer() async throws -> DistributionAnswer
}

/// The gate of a Release build: closed until the distribution answers, then open for a verified TestFlight install only.
public final class DistributionGate: TraceGate {
    private let state = Mutex<DistributionAnswer?>(nil)

    public init() {}

    /// The distribution's answer, or nil while it has not answered.
    public var answer: DistributionAnswer? { state.withLock { $0 } }

    public var isOpen: Bool { answer?.allowsTrace ?? false }

    /// Asks the distribution once; an error closes the gate for this launch.
    public func ask(_ distribution: any DistributionReading) async {
        let answer: DistributionAnswer
        do {
            answer = try await distribution.answer()
        } catch {
            answer = .failed
        }
        state.withLock { $0 = answer }
    }
}
