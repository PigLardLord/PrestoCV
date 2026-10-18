import Testing
import Foundation
@testable import CVGeneratorAI

/// ADR 0023: grounding gives the same draft on every device, in Italian, Spanish, French and Portuguese whatever the device tags, and
/// in English and German where the device has their assets. Whether the device's lexical class tags a language depends on the
/// linguistic assets the device has downloaded, so the rows of the contract run here with its verdict forced, language by language.
@Suite("Grounding on every device: the rows of the contract do not depend on the device's assets")
struct GroundingOnEveryDeviceTests {
    private static let rowLanguages = ["en", "it", "de", "es", "fr", "pt"]
    private static let untaggedLanguages: [Vocabulary.Language] = [.italian, .spanish, .french, .portuguese]

    /// The rows that keep, on a device without the assets of English and German, what a device with them drops: a wish, a plan or
    /// another person's statement read as the person's fact, as the verbs that tell them are not tagged. Each runs in `withKnownIssue`:
    /// once grounding no longer keeps it, the wrapper fails, and the id leaves this list.
    private static let keptWithoutAssets: Set<String> = [
        "a-job-search-at-an-employer-is-no-job-en", "no-experience-from-a-coordinated-search-en", "probe-long-en",
        "no-job-from-an-intention-phrase-de", "no-job-from-a-purpose-before-the-name-de", "no-job-from-an-infinitive-clause-de",
        "no-job-from-a-dream-after-the-name-de", "an-inverted-noun-subject-gives-nothing-de", "place-before-sister-language-de",
        "a-name-after-a-place-gives-no-language-de",
    ]

    private func sanitized(_ row: GroundingRow, by tagger: ForcedLexicalTagger) -> CVData {
        CVDataSanitizer(lexicalClasses: tagger).sanitize(row.draft, against: row.description)
    }

    private func everyUntaggedLanguage(_ verdict: ForcedLexicalTagger.Verdict) -> ForcedLexicalTagger {
        ForcedLexicalTagger(Dictionary(uniqueKeysWithValues: Self.untaggedLanguages.map { ($0, verdict) }))
    }

    @Test("A row gives the same draft whether the device tags Italian, Spanish, French and Portuguese or not", arguments: rowLanguages)
    func untaggedLanguagesGiveTheSameDraft(rowLanguage: String) {
        let rows = GroundingRows.all.filter { $0.language == rowLanguage }
        let verdicts: [(name: String, verdict: ForcedLexicalTagger.Verdict)] = [
            ("every word", .everyWord),
            // Words that a device with the assets can take for verbs: "corsi" (I ran) in "Insegno corsi a studenti presso Acme".
            ("corsi, hésitez and contacter", .words(["corsi", "hesitez", "contacter"])),
        ]
        let untagged = rows.map { sanitized($0, by: everyUntaggedLanguage(.noAssets)) }

        #expect(!rows.isEmpty)
        for (name, verdict) in verdicts {
            let tagger = everyUntaggedLanguage(verdict)
            let changed = zip(rows, untagged).filter { row, draft in sanitized(row, by: tagger) != draft }.map { $0.0.id }
            #expect(changed.isEmpty, "Tagging \(name) changes \(changed.count) of \(rows.count) rows: \(changed)")
        }
    }

    @Test("Without the assets of English and German a row keeps nothing that it drops with them", arguments: rowLanguages)
    func taggedLanguagesWithoutAssetsOnlyLose(rowLanguage: String) throws {
        let withoutAssets = ForcedLexicalTagger([.english: .noAssets, .german: .noAssets])

        for row in GroundingRows.all where row.language == rowLanguage {
            let kept = try Kept.sections(of: sanitized(row, by: withoutAssets), beyond: sanitized(row, by: ForcedLexicalTagger([:])))
            if Self.keptWithoutAssets.contains(row.id) {
                withKnownIssue("Without the device's tags the verbs of English and German are not told") {
                    #expect(kept.isEmpty, "\(row.id) keeps more in \(kept)")
                }
            } else {
                #expect(kept.isEmpty, "\(row.id) keeps more in \(kept)")
            }
        }
    }
}

/// What a draft keeps beyond another: the sections of the draft with a value that no value of the other holds. An entry is held by an
/// entry of the other with each of its fields, so an entry that lost a field is held, and one the other has not got is not.
private enum Kept {
    static func sections(of draft: CVData, beyond other: CVData) throws -> [String] {
        let kept = try fields(of: draft), whole = try fields(of: other)
        return kept.keys.sorted().filter { !isPart(kept[$0], of: whole[$0]) }
    }

    private static func fields(of draft: CVData) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(draft)) as? [String: Any])
    }

    private static func isPart(_ value: Any?, of other: Any?) -> Bool {
        switch value {
        case let fields as [String: Any]:
            let whole = other as? [String: Any] ?? [:]
            return fields.allSatisfy { isPart($0.value, of: whole[$0.key]) }
        case let items as [Any]:
            let whole = other as? [Any] ?? []
            return items.allSatisfy { item in whole.contains { isPart(item, of: $0) } }
        case let text as String:
            return text.isEmpty || text == other as? String
        case let flag as Bool:
            return !flag || flag == other as? Bool
        default:
            return value == nil
        }
    }
}
