#if canImport(StoreKit)
import DiagnosticTrace
import StoreKit

/// Asks StoreKit how this copy of the app was installed (ADR 0032). TestFlight installs are signed for the sandbox, App
/// Store installs for production. It reads the cached transaction and never refreshes it, so it never asks the person to
/// sign in. An answer StoreKit cannot verify is `unverified`, which keeps the trace off.
public struct AppTransactionDistribution: DistributionReading {
    public init() {}

    public func answer() async throws -> DistributionAnswer {
        switch try await AppTransaction.shared {
        case .verified(let transaction): Self.answer(for: transaction.environment)
        case .unverified: .unverified
        }
    }

    static func answer(for environment: AppStore.Environment) -> DistributionAnswer {
        switch environment {
        case .sandbox: .sandbox
        case .production: .production
        case .xcode: .xcode
        default: .unknown
        }
    }
}
#endif
