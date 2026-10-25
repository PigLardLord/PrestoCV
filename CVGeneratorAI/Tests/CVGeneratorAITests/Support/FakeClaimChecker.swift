import Foundation
@testable import CVGeneratorAI

/// A scripted claim check that records what it was asked. Each candidate gets the stance given for its value, and `fact`
/// otherwise. After the first `afterCalls` calls it can misbehave: fail, answer only the first candidates, or never answer.
actor FakeClaimChecker: ClaimChecking {
    struct Call: Equatable {
        let candidates: [ClaimCandidate]
        let description: String
    }

    private let stances: [String: ClaimStance]
    private let failure: (any Error)?
    private let verdictLimit: Int?
    private let hangs: Bool
    private let afterCalls: Int
    private let whenAsked: (@Sendable () -> Void)?

    private(set) var calls: [Call] = []

    /// - Parameters:
    ///   - stances: The stance of each value; a value not listed is a fact.
    ///   - failure: What the check throws, if it fails. With `hangs`, what it throws once its task is cancelled.
    ///   - verdictLimit: How many candidates the answer judges, from the first; all when nil.
    ///   - hangs: Whether the check waits until its task is cancelled instead of answering, as a model that never finishes does. It
    ///     then throws `failure`, or the cancellation.
    ///   - afterCalls: How many calls answer in full before `failure`, `verdictLimit` and `hangs` apply.
    ///   - whenAsked: Run at each call, as soon as it is recorded.
    init(stances: [String: ClaimStance] = [:], failure: (any Error)? = nil, verdictLimit: Int? = nil, hangs: Bool = false,
         afterCalls: Int = 0, whenAsked: (@Sendable () -> Void)? = nil) {
        self.stances = stances
        self.failure = failure
        self.verdictLimit = verdictLimit
        self.hangs = hangs
        self.afterCalls = afterCalls
        self.whenAsked = whenAsked
    }

    func judgements(of candidates: [ClaimCandidate], in description: String) async throws -> [ClaimJudgement] {
        calls.append(Call(candidates: candidates, description: description))
        whenAsked?()
        let misbehaves = calls.count > afterCalls
        if misbehaves, hangs {
            do { try await Task.sleep(for: .seconds(3600)) } catch { throw failure ?? error }
        }
        if misbehaves, let failure { throw failure }
        let judgements = candidates.map { ClaimJudgement(stance: stances[$0.value] ?? .fact, quote: "") }
        return misbehaves ? verdictLimit.map { Array(judgements.prefix($0)) } ?? judgements : judgements
    }
}
