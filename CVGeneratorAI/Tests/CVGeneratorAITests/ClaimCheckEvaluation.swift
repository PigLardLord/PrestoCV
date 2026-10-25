#if canImport(FoundationModels)
import Testing
import Foundation
import FoundationModels
@testable import CVGeneratorAI

// The claim check of ADR 0028 on the real on-device model. It runs only when PRESTOCV_CLAIM_EVAL names the parts to run ("a", "b",
// "c", "d", "e", in any combination), on an Apple host with Apple Intelligence, and writes what it measured as JSON to the folder
// PRESTOCV_CLAIM_EVAL_OUT, a summary per part and the verdicts of every run.
//
// - composed, the default: the path of the product. The rules ground the draft, the check judges the personal items they keep in
//   batches within its time, and the withdrawal applies its verdicts (`ClaimWithdrawal.checking`). An item the description does not
//   claim that the result keeps is a false keep, and fails the run, in every part. A check that gives no answer (an `unchecked`
//   draft) keeps no personal item, so it is counted, never a false keep; so is a fact the quote proof demoted (`quoteDrops`).
// - alone (PRESTOCV_CLAIM_EVAL_MODE=alone): the check judges every listed item without the rules, as when the instruction is tuned. A
//   false keep fails (b), (c) and (d); on (a) it is measured only, since the rules drop those items before the check.
//
// Part (e) is drafts of 22, 32 and 42 personal items: the batching and the time limit of the check at the size of a long CV.
//
// Every part runs three times (PRESTOCV_CLAIM_EVAL_RUNS), and its verdicts must be the same each time.

private let environment = ProcessInfo.processInfo.environment
private let evaluation = environment["PRESTOCV_CLAIM_EVAL"] ?? ""
private let outputFolder = URL(fileURLWithPath: environment["PRESTOCV_CLAIM_EVAL_OUT"] ?? NSTemporaryDirectory())
private let alone = environment["PRESTOCV_CLAIM_EVAL_MODE"] == "alone"
private let runs = environment["PRESTOCV_CLAIM_EVAL_RUNS"].flatMap(Int.init) ?? 3

@Suite("Claim check evaluation: ADR 0028", .serialized, .enabled(if: !evaluation.isEmpty))
struct ClaimCheckEvaluation {
    @Test("(a) the contract: every personal item that a row keeps or drops")
    func contract() async throws {
        guard evaluation.contains("a") else { return }
        let cases = GroundingRows.all.compactMap { row -> EvaluationCase? in
            guard let items = ClaimItems.expectation(of: row), !items.isEmpty else { return nil }
            let tag = row.id.contains("accepted-loss") ? "accepted-loss" : (GroundingRows.notImplementedYet.contains(row.id) ? "known-issue" : "")
            return EvaluationCase(id: row.id, language: row.language, tag: tag, description: row.description, draft: row.draft, items: items)
        }
        try await measure("contract", cases, falseKeepsFail: !alone)
    }

    @Test("(b) the adversarial set")
    func adversarial() async throws {
        guard evaluation.contains("b") else { return }
        try await measure("adversarial", AdversarialSet.sentences.map(EvaluationCase.init), falseKeepsFail: true)
    }

    @Test("(c) the held-out set the instruction of the spike was chosen on")
    func heldOut() async throws {
        guard evaluation.contains("c") else { return }
        try await measure("heldout", AdversarialSet.heldOut.map(EvaluationCase.init), falseKeepsFail: true)
    }

    @Test("(d) the held-out set written after the instruction was frozen")
    func frozenHeldOut() async throws {
        guard evaluation.contains("d") else { return }
        try await measure("frozen", AdversarialSet.frozenHeldOut.map(EvaluationCase.init), falseKeepsFail: true)
    }

    @Test("(e) long drafts of 22, 32 and 42 personal items")
    func longDrafts() async throws {
        guard evaluation.contains("e") else { return }
        try await measure("long", AdversarialSet.longDrafts.map(EvaluationCase.init), falseKeepsFail: true)
    }

    // MARK: - Measuring

    private func measure(_ name: String, _ cases: [EvaluationCase], falseKeepsFail: Bool) async throws {
        var verdicts: [[MeasuredDraft]] = []
        for run in 1...runs {
            var drafts: [MeasuredDraft] = []
            for evaluationCase in cases {
                drafts.append(await alone ? Self.judgeAlone(evaluationCase) : Self.judgeComposed(evaluationCase))
            }
            try write(drafts, to: "\(name)-run\(run).json")
            verdicts.append(drafts)
        }
        let summary = Summary(name: name, mode: alone ? "alone" : "composed", runs: verdicts)
        try write(summary, to: "\(name)-summary.json")

        #expect(summary.sameInEveryRun, "\(name): the verdicts differ between runs")
        if falseKeepsFail {
            #expect(summary.falseKeeps.isEmpty, "\(name): false keeps \(summary.falseKeeps)")
        }
    }

