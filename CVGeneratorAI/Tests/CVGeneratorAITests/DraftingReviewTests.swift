import Testing
import Foundation
import CVGeneratorAI

// A run set passes with no hard finding. It is GO only when the fields the counter queued for a person (review.json) have been read,
// and the reading is recorded at the revision under test (adjudication.json).

@Suite("Drafting evaluation: review items and the verdict")
struct DraftingReviewTests {
    // MARK: - The items

    @Test("The same value of the same input in three runs is one item that lists the three")
    func oneItemPerValue() throws {
        let scenario = try Scenario.make(
            ids: ["en-plain", "it-plain"], runs: 3, tweak: DraftMeasures.tweak(Scenario.reviewedOnce, for: "en-plain")
        )

        let item = try #require(scenario.review.first)

        #expect(scenario.review.count == 1)
        #expect(scenario.review.count == scenario.summary.reviewItems)
        #expect(item.id == "en-plain")
        #expect(item.value == "bake bread")
        #expect(item.seen == ["run 1: interests[0]", "run 2: interests[0]", "run 3: interests[0]"])
    }

    @Test("Two fields with the same value and two reasons are two items")
    func oneItemPerReason() throws {
        let scenario = try Scenario.make(runs: 2, tweak: DraftMeasures.tweak(Scenario.reviewed, for: "en-plain"))

        let items = scenario.review.filter { $0.value == "English" }

        #expect(items.count == 2)
        #expect(Set(items.map(\.key)).count == 2)
        #expect(Set(items.map(\.reason)).count == 2)
        #expect(items.map(\.seen.count) == [2, 2])
    }

    @Test("The items come in the order they were first seen")
    func order() throws {
        let both = Tweak(edit: { $0.skills.append(Skill(name: "English")) })
        let measured = try DraftMeasures.set(["en-plain"], runs: 2, tweak: { _, run in run == 1 ? both : Tweak(edit: { $0.skills = [Skill(name: "Polish"), Skill(name: "English")] }) })

        let values = ReviewItem.unique(in: measured).map(\.value)

        #expect(values.firstIndex(of: "English") ?? .max < values.firstIndex(of: "Polish") ?? .max)
    }

    @Test("The same value of another input is another item")
    func otherInput() throws {
        let measured = try DraftMeasures.set(["en-plain", "en-traps"], tweak: { _, _ in Scenario.reviewed })

        let items = ReviewItem.unique(in: measured).filter { $0.value == "English" && $0.seen.contains { $0.contains("skills[") } }

        #expect(items.map(\.id) == ["en-plain", "en-traps"])
        #expect(Set(items.map(\.key)).count == 2)
    }

    @Test("The key is the input and a hash of the value, the reason and the context, the same in every process", arguments: KeyCase.all)
    func key(_ item: KeyCase) {
        #expect(ReviewItem.key(id: item.id, value: item.value, reason: item.reason, context: item.context) == item.key)
    }

    @Test("Each of the four fields changes the key")
    func keyFields() {
        let base = ReviewItem.key(id: "a", value: "b", reason: "c", context: "d")

        #expect(base == ReviewItem.key(id: "a", value: "b", reason: "c", context: "d"))
        #expect(base != ReviewItem.key(id: "x", value: "b", reason: "c", context: "d"))
        #expect(base != ReviewItem.key(id: "a", value: "x", reason: "c", context: "d"))
        #expect(base != ReviewItem.key(id: "a", value: "b", reason: "x", context: "d"))
        #expect(base != ReviewItem.key(id: "a", value: "b", reason: "c", context: "x"))
        #expect(base != ReviewItem.key(id: "a", value: "b", reason: "c", context: nil))
    }

    @Test("A field boundary cannot be moved between two fields")
    func boundary() {
        #expect(ReviewItem.key(id: "a", value: "bc", reason: "d", context: nil) != ReviewItem.key(id: "a", value: "b", reason: "cd", context: nil))
    }

    @Test("The hash is FNV-1a over the UTF-8 bytes", arguments: [
        ("", UInt64(0xcbf2_9ce4_8422_2325)), ("a", 0xaf63_dc4c_8601_ec8c), ("foobar", 0x8594_4171_f739_67e8),
    ])
    func fnv(_ text: String, _ hash: UInt64) {
        #expect(ReviewItem.fnv1a(text) == hash)
    }

    // MARK: - The verdict

    @Test("A complete set with no hard finding and no item to read is GO")
    func goWithNothingToRead() throws {
        let scenario = try Scenario.make()

        #expect(scenario.review.isEmpty)
        #expect(scenario.verdict == .go)
    }

    @Test("A set with items to read is not GO until somebody has decided every one")
    func goNeedsAdjudication() throws {
        let scenario = try Scenario.make(runs: 2, tweak: DraftMeasures.tweak(Scenario.reviewed, for: "en-plain"))

        #expect(!scenario.review.isEmpty)
        #expect(scenario.verdict.reasons.contains { $0.contains("nobody has adjudicated them") })
        #expect(scenario.adjudicated().verdict == .go)
    }

    @Test("A decision that is not complete, or not in order, is not GO", arguments: VerdictCase.all)
    func notGo(_ item: VerdictCase) throws {
        let verdict = try item.scenario().verdict

        #expect(verdict != .go, "\(item)")
        #expect(verdict.reasons.contains { $0.contains(item.reason) }, "\(item): \(verdict.reasons)")
    }

