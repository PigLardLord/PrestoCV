import Foundation
import CVGeneratorAI

// The fields the counter cannot prove either way go to review (`InventedFacts.Class.review`), and a person reads them once per run
// set. So does what a draft writes around the facts (ADR 0031): whether a summary, a role description or a skill fits the person's
// role and field no counter can say, and a person reads each distinct final draft that writes any (`ReviewItem.Kind.pertinence`).
// Reading them is not a gate until it is recorded: `Adjudication` is that record, and `Readiness` is the one place that says GO.

// MARK: - The items to read

/// A field, or a draft, a person reads once per run set: the same value of the same input is listed once, with the runs that wrote it.
struct ReviewItem: Codable, Equatable {
    enum Kind: String, Codable, Equatable {
        /// A field the counter cannot prove either way: is it faithful to the description?
        case field
        /// What a final draft writes around the facts. The rubric of #354: each technology fits the role and the field; each soft
        /// skill fits the role; each role description matches its title and the field; the summary is plausible, of one person, in the
        /// description's language; nothing contradicts a fact of the description.
        case pertinence
    }

    /// The key an adjudication names the item by: the input and a hash of the value, the reason and the context.
    let key: String
    let kind: Kind
    let id: String
    let value: String
    let reason: String
    /// The job or the school the value was written for, when the field belongs to one; the input's role or field for a pertinence item.
    let context: String?
    /// "run <n>: <path>" for every run and field that holds the value; "run <n>" for every run that wrote the draft.
    let seen: [String]

    static let pertinenceReason = "pertinence: does what the draft writes around the facts fit the role and the field?"

    static func unique(in measured: [DraftMeasure]) -> [ReviewItem] {
        var order: [String] = []
        var items: [String: ReviewItem] = [:]
        func add(_ kind: Kind, id: String, value: String, reason: String, context: String?, seen: String) {
            let key = Self.key(id: id, value: value, reason: reason, context: context)
            if let item = items[key] {
                items[key] = ReviewItem(
                    key: key, kind: kind, id: id, value: value, reason: reason, context: context, seen: item.seen + [seen]
                )
            } else {
                order.append(key)
                items[key] = ReviewItem(key: key, kind: kind, id: id, value: value, reason: reason, context: context, seen: [seen])
            }
        }
        for draft in measured {
            for finding in draft.report.toReview {
                add(.field, id: draft.id, value: finding.value, reason: finding.reason, context: finding.context,
                    seen: "run \(draft.run): \(finding.path)")
            }
        }
        // A draft with no role has nothing to fit: what it writes around the facts is an off-field hit (`WrittenMeasure.offField`).
        for draft in measured where draft.kind != .noRole && !draft.report.inferred.isEmpty {
            guard let final = draft.final else { continue }
            add(.pertinence, id: draft.id, value: written(final), reason: pertinenceReason, context: DraftingInputs.fields[draft.id]?.field,
                seen: "run \(draft.run)")
        }
        return order.compactMap { items[$0] }
    }

    /// What `cv` writes around the facts, as a person reads it for pertinence: the title, the summary, each job with its description,
    /// the technologies and the soft skills, a line each.
    static func written(_ cv: CVData) -> String {
        var lines: [String] = []
        if let title = cv.personalInfo.title, !title.isEmpty { lines.append("title: \(title)") }
        if let summary = cv.summary, !summary.isEmpty { lines.append("summary: \(summary)") }
        for job in cv.experience {
            lines.append("job: \([job.title, job.company].filter { !$0.isEmpty }.joined(separator: ", ")): \(job.description ?? "")")
        }
        for kind in SkillKind.allCases {
            let names = cv.skills.filter { $0.kind == kind }.map(\.name)
            if !names.isEmpty { lines.append("\(kind == .technology ? "technologies" : "soft skills"): \(names.joined(separator: ", "))") }
        }
        return lines.joined(separator: "\n")
    }

