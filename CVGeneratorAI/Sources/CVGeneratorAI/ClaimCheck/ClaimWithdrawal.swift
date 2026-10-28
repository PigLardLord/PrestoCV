import Foundation

/// How much the claim check may ask of the device (ADR 0028): the on-device model reads about one item a second, and a longer prompt
/// answers worse and, past its window, not at all. So the candidates go to the model in batches, and the whole check has a time.
struct ClaimCheckLimits: Equatable, Sendable {
    /// How many candidates one call judges. A batch is small enough for the model to answer every item and for its prompt to fit the
    /// window of the model whatever the description.
    let batchSize: Int
    /// How long the whole check may take, from the first batch to the last. Past it the check gives no answer.
    let time: Duration

    static let standard = ClaimCheckLimits(batchSize: 8, time: .seconds(60))

    /// - Parameter batchSize: At least 1: a smaller number counts as 1.
    init(batchSize: Int, time: Duration) {
        self.batchSize = max(1, batchSize)
        self.time = time
    }
}

/// What the claim check did with a grounded draft: the draft it gave, the candidates it was asked about, the judgement of each when
/// it answered, and why it gave no answer when it did not (ADR 0032).
struct ClaimCheckReport: Equatable, Sendable {
    let draft: GeneratedDraft
    let candidates: [ClaimCandidate]
    /// One for each candidate, in order; empty when the check gave no answer.
    let judgements: [ClaimJudgement]
    /// Why the check gave no answer, or nil when it answered.
    let failure: ClaimCheckFailure?
}

/// Why the claim check gave no answer, as the trace shows it.
struct ClaimCheckFailure: Equatable, Sendable {
    /// `invalidAnswer`, `timedOut`, or the type of what the checker threw.
    let code: String
    /// The error as the framework or the checker describes it, which may quote the model.
    let text: String

    init(_ error: any Error) {
        switch error {
        case ClaimCheckError.invalidAnswer: code = "invalidAnswer"
        case ClaimCheckError.timedOut: code = "timedOut"
        default: code = String(describing: type(of: error))
        }
        text = String(describing: error)
    }
}

/// Applies the claim check to a grounded draft (ADR 0028). It only ever removes: a personal item stays when the check judged it a
/// fact about the writer, and everything the check does not judge (the name, the contacts, the summary, the jobs, the schools,
/// their dates and the certifications) stays as the rules left it.
enum ClaimWithdrawal {
    /// The grounded draft with only the personal items `checker` calls facts. The candidates go to the checker in batches, one after
    /// the other. When the check gives no answer (a failed call, a refusal, an answer that does not judge every item of its batch,
    /// or time that runs out) every personal item it would have judged is withdrawn and the draft says so: never a retry, and
    /// never the rules alone. Cancellation passes through.
    /// - Note: A checker must stop when its task is cancelled, or the time limit cannot cut it short.
    static func checking(_ grounded: CVData, in description: String, with checker: any ClaimChecking,
                         within limits: ClaimCheckLimits = .standard) async throws -> GeneratedDraft {
        try await report(on: grounded, in: description, with: checker, within: limits).draft
    }

    /// What `checking` gives, with what the check said for the trace of a test build (ADR 0032): the candidates, the judgement of
    /// each, and why the check gave no answer when it did not.
    static func report(on grounded: CVData, in description: String, with checker: any ClaimChecking,
                       within limits: ClaimCheckLimits = .standard) async throws -> ClaimCheckReport {
        let candidates = ClaimCandidates.of(grounded)
        guard !candidates.isEmpty else {
            return ClaimCheckReport(draft: GeneratedDraft(cvData: grounded, personalItemsUnchecked: false), candidates: [],
                                    judgements: [], failure: nil)
        }

        do {
            let judgements = try await judgementsInBatches(of: candidates, in: description, with: checker, within: limits)
            let draft = GeneratedDraft(cvData: keepingFacts(of: grounded, candidates: candidates, judgements: judgements),
                                       personalItemsUnchecked: false)
            return ClaimCheckReport(draft: draft, candidates: candidates, judgements: judgements, failure: nil)
        } catch let cancellation as CancellationError {
            throw cancellation
        } catch {
            // A check stopped by a cancellation may report it with an error of its own.
            try Task.checkCancellation()
            return ClaimCheckReport(draft: GeneratedDraft(cvData: withdrawingAll(from: grounded), personalItemsUnchecked: true),
                                    candidates: candidates, judgements: [], failure: ClaimCheckFailure(error))
        }
    }

    /// The judgement of each candidate, from one call of `checker` for each batch, within `limits.time`.
    /// - Throws: `ClaimCheckError.invalidAnswer` for a batch the answer does not judge item by item, `ClaimCheckError.timedOut` when
    ///   the time runs out, and whatever the checker throws.
    private static func judgementsInBatches(of candidates: [ClaimCandidate], in description: String, with checker: any ClaimChecking,
                                            within limits: ClaimCheckLimits) async throws -> [ClaimJudgement] {
        let batches = stride(from: 0, to: candidates.count, by: limits.batchSize).map {
            Array(candidates[$0..<min($0 + limits.batchSize, candidates.count)])
        }
        return try await withThrowingTaskGroup(of: [ClaimJudgement]?.self) { group in
            group.addTask {
                var judgements: [ClaimJudgement] = []
                for batch in batches {
                    let answer = try await checker.judgements(of: batch, in: description)
                    guard answer.count == batch.count else { throw ClaimCheckError.invalidAnswer }
                    judgements += answer
                }
                return judgements
            }
            group.addTask {
                try await Task.sleep(for: limits.time)
                return nil
            }
            defer { group.cancelAll() }

            guard let first = try await group.next(), let judgements = first else { throw ClaimCheckError.timedOut }
            return judgements
        }
    }

    /// The draft without the personal items that the judgements do not call a fact. `judgements` answer `candidates` one for one, in
    /// order; an item that is not a candidate is withdrawn. A language goes with its level.
    static func keepingFacts(of cvData: CVData, candidates: [ClaimCandidate], judgements: [ClaimJudgement]) -> CVData {
        let facts = Set(zip(candidates, judgements).filter { $0.1.stance == .fact }.map(\.0))
        func isFact(_ kind: ClaimCandidate.Kind, _ value: String?) -> Bool {
            ClaimCandidates.candidate(kind, value).map(facts.contains) ?? false
        }
        let info = cvData.personalInfo
        return CVData(
            personalInfo: PersonalInfo(
                name: info.name, email: info.email, phone: info.phone,
                location: isFact(.place, info.location) ? info.location : nil,
                website: info.website, linkedin: info.linkedin, github: info.github,
                title: isFact(.title, info.title) ? info.title : nil
            ),
            summary: cvData.summary, experience: cvData.experience, education: cvData.education,
            skills: cvData.skills.filter { isFact(.skill, $0.name) },
            languages: cvData.languages.filter { isFact(.language, $0.name) },
            certifications: cvData.certifications,
            interests: cvData.interests.filter { isFact(.interest, $0) }
        )
    }

    /// The draft without any of the personal items the check judges, for when it gave no answer: the person adds them by hand.
    static func withdrawingAll(from cvData: CVData) -> CVData {
        keepingFacts(of: cvData, candidates: [], judgements: [])
    }
}
