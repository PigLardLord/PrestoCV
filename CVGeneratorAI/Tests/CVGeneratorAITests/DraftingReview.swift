import Foundation

// The fields the counter cannot prove either way go to review (`InventedFacts.Class.review`), and a person reads them once per run
// set. Reading them is not a gate until it is recorded: `Adjudication` is that record, and `Readiness` is the one place that says GO.

// MARK: - The items to read

/// A field a person reads once per run set: the same value of the same input is listed once, with the runs that wrote it.
struct ReviewItem: Codable, Equatable {
    /// The key an adjudication names the item by: the input and a hash of the value, the reason and the context.
    let key: String
    let id: String
    let value: String
    let reason: String
    /// The job or the school the value was written for, when the field belongs to one.
    let context: String?
    /// "run <n>: <path>" for every run and field that holds the value.
    let seen: [String]

    static func unique(in measured: [DraftMeasure]) -> [ReviewItem] {
        var order: [String] = []
        var items: [String: ReviewItem] = [:]
        for draft in measured {
            for finding in draft.report.toReview {
                let key = Self.key(id: draft.id, value: finding.value, reason: finding.reason, context: finding.context)
                let seen = "run \(draft.run): \(finding.path)"
                if let item = items[key] {
                    items[key] = ReviewItem(
                        key: key, id: item.id, value: item.value, reason: item.reason, context: item.context, seen: item.seen + [seen]
                    )
                } else {
                    order.append(key)
                    items[key] = ReviewItem(
                        key: key, id: draft.id, value: finding.value, reason: finding.reason, context: finding.context, seen: [seen]
                    )
                }
            }
        }
        return order.compactMap { items[$0] }
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
                    + "\(summary.exampleMisses.count) example misses"
            )
        }
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
