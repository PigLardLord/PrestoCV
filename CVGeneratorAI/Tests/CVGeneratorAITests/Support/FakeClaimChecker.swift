import Foundation
@testable import CVGeneratorAI

/// A scripted claim check that records what it was asked. Each candidate gets the stance given for its value, and `fact`
/// otherwise; it can fail instead, after cancelling the task that asked, or answer only the first candidates.
actor FakeClaimChecker: ClaimChecking {
    struct Call: Equatable {
        let candidates: [ClaimCandidate]
        let description: String
    }

    private let stances: [String: ClaimStance]
    private let failure: (any Error)?
    private let verdictLimit: Int?
    private let cancelsItsTask: Bool

    private(set) var calls: [Call] = []

    /// - Parameters:
    ///   - stances: The stance of each value; a value not listed is a fact.
    ///   - failure: What the check throws, if it fails.
    ///   - verdictLimit: How many candidates the answer judges, from the first; all when nil.
    ///   - cancelsItsTask: Whether the check cancels the task that asked before it answers, as a person leaving the screen does.
    init(stances: [String: ClaimStance] = [:], failure: (any Error)? = nil, verdictLimit: Int? = nil, cancelsItsTask: Bool = false) {
        self.stances = stances
        self.failure = failure
        self.verdictLimit = verdictLimit
        self.cancelsItsTask = cancelsItsTask
    }

    func judgements(of candidates: [ClaimCandidate], in description: String) async throws -> [ClaimJudgement] {
        calls.append(Call(candidates: candidates, description: description))
        if cancelsItsTask { withUnsafeCurrentTask { $0?.cancel() } }
        if let failure { throw failure }
        let judgements = candidates.map { ClaimJudgement(stance: stances[$0.value] ?? .fact, quote: "") }
        return verdictLimit.map { Array(judgements.prefix($0)) } ?? judgements
    }
}