    /// The path of the product: the rules, then the check of what they keep, then the withdrawal.
    private static func judgeComposed(_ evaluationCase: EvaluationCase) async -> MeasuredDraft {
        let checker = RecordingClaimChecker()
        let start = ContinuousClock.now
        let grounded: CVData
        let checked: GeneratedDraft
        do {
            grounded = try CVDataSanitizer().sanitize(evaluationCase.draft, against: evaluationCase.description)
            checked = try await ClaimWithdrawal.checking(grounded, in: evaluationCase.description, with: checker)
        } catch {
            return MeasuredDraft(evaluationCase, items: [], seconds: seconds(since: start), error: error, unchecked: false)
        }
        let seconds = seconds(since: start)
        let judged = await checker.judged
        let groundedItems = ClaimCandidates.of(grounded), keptItems = ClaimCandidates.of(checked.cvData)

        let modelStances = await checker.modelStances

        let items = evaluationCase.items.map { item in
            let verdict: String, quote: String, modelStance: String
            if let candidate = groundedItems.first(where: { ClaimItems.overlaps($0, item.candidate) }) {
                let judgement = judged[candidate]
                // The batches that were answered before the check gave up count for nothing: no item stays.
                verdict = checked.personalItemsUnchecked ? "unchecked" : (judgement?.stance.rawValue ?? "missing")
                quote = judgement?.quote ?? ""
                modelStance = modelStances[candidate]?.rawValue ?? ""
            } else {
                verdict = "rules"
                quote = ""
                modelStance = ""
            }
            return MeasuredItem(item, verdict: verdict, quote: quote, modelStance: modelStance,
                                kept: keptItems.contains { ClaimItems.overlaps($0, item.candidate) })
        }
        return MeasuredDraft(evaluationCase, items: items, seconds: seconds, error: await checker.failure,
                             unchecked: checked.personalItemsUnchecked)
    }

    /// The check alone, on every listed item.
    private static func judgeAlone(_ evaluationCase: EvaluationCase) async -> MeasuredDraft {
        let start = ContinuousClock.now
        do {
            let candidates = evaluationCase.items.map(\.candidate)
            var judgements: [ClaimJudgement] = []
            for first in stride(from: 0, to: candidates.count, by: ClaimCheckLimits.standard.batchSize) {
                let batch = Array(candidates[first..<min(first + ClaimCheckLimits.standard.batchSize, candidates.count)])
                judgements += try await FoundationModelsClaimChecker().judgements(of: batch, in: evaluationCase.description)
            }
            let items = zip(evaluationCase.items, judgements).map { item, judgement in
                MeasuredItem(item, verdict: judgement.stance.rawValue, quote: judgement.quote, modelStance: "", kept: judgement.stance == .fact)
            }
            return MeasuredDraft(evaluationCase, items: items, seconds: seconds(since: start), error: nil, unchecked: false)
        } catch {
            let items = evaluationCase.items.map { MeasuredItem($0, verdict: "error", quote: "", modelStance: "", kept: false) }
            return MeasuredDraft(evaluationCase, items: items, seconds: seconds(since: start), error: error, unchecked: true)
        }
    }

    private func write(_ value: some Encodable, to name: String) throws {
        try FileManager.default.createDirectory(at: outputFolder, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(value).write(to: outputFolder.appendingPathComponent(name))
    }

    private static func seconds(since start: ContinuousClock.Instant) -> Double {
        let (whole, attoseconds) = (ContinuousClock.now - start).components
        return Double(whole) + Double(attoseconds) / 1e18
    }
}

// MARK: - What is measured

/// A description, the draft a model could write from it, and whether the writer claims each personal item of that draft.
struct EvaluationCase {
    let id: String
    let language: String
    let tag: String
    let description: String
    let draft: CVData
    let items: [(candidate: ClaimCandidate, claimed: Bool)]

    init(id: String, language: String, tag: String, description: String, draft: CVData, items: [(candidate: ClaimCandidate, claimed: Bool)]) {
        self.id = id
        self.language = language
        self.tag = tag
        self.description = description
        self.draft = draft
        self.items = items
    }