    @Test("A rejected item is named, with the rest of the decisions kept")
    func rejection() throws {
        var scenario = try Scenario.make(tweak: DraftMeasures.tweak(Scenario.reviewed, for: "en-plain")).adjudicated()
        let item = try #require(scenario.review.first)
        scenario.adjudication = Adjudication(
            reviewer: "G. T.", revision: scenario.manifest.revision,
            entries: scenario.review.map { Adjudication.Entry(key: $0.key, decision: $0.key == item.key ? .reject : .accept, note: "wrong place") }
        )

        let reasons = scenario.verdict.reasons

        #expect(reasons.count == 1)
        #expect(reasons.first?.hasPrefix("rejected: \(item.id) \"\(item.value)\"") == true)
    }

    @Test("An adjudication reads back the way it was written")
    func adjudicationRoundTrip() throws {
        let adjudication = Adjudication(
            reviewer: "G. T.", revision: "abc1234", entries: [Adjudication.Entry(key: "en-plain-1", decision: .reject, note: "x")]
        )

        let decoded = try JSONDecoder().decode(Adjudication.self, from: JSONEncoder().encode(adjudication))

        #expect(decoded == adjudication)
    }
}

extension Readiness {
    /// The reasons that make it not GO; empty when it is.
    var reasons: [String] {
        if case .noGo(let reasons) = self { return reasons }
        return []
    }
}

// MARK: - Cases

struct KeyCase: Sendable, CustomTestStringConvertible {
    let id: String
    let value: String
    let reason: String
    let context: String?
    let key: String

    var testDescription: String { "\(id) \(value)" }

    static let all: [KeyCase] = [
        KeyCase(id: "en-plain", value: "English", reason: "r", context: nil, key: "en-plain-" + digest("en-plain\u{1F}English\u{1F}r\u{1F}")),
        KeyCase(id: "x", value: "", reason: "", context: nil, key: "x-" + digest("x\u{1F}\u{1F}\u{1F}")),
        KeyCase(id: "x", value: "é", reason: "r", context: "job", key: "x-" + digest("x\u{1F}é\u{1F}r\u{1F}job")),
    ]

    /// 16 hex digits with the leading zeros, of the hash the test of FNV-1a checks on its own.
    private static func digest(_ text: String) -> String {
        let hex = String(ReviewItem.fnv1a(text), radix: 16)
        return String(repeating: "0", count: 16 - hex.count) + hex
    }
}

/// A run set whose reading is wrong in one way, and the reason the verdict gives.
struct VerdictCase: Sendable, CustomTestStringConvertible {
    let label: String
    let reason: String
    let scenario: @Sendable () throws -> Scenario

    var testDescription: String { label }

    /// A set with items to read, all of them decided.
    private static func read() throws -> Scenario {
        try Scenario.make(runs: 2, tweak: DraftMeasures.tweak(Scenario.reviewed, for: "en-plain")).adjudicated()
    }

    static let all: [VerdictCase] = [
        VerdictCase(label: "no adjudication", reason: "nobody has adjudicated them") {
            var scenario = try read()
            scenario.adjudication = nil
            return scenario
        },
        VerdictCase(label: "no reviewer", reason: "names no reviewer") { try read().adjudicated(by: "  ") },
        VerdictCase(label: "an adjudication of another revision", reason: "is of revision other, not abc1234") {
            try read().adjudicated(at: "other")
        },
        VerdictCase(label: "an item decided twice", reason: "is decided 2 times") {
            var scenario = try read()
            let first = try #require(scenario.adjudication?.entries.first)
            scenario.adjudication = scenario.adjudication.map {
                Adjudication(reviewer: $0.reviewer, revision: $0.revision, entries: $0.entries + [first])
            }
            return scenario
        },
        VerdictCase(label: "a decision about an item that is not listed", reason: "is decided and is not in review.json") {
            var scenario = try read()
            scenario.adjudication = scenario.adjudication.map {
                Adjudication(
                    reviewer: $0.reviewer, revision: $0.revision,
                    entries: $0.entries + [Adjudication.Entry(key: "en-plain-0000000000000000", decision: .accept, note: nil)]
                )
            }
            return scenario
        },
        VerdictCase(label: "an item left undecided", reason: "items are not decided") {
            var scenario = try read()
            scenario.adjudication = scenario.adjudication.map {
                Adjudication(reviewer: $0.reviewer, revision: $0.revision, entries: [])
            }
            return scenario
        },
        VerdictCase(label: "every item rejected", reason: "rejected: en-plain") { try read().adjudicated(as: .reject) },
        VerdictCase(label: "an invented field", reason: "hard findings") {
            try Scenario.make(tweak: DraftMeasures.tweak(Scenario.invented, for: "en-plain"))
        },
        VerdictCase(label: "a run that failed", reason: "1 failed runs") {
            try Scenario.make(tweak: DraftMeasures.tweak(Tweak(error: CVGenerationError.generationFailed), for: "it-plain"))
        },
        VerdictCase(label: "a revision that is not recorded", reason: "the revision under test is not recorded") {
            try Scenario.make(revision: "unknown")
        },
        VerdictCase(label: "a partial set", reason: "the run set is partial: 1 of 2 inputs") {
            try Scenario.make(ids: ["en-plain"], all: ["en-plain", "it-plain"])
        },
        VerdictCase(label: "a set that stopped halfway", reason: "the run set is not complete: 1 of 4 runs") {
            var scenario = try Scenario.make(runs: 2)
            scenario.manifest = scenario.manifest.completed(runs: 1)
            return scenario
        },
        VerdictCase(label: "a summary of another revision", reason: "summary.json is of revision abc1234, the manifest of other") {
            var scenario = try Scenario.make()
            let other = DraftMeasures.manifest(["en-plain", "it-plain"], revision: "other")
            scenario.manifest = other.completed(runs: other.expectedRuns)
            return scenario
        },
    ]
}
