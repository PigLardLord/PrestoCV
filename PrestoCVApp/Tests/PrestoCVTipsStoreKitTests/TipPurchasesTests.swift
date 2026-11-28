#if canImport(StoreKit)
import DiagnosticLogging
import Foundation
import PrestoCVWorkflowPorts
import StoreKit
import Synchronization
import Testing
@testable import PrestoCVTipsStoreKit

@Suite("The purchase of a tip")
struct TipPurchasesTests {
    @Test("a tip the store verified is finished and goes through, and only its outcome is logged")
    func verifiedIsFinished() async throws {
        let logger = KeptLogger()
        let finishes = Finishes()

        let ended = try await TipPurchases.settle(.bought(finishes.transaction(isVerified: true)), logger: logger)

        #expect(ended == .completed)
        #expect(finishes.count == 1)
        #expect(logger.entries.map(\.event.description) == ["tips.purchase.ended"])
        #expect(logger.entries.first?.fields == [.token("outcome", "completed")])
    }

    @Test("a tip the store did not verify is finished too, grants nothing and does not go through")
    func unverifiedIsFinished() async {
        let logger = KeptLogger()
        let finishes = Finishes()

        await #expect(throws: TipFailure.failed) {
            try await TipPurchases.settle(.bought(finishes.transaction(isVerified: false)), logger: logger)
        }

        #expect(finishes.count == 1)
        #expect(logger.entries.first?.fields == [.token("outcome", "unverified")])
    }

    @Test("a purchase that sold nothing finishes nothing, and its outcome is logged by its code")
    func nothingSold() async {
        let cases: [(TipPurchaseAnswer, Result<TipPurchase, TipFailure>, LogField)] = [
            (.cancelled, .success(.cancelled), .token("outcome", "cancelled")),
            (.pending, .success(.pending), .token("outcome", "pending")),
            (.refused(.notAllowed), .failure(.notAllowed), .token("outcome", "notAllowed")),
            (.refused(.unreachable), .failure(.unreachable), .token("outcome", "unreachable")),
            (.refused(.failed), .failure(.failed), .token("outcome", "failed")),
        ]
        for (answer, expected, field) in cases {
            let logger = KeptLogger()

            let ended: Result<TipPurchase, TipFailure>
            do throws(TipFailure) {
                ended = .success(try await TipPurchases.settle(answer, logger: logger))
            } catch {
                ended = .failure(error)
            }

            #expect(ended == expected)
            #expect(logger.entries.first?.fields == [field])
        }
    }

    @Test("what the store throws reads as the port's answer")
    func storeErrors() {
        #expect(TipPurchases.answer(to: StoreKitError.userCancelled).code == "cancelled")
        #expect(TipPurchases.answer(to: Product.PurchaseError.purchaseNotAllowed).code == "refused notAllowed")
        let offline = StoreKitError.networkError(URLError(.notConnectedToInternet))
        #expect(TipPurchases.answer(to: offline).code == "refused unreachable")
        #expect(TipPurchases.answer(to: Product.PurchaseError.productUnavailable).code == "refused failed")
        #expect(TipPurchases.answer(to: StoreKitError.unknown).code == "refused failed")
        #expect(TipPurchases.answer(to: URLError(.timedOut)).code == "refused failed")
    }
}

extension TipPurchaseAnswer {
    /// What a test compares: the answer without its transaction.
    fileprivate var code: String {
        switch self {
        case .bought: "bought"
        case .cancelled: "cancelled"
        case .pending: "pending"
        case .refused(let failure): "refused \(failure)"
        }
    }
}

/// Counts the transactions finished.
private final class Finishes: Sendable {
    private let finished = Mutex(0)
    var count: Int { finished.withLock { $0 } }

    func transaction(isVerified: Bool) -> TipTransaction {
        TipTransaction(id: 1, isVerified: isVerified, finish: { self.finished.withLock { $0 += 1 } })
    }
}

/// Keeps every entry logged.
private final class KeptLogger: DiagnosticLogger {
    private let kept = Mutex<[LogEntry]>([])
    var entries: [LogEntry] { kept.withLock { $0 } }

    func log(_ entry: LogEntry) { kept.withLock { $0.append(entry) } }
}
#endif