    /// A sentence of a hand-written set, with the draft that holds its items.
    init(_ sentence: AdversarialSet.Sentence) {
        let candidates = sentence.items.map(\.candidate)
        func values(_ kind: ClaimCandidate.Kind) -> [String] { candidates.filter { $0.kind == kind }.map(\.value) }
        self.init(
            id: sentence.id, language: sentence.language, tag: "", description: sentence.description,
            draft: CVData(
                personalInfo: PersonalInfo(location: values(.place).first, title: values(.title).first),
                skills: values(.skill).map { Skill(name: $0) },
                languages: values(.language).map { Language(name: $0) },
                interests: values(.interest)
            ),
            items: sentence.items
        )
    }
}

struct MeasuredItem: Encodable, Equatable {
    let kind: String
    let value: String
    let claimed: Bool
    /// The stance of the check; "rules" when the rules dropped the item before the check, "unchecked" or "error" when the check gave
    /// no answer.
    let verdict: String
    let quote: String
    /// The stance the model gave, before its quote was proved (`ClaimAnswer`); empty when it is not known.
    let modelStance: String
    let kept: Bool

    init(_ item: (candidate: ClaimCandidate, claimed: Bool), verdict: String, quote: String, modelStance: String, kept: Bool) {
        kind = item.candidate.kind.rawValue
        value = item.candidate.value
        claimed = item.claimed
        self.verdict = verdict
        self.quote = quote
        self.modelStance = modelStance
        self.kept = kept
    }

    /// A fact of the model that the proof of its quote turned into "not mentioned".
    var droppedByItsQuote: Bool { modelStance == ClaimStance.fact.rawValue && verdict == ClaimStance.notMentioned.rawValue }
}

struct MeasuredDraft: Encodable, Equatable {
    let id: String
    let language: String
    let tag: String
    let items: [MeasuredItem]
    let seconds: Double
    let error: String?
    /// Whether the model's guardrail refused the description.
    let refused: Bool
    /// Whether the check gave no answer, so that the draft lost every personal item it judges.
    let unchecked: Bool

    init(_ evaluationCase: EvaluationCase, items: [MeasuredItem], seconds: Double, error: (any Error)?, unchecked: Bool) {
        id = evaluationCase.id
        language = evaluationCase.language
        tag = evaluationCase.tag
        self.items = items
        self.seconds = seconds
        self.error = error.map { String(describing: $0) }
        self.unchecked = unchecked
        refused = error.map(Self.isGuardrailRefusal) ?? false
    }

    /// Whether `error` is the model's guardrail refusing the description. macOS 27 throws `LanguageModelError`; its older
    /// `LanguageModelSession.GenerationError` is what earlier systems throw.
    private static func isGuardrailRefusal(_ error: any Error) -> Bool {
        if #available(macOS 27.0, iOS 27.0, *), let modelError = error as? LanguageModelError, case .guardrailViolation = modelError {
            return true
        }
        if let generationError = error as? LanguageModelSession.GenerationError, case .guardrailViolation = generationError {
            return true
        }
        return false
    }

    /// The verdicts and what they kept, without the quotes and the time they took.
    var verdicts: [String] { items.map { "\($0.kind)|\($0.value)|\($0.verdict)|\($0.kept)" } + [error == nil ? "" : "error", unchecked ? "unchecked" : ""] }
}

struct Summary: Encodable {
    let name: String
    let mode: String
    let runs: Int
    let drafts: Int
    let items: Int
    let claimed: Int
    /// "<draft id>: <kind> <value>" for each item the writer does not claim that the result keeps.
    let falseKeeps: [String]
    /// Claimed items the check withdrew, not counting those of an unchecked draft.
    let falseDrops: [String]
    /// Claimed items whose fact the proof of the quote turned into "not mentioned" (see `ClaimAnswer`): each is a false drop.
    let quoteDrops: [String]
    /// Drafts whose check gave no answer, so that they lost every personal item it judges (a failure, a refusal, an answer that did not
    /// number the items 1 to n, or the time limit).
    let unchecked: Int
    /// Claimed items the rules dropped before the check (composed only).
    let rulesDrops: Int
    let errors: Int
    let refusals: Int
    let medianSeconds: Double
    let p95Seconds: Double
    let sameInEveryRun: Bool

    init(name: String, mode: String, runs: [[MeasuredDraft]]) {
        let first = runs.first ?? []
        let items = first.flatMap { draft in draft.items.map { (draft.id, $0) } }
        func label(_ entry: (String, MeasuredItem)) -> String { "\(entry.0): \(entry.1.kind) \(entry.1.value)" }
        self.name = name
        self.mode = mode
        self.runs = runs.count
        drafts = first.count
        self.items = items.count
        claimed = items.filter { $0.1.claimed }.count
        falseKeeps = Array(Set(runs.flatMap { run in
            run.flatMap { draft in draft.items.filter { !$0.claimed && $0.kept }.map { label((draft.id, $0)) } }
        })).sorted()
        falseDrops = items.filter { $0.1.claimed && !$0.1.kept && !["rules", "unchecked", "error"].contains($0.1.verdict) }.map(label)
        quoteDrops = items.filter { $0.1.claimed && $0.1.droppedByItsQuote }.map(label)
        unchecked = first.filter(\.unchecked).count
        rulesDrops = items.filter { $0.1.claimed && $0.1.verdict == "rules" }.count
        errors = first.filter { $0.error != nil }.count
        refusals = first.filter(\.refused).count
        // Only the drafts the check was called on: the rules leave the others nothing to check, and they take milliseconds.
        let times = runs.flatMap { $0 }.filter { draft in draft.items.contains { $0.verdict != "rules" } }.map(\.seconds).sorted()
        medianSeconds = times.isEmpty ? 0 : times[times.count / 2]
        p95Seconds = times.isEmpty ? 0 : times[min(times.count - 1, Int(Double(times.count) * 0.95))]
        sameInEveryRun = runs.allSatisfy { $0.map(\.verdicts) == first.map(\.verdicts) }
    }
}

