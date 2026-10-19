import Testing
import Foundation
@testable import CVGeneratorAI

// The spike of #249: the claim check on the real on-device model, measured on the contract and on an adversarial set. It runs
// only when PRESTOCV_CLAIM_EVAL names the parts to run ("a", "b" or "ab"), on an Apple host with Apple Intelligence, and writes
// its results as JSON to the folder PRESTOCV_CLAIM_EVAL_OUT. It measures; it asserts nothing.

private let evaluation = ProcessInfo.processInfo.environment["PRESTOCV_CLAIM_EVAL"] ?? ""
private let outputFolder = URL(fileURLWithPath: ProcessInfo.processInfo.environment["PRESTOCV_CLAIM_EVAL_OUT"] ?? NSTemporaryDirectory())
/// The kinds of items to judge (PRESTOCV_CLAIM_KINDS, comma-separated); every kind when it is not set.
private let judgedKinds: Set<ClaimCandidate.Kind> = {
    guard let kinds = ProcessInfo.processInfo.environment["PRESTOCV_CLAIM_KINDS"] else { return Set(ClaimCandidate.Kind.allCases) }
    return Set(kinds.split(separator: ",").compactMap { ClaimCandidate.Kind(rawValue: String($0)) })
}()

@Suite("Claim check evaluation (#249)", .serialized, .enabled(if: !evaluation.isEmpty))
@MainActor
struct ClaimCheckEvaluation {
    struct Judged: Encodable {
        let kind: String
        let value: String
        let expected: Bool
        let stance: String
        let quote: String
    }

    struct Draft: Encodable {
        let id: String
        let language: String
        let tag: String
        let items: [Judged]
        let seconds: Double
        let error: String?
    }

    @Test("(a) every item of the contract that the rows keep or drop")
    func contractRows() async throws {
        guard evaluation.contains("a") else { return }
        var drafts: [Draft] = []
        for row in GroundingRows.all {
            guard let expectation = ClaimItems.expectation(of: row), !expectation.isEmpty else { continue }
            let tag = row.id.contains("accepted-loss") ? "accepted-loss" : (GroundingRows.notImplementedYet.contains(row.id) ? "known-issue" : "")
            drafts.append(await judge(id: row.id, language: row.language, tag: tag, description: row.description, items: expectation))
        }
        try write(drafts, to: "contract.json")
    }

    @Test("(b) the adversarial set, three times")
    func adversarialSet() async throws {
        guard evaluation.contains("b") else { return }
        for run in 1...3 {
            var drafts: [Draft] = []
            for sentence in AdversarialSet.sentences {
                drafts.append(await judge(id: sentence.id, language: sentence.language, tag: "", description: sentence.description,
                                          items: sentence.items))
            }
            try write(drafts, to: "adversarial-run\(run).json")
        }
    }

    @Test("(c) the held-out set, three times")
    func heldOutSet() async throws {
        guard evaluation.contains("c") else { return }
        for run in 1...3 {
            var drafts: [Draft] = []
            for sentence in AdversarialSet.heldOut {
                drafts.append(await judge(id: sentence.id, language: sentence.language, tag: "", description: sentence.description,
                                          items: sentence.items))
            }
            try write(drafts, to: "heldout-run\(run).json")
        }
    }

    private func judge(id: String, language: String, tag: String, description: String,
                       items allItems: [(candidate: ClaimCandidate, claimed: Bool)]) async -> Draft {
        let items = allItems.filter { judgedKinds.contains($0.candidate.kind) }
        guard !items.isEmpty else { return Draft(id: id, language: language, tag: tag, items: [], seconds: 0, error: nil) }
        let checker = FoundationModelsClaimChecker()
        let start = ContinuousClock.now
        do {
            let judgements = try await checker.judgements(of: items.map(\.candidate), in: description)
            let seconds = Self.seconds(ContinuousClock.now - start)
            let judged = zip(items, judgements).map { item, judgement in
                Judged(kind: item.candidate.kind.rawValue, value: item.candidate.value, expected: item.claimed,
                       stance: judgement.stance.rawValue, quote: judgement.quote)
            }
            return Draft(id: id, language: language, tag: tag, items: judged, seconds: seconds, error: nil)
        } catch {
            let judged = items.map { Judged(kind: $0.candidate.kind.rawValue, value: $0.candidate.value, expected: $0.claimed, stance: "error", quote: "") }
            return Draft(id: id, language: language, tag: tag, items: judged, seconds: Self.seconds(ContinuousClock.now - start),
                         error: String(describing: error))
        }
    }

    private func write(_ drafts: [Draft], to name: String) throws {
        try FileManager.default.createDirectory(at: outputFolder, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(drafts).write(to: outputFolder.appendingPathComponent(name))
    }

    private static func seconds(_ duration: Duration) -> Double {
        let (whole, attoseconds) = duration.components
        return Double(whole) + Double(attoseconds) / 1e18
    }
}

/// The items a claim check judges in a draft, and what a row of the contract says of them.
enum ClaimItems {
    /// The skills, languages, interests, headline title, place, employers and schools of a draft, by their path in the contract.
    static func of(_ cv: CVData) -> [(path: String, candidate: ClaimCandidate)] {
        var items: [(String, ClaimCandidate)] = []
        func add(_ path: String, _ kind: ClaimCandidate.Kind, _ value: String?) {
            guard let value = value?.trimmingCharacters(in: .whitespaces), !value.isEmpty, value.lowercased() != "null" else { return }
            items.append((path, ClaimCandidate(kind: kind, value: value)))
        }
        add("personalInfo.title", .title, cv.personalInfo.title)
        add("personalInfo.location", .place, cv.personalInfo.location)
        for (index, job) in cv.experience.enumerated() { add("experience[\(index)].company", .employer, job.company) }
        for (index, study) in cv.education.enumerated() { add("education[\(index)].institution", .school, study.institution) }
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
    private static func overlaps(_ first: ClaimCandidate, _ second: ClaimCandidate) -> Bool {
        let one = " \(DescriptionText.normalized(first.value)) ", other = " \(DescriptionText.normalized(second.value)) "
        return first.kind == second.kind && (one.contains(other) || other.contains(one))
    }

    private static func key(_ candidate: ClaimCandidate) -> String {
        candidate.kind.rawValue + "|" + DescriptionText.normalized(candidate.value)
    }
}