    /// The same four fields always give the same key, in every process: Swift's own `hashValue` is seeded per process, so the key is a
    /// hand-written FNV-1a.
    static func key(id: String, value: String, reason: String, context: String?) -> String {
        let hash = fnv1a([id, value, reason, context ?? ""].joined(separator: "\u{1F}"))
        let hex = String(hash, radix: 16)
        return id + "-" + String(repeating: "0", count: 16 - hex.count) + hex
    }

    /// The 64-bit FNV-1a hash of the UTF-8 bytes of `text`.
    static func fnv1a(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return hash
    }
}

// MARK: - The record of a reading

/// What a person decided of the items of review.json, kept as adjudication.json beside them.
struct Adjudication: Codable, Equatable {
    enum Decision: String, Codable, Equatable {
        /// The value is faithful to the description, or harmless where it stands.
        case accept
        /// The value is wrong where it stands: the draft invents, or puts a fact in the wrong place.
        case reject
    }

    struct Entry: Codable, Equatable {
        let key: String
        let decision: Decision
        let note: String?
    }

    /// Who read the items.
    let reviewer: String
    /// The revision the items were read at: an adjudication of another revision decides nothing here.
    let revision: String
    let entries: [Entry]
}

// MARK: - GO

/// Whether a run set is GO. The evaluation test passes with no hard finding; GO needs that and a recorded adjudication of every item
/// of review.json at the same revision, none of them rejected.
enum Readiness: Equatable {
    case go
    case noGo([String])

    static func verdict(manifest: RunManifest, summary: DraftSummary, review: [ReviewItem], adjudication: Adjudication?) -> Readiness {
        var reasons: [String] = []
        if manifest.revision.isEmpty || manifest.revision == "unknown" {
            reasons.append("the revision under test is not recorded (PRESTOCV_DRAFT_EVAL_REV)")
        }
        if manifest.partial {
            reasons.append("the run set is partial: \(manifest.inputs.count) of \(manifest.allInputs.count) inputs")
        }
        if !manifest.complete {
            reasons.append("the run set is not complete: \(manifest.completedRuns) of \(manifest.expectedRuns) runs")
        }
        if summary.revision != manifest.revision {
            reasons.append("summary.json is of revision \(summary.revision), the manifest of \(manifest.revision)")
        }
        if summary.hardFindings > 0 {
            reasons.append(
                "\(summary.hardFindings) hard findings: \(summary.invented.count) invented, \(summary.failures.count) failed runs, "
                    + "\(summary.exampleMisses.count) example misses, \(summary.offField.count) off-field hits"
            )
        }
        reasons += summary.shortfalls.map { "a threshold is missed: \($0)" }
        reasons += problems(of: adjudication, for: review, at: manifest.revision)
        return reasons.isEmpty ? .go : .noGo(reasons)
    }

    private static func problems(of adjudication: Adjudication?, for review: [ReviewItem], at revision: String) -> [String] {
        guard !review.isEmpty else { return [] }
        guard let adjudication else {
            return ["review.json lists \(review.count) items and nobody has adjudicated them (no adjudication.json)"]
        }
        var problems: [String] = []
        if adjudication.reviewer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            problems.append("the adjudication names no reviewer")
        }
        if adjudication.revision != revision {
            problems.append("the adjudication is of revision \(adjudication.revision), not \(revision)")
        }
        let decided = Dictionary(grouping: adjudication.entries, by: \.key)
        for (key, entries) in decided.sorted(by: { $0.key < $1.key }) where entries.count > 1 {
            problems.append("\(key) is decided \(entries.count) times")
        }
        let known = Set(review.map(\.key))
        for key in decided.keys.sorted() where !known.contains(key) {
            problems.append("\(key) is decided and is not in review.json")
        }
        let undecided = review.filter { decided[$0.key] == nil }
        if !undecided.isEmpty {
            problems.append("\(undecided.count) of \(review.count) items are not decided, the first: \(undecided[0].id) \"\(undecided[0].value)\"")
        }
        for item in review where decided[item.key]?.contains(where: { $0.decision == .reject }) == true {
            problems.append("rejected: \(item.id) \"\(item.value)\" (\(item.reason))")
        }
        return problems
    }
}
