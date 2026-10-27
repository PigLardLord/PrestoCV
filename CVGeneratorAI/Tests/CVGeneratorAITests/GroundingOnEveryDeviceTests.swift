import Testing
import Foundation
@testable import CVGeneratorAI

/// ADR 0023: grounding gives the same draft on every device that grounds the description. Whether the device's lexical class tags a
/// language depends on the language data the device has downloaded, so the rows of the contract run here with its verdict forced,
/// language by language, whatever the data of the device that runs them.
@Suite("Grounding on every device: the rows of the contract do not depend on the device's language data")
struct GroundingOnEveryDeviceTests {
    private static let rowLanguages = ["en", "it", "de", "es", "fr", "pt"]
    private static let untaggedLanguages: [Vocabulary.Language] = [.italian, .spanish, .french, .portuguese]

    private func grounding(_ row: GroundingRow, by tagger: ForcedLexicalTagger) -> Result<CVData, CVGenerationError> {
        Result { () throws(CVGenerationError) in
            try CVDataSanitizer(lexicalClasses: tagger, wordList: TableWordList()).sanitize(row.draft, against: row.description)
        }
    }

    /// Every language forced: English and German without their data, so that no row reads the device that runs the test, and the
    /// other four with `verdict`.
    private func everyLanguage(_ verdict: ForcedLexicalTagger.Verdict) -> ForcedLexicalTagger {
        var verdicts: [Vocabulary.Language: ForcedLexicalTagger.Verdict] = [.english: .noAssets, .german: .noAssets]
        for language in Self.untaggedLanguages { verdicts[language] = verdict }
        return ForcedLexicalTagger(verdicts)
    }

    @Test("A row gives the same draft whether the device tags Italian, Spanish, French and Portuguese or not", arguments: rowLanguages)
    func untaggedLanguagesGiveTheSameDraft(rowLanguage: String) {
        let rows = GroundingRows.all.filter { $0.language == rowLanguage }
        let verdicts: [(name: String, verdict: ForcedLexicalTagger.Verdict)] = [
            ("every word", .everyWord),
            // Words that a device with the data can take for verbs: "corsi" (I ran) in "Insegno corsi a studenti presso Acme".
            ("corsi, hésitez and contacter", .words(["corsi", "hesitez", "contacter"])),
        ]
        let untagged = rows.map { grounding($0, by: everyLanguage(.noAssets)) }

        #expect(!rows.isEmpty)
        for (name, verdict) in verdicts {
            let tagger = everyLanguage(verdict)
            let changed = zip(rows, untagged).filter { row, draft in grounding(row, by: tagger) != draft }.map { $0.0.id }
            #expect(changed.isEmpty, "Tagging \(name) changes \(changed.count) of \(rows.count) rows: \(changed)")
        }
    }

    @Test("Without the data of English and German a row read in either gives no draft, and any other row the draft it gives with it",
          arguments: rowLanguages)
    func taggedLanguagesWithoutDataGiveNoDraft(rowLanguage: String) {
        let withoutData = ForcedLexicalTagger([.english: .noAssets, .german: .noAssets])
        let withData = ForcedLexicalTagger([.english: .everyWord, .german: .everyWord])
        var readInEnglishOrGerman = 0
        var grounded: [String] = []

        for row in GroundingRows.all where row.language == rowLanguage {
            let draft = grounding(row, by: withoutData)
            if let language = DescriptionText(row.description).explainer.language, VerbForms.readsVerbsByTags(in: language) {
                readInEnglishOrGerman += 1
                if draft != .failure(.languageDataUnavailable(languageCode: language.rawValue)) { grounded.append(row.id) }
            } else if draft != grounding(row, by: withData) {
                grounded.append(row.id)
            }
        }
        #expect(["en", "de"].contains(rowLanguage) ? readInEnglishOrGerman > 0 : true)
        #expect(grounded.isEmpty, "\(grounded.count) rows give a draft that the data of English or German changes: \(grounded)")
    }

    @Test("A description in Italian, Spanish, French, Portuguese or none of the six needs no data of the device", arguments: [
        "Dal 2016 insegno alla scuola Don Milani.", "Desde 2016 enseño en la escuela Don Milani.",
        "Depuis 2016, j'enseigne à l'école Don Milani.", "Desde 2016 leciono na escola Don Milani.", "東京の病院で看護師として働いています。",
    ])
    func otherDescriptionsNeedNoData(description: String) throws {
        let withoutData = ForcedLexicalTagger(Dictionary(uniqueKeysWithValues: Vocabulary.Language.allCases.map { ($0, .noAssets) }))

        try CVDataSanitizer(lexicalClasses: withoutData).languageCheck(of: description).require()
    }
}
