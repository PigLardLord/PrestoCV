import Foundation
import CVGeneratorAI

/// A scripted claim check (ADR 0028) for view model tests: it calls every personal item a fact, or fails as a check that gives no
/// answer.
struct FakeClaimChecker: ClaimChecking {
    struct Failure: Error {}

    var fails = false

    func judgements(of candidates: [ClaimCandidate], in description: String) async throws -> [ClaimJudgement] {
        if fails { throw Failure() }
        return candidates.map { _ in ClaimJudgement(stance: .fact, quote: "") }
    }
}
