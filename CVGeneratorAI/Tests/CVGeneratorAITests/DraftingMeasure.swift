import Foundation
import CVGeneratorAI

// What the drafting evaluation (#202) records of one run. These types hold no model and no host call, so they are tested
// everywhere (`DraftingMeasureTests`): the evaluation itself, `DraftingEvaluation`, needs Apple Intelligence.

// MARK: - The claim check, call by call

/// What one call of the claim check did.
struct CheckEvent: Codable, Equatable, Sendable {
    /// How many candidates the call was asked to judge.
    let candidates: Int
    /// How many judgements it answered; nil when it threw.
    let answers: Int?
    let error: String?
    /// Whether the task was cancelled when the call threw: the time of the whole check ran out.
    let cancelled: Bool
}

/// The calls of one claim check, in order.
actor CheckLog {
    private(set) var events: [CheckEvent] = []

    func record(_ event: CheckEvent) {
        events.append(event)
    }
}

/// A claim checker that remembers what each call did, so that a draft whose check gave no answer says why. It changes nothing: the
/// answer, or the error, passes through.
struct CheckRecorder: ClaimChecking {
    let wrapped: any ClaimChecking
    let log: CheckLog

    func judgements(of candidates: [ClaimCandidate], in description: String) async throws -> [ClaimJudgement] {
        do {
            let answer = try await wrapped.judgements(of: candidates, in: description)
            await log.record(CheckEvent(candidates: candidates.count, answers: answer.count, error: nil, cancelled: false))
            return answer
        } catch {
            let cancelled = error is CancellationError || Task.isCancelled
            await log.record(CheckEvent(candidates: candidates.count, answers: nil, error: String(describing: error), cancelled: cancelled))
            throw error
        }
    }
}

/// Why the claim check of a draft gave no answer (ADR 0028), from what its calls did.
enum UncheckedCause: Equatable, Sendable, CustomStringConvertible {
    /// A call threw on its own: the model failed or refused.
    case threw(String)
    /// A call answered with another number of judgements than it had candidates.
    case answerCount(candidates: Int, answers: Int)
    /// No call failed on its own, so the time of the whole check ran out.
    case timedOut
    /// The check was never asked: nothing explains the missing answer.
    case notAsked

    /// The cause of a check that gave no answer: the first call that threw, else the first answer of the wrong length, else (no call
    /// failed on its own) the time that ran out.
    init(events: [CheckEvent]) {
        if let thrown = events.first(where: { $0.error != nil && !$0.cancelled }) {
            self = .threw(thrown.error ?? "")
        } else if let short = events.first(where: { $0.answers != nil && $0.answers != $0.candidates }) {
            self = .answerCount(candidates: short.candidates, answers: short.answers ?? 0)
        } else if events.isEmpty {
            self = .notAsked
        } else {
            self = .timedOut
        }
    }

    var description: String {
        switch self {
        case .threw(let error): "a call threw \(error)"
        case .answerCount(let candidates, let answers): "a call answered \(answers) judgements for \(candidates) candidates"
        case .timedOut: "the time of the check ran out"
        case .notAsked: "the check was never asked"
        }
    }
}

// MARK: - One request

/// One request of the sections and the model's answer to it, before the rules: nil when it gave none.
struct RequestRecord: Encodable, Equatable {
    let step: String
    let answer: [String]?
}

// MARK: - One run

/// One input drafted once: the three drafts, what the check did, and the counts of the final one.
struct DraftMeasure: Encodable {
    /// The revision under test, so that a record read alone says which code it measured.
    let revision: String
    let id: String
    let language: String
    let kind: DraftingInput.Kind
    let run: Int
    let seconds: Double
    let load: Double?
    /// The model's draft, before the rules: the facts of the first pass.
    let raw: CVData?
    /// What the second pass wrote around the facts, before the rules (ADR 0031); nil when it was not asked, failed or wrote nothing.
    let writing: DraftWriting?
    /// Each request of the sections in the order it ran, with what the model answered before any rule: a rejected summary or a
    /// dropped skill shows here and nowhere else.
    let requests: [RequestRecord]
    /// The model's draft after the rules of ADR 0023, before the claim check.
    let grounded: CVData?
    /// What the use case returns, and the app shows.
    let final: CVData?
    /// Whether the claim check gave no answer, so that every personal item was withdrawn.
    let unchecked: Bool
    /// Why it gave none; nil when it did.
    let uncheckedCause: String?
    /// The calls the claim check made.
    let checks: [CheckEvent]
    let error: String?
    /// Whether the use case refused the description: it maps the model's guardrail and refusal to `contentNotAllowed`.
    let refused: Bool
    /// The classes of every field of the final draft, and the expected facts it keeps and loses. A run that threw has no field and
    /// loses every fact.
    let report: InventedFacts.Report
    /// The fields of the model's draft that the counter calls invented: what the rules and the check had to remove.
    let rawInvented: [InventedFacts.Finding]
    /// What the final draft writes around the facts (ADR 0031); nil for a run that gave no draft.
    let written: WrittenMeasure?
    /// Why an example's draft misses the name, the title or a job; empty for the other inputs, and for a run that gave no draft (its
    /// `failure` says why).
    let misses: [String]
    /// Why the run gave no usable draft (it threw, it was refused, or its check gave no answer); nil when it did.
    let failure: String?

    init(
        input: DraftingInput, run: Int, revision: String, seconds: Double, load: Double?, raw: CVData?, writing: DraftWriting? = nil, requests: [RequestRecord] = [],
        grounded: CVData?, result: GeneratedDraft?, error: (any Error)?, checks: [CheckEvent]
    ) {
        self.revision = revision
        id = input.id
        language = input.language
        kind = input.kind
        self.run = run
        self.seconds = seconds
        self.load = load
        self.raw = raw
        self.writing = writing
        self.requests = requests
        self.grounded = grounded
        self.final = result?.cvData
        unchecked = result?.personalItemsUnchecked ?? false
        let cause = unchecked ? UncheckedCause(events: checks) : nil
        uncheckedCause = cause?.description
        self.checks = checks
        self.error = error.map { String(describing: $0) }
        let refused = Self.isRefusal(error)
        self.refused = refused
        let report = InventedFacts.count(result?.cvData ?? CVData(), for: input)
        self.report = report
        rawInvented = raw.map { InventedFacts.count($0, for: input).invented } ?? []
        written = result.map { WrittenMeasure(
            $0.cvData, for: input, report: report, answers: requests.flatMap { $0.answer ?? [] }, wordList: DeviceWordList()
        ) }

        var misses: [String] = []
        if input.kind == .example, result != nil {
            if !report.keeps(.name) { misses.append("lost the name") }
            if !report.keeps(.title) { misses.append("lost the title") }
            if !report.keeps(.employer) { misses.append("kept no job") }
        }
        self.misses = misses

        if refused {
            failure = "refused: the model declined the description (\(error.map { String(describing: $0) } ?? ""))"
        } else if let error {
            failure = "threw \(error)"
        } else if let cause {
            failure = "the claim check gave no answer: \(cause)"
        } else {
            failure = nil
        }
    }

    /// Whether `error` is the use case refusing the description. `FoundationModelsService` maps the model's guardrail violation and
    /// its refusal to `CVGenerationError.contentNotAllowed`, so that is the only refusal a run can show.
    private static func isRefusal(_ error: (any Error)?) -> Bool {
        if let error = error as? CVGenerationError, case .contentNotAllowed = error { return true }
        return false
    }
}
