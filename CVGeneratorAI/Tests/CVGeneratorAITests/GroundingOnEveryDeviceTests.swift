import Testing
import Foundation
@testable import CVGeneratorAI

/// ADR 0023: grounding gives the same draft on every device. Whether the device's lexical class tags a language depends on the
/// linguistic assets the device has downloaded, so the rows of the contract run here with its verdict forced, language by language.
@Suite("Grounding on every device: the rows of the contract do not depend on the device's assets")
struct GroundingOnEveryDeviceTests {
    private static let rowLanguages = ["en", "it", "de", "es", "fr", "pt"]
    private static let untaggedLanguages: [Vocabulary.Language] = [.italian, .spanish, .french, .portuguese]

    private func sanitized(_ row: GroundingRow, by tagger: ForcedLexicalTagger) -> CVData {
        LexicalClasses.$tagger.withValue(tagger) { CVDataSanitizer().sanitize(row.draft, against: row.description) }
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
}