/// The real claim check, keeping what it said, for the measurement of the path the product takes: the judgement of each candidate and
/// the stance the model gave it before the proof of its quote.
actor RecordingClaimChecker: ClaimChecking {
    private(set) var judged: [ClaimCandidate: ClaimJudgement] = [:]
    private(set) var modelStances: [ClaimCandidate: ClaimStance] = [:]
    private(set) var failure: (any Error)?

    func judgements(of candidates: [ClaimCandidate], in description: String) async throws -> [ClaimJudgement] {
        do {
            let entries = try await FoundationModelsClaimChecker().answer(to: candidates, in: description)
            let judgements = try ClaimAnswer.judgements(from: entries, of: candidates, in: description)
            for (candidate, judgement) in zip(candidates, judgements) { judged[candidate] = judgement }
            // The answer numbers the items 1 to n, each once, or the judgements above would have thrown.
            for (candidate, entry) in zip(candidates, entries.sorted { $0.item < $1.item }) { modelStances[candidate] = entry.stance }
            return judgements
        } catch {
            failure = error
            throw error
        }
    }
}

/// The personal items of a draft of the contract, and what its row says of them.
enum ClaimItems {
    /// The headline title, the place, the skills, the languages and the interests of a draft, by their path in the contract.
    static func of(_ cv: CVData) -> [(path: String, candidate: ClaimCandidate)] {
        var items: [(String, ClaimCandidate)] = []
        func add(_ path: String, _ kind: ClaimCandidate.Kind, _ value: String?) {
            guard let candidate = ClaimCandidates.candidate(kind, value) else { return }
            items.append((path, candidate))
        }
        add("personalInfo.title", .title, cv.personalInfo.title)
        add("personalInfo.location", .place, cv.personalInfo.location)
        for (index, skill) in cv.skills.enumerated() { add("skills[\(index)].name", .skill, skill.name) }
        for (index, language) in cv.languages.enumerated() { add("languages[\(index)].name", .language, language.name) }
        for (index, interest) in cv.interests.enumerated() { add("interests[\(index)]", .interest, interest) }
        return items
    }

    /// The items of a row's draft with what the row says of each: kept (claimed) or dropped (not claimed). Nil when the row says
    /// nothing of them.
    static func expectation(of row: GroundingRow) -> [(candidate: ClaimCandidate, claimed: Bool)]? {
        let draft = of(row.draft)
        var judged: [(candidate: ClaimCandidate, claimed: Bool)] = []
        switch row.expected {
        case .exactly(let expected):
            let kept = of(expected).map(\.candidate)
            judged = kept.map { ($0, true) }
            judged += draft.filter { item in !kept.contains { overlaps($0, item.candidate) } }.map { ($0.candidate, false) }
        case .keeping(let drops, _):
            let dropped = Set(drops.map(\.path))
            judged = draft.map { ($0.candidate, !dropped.contains($0.path)) }
        case .safe(let never, let absent, let keeping):
            for item in draft {
                let value = item.candidate.value.lowercased()
                if absent.contains(item.path) || never.contains(where: { value.contains($0.lowercased()) }) {
                    judged.append((item.candidate, false))
                } else if keeping[item.path] != nil {
                    judged.append((item.candidate, true))
                }
            }
        }
        var seen = Set<String>()
        return judged.filter { seen.insert(key($0.candidate)).inserted }
    }

    /// Whether two items are the same item, one written with more words than the other: "a nursery" and "nursery".
    static func overlaps(_ first: ClaimCandidate, _ second: ClaimCandidate) -> Bool {
        let one = " \(DescriptionText.normalized(first.value)) ", other = " \(DescriptionText.normalized(second.value)) "
        return first.kind == second.kind && (one.contains(other) || other.contains(one))
    }

    private static func key(_ candidate: ClaimCandidate) -> String {
        candidate.kind.rawValue + "|" + DescriptionText.normalized(candidate.value)
    }
}
#endif
