import Testing
@testable import CVGeneratorAI

/// The draft of a sparse German description (#359, P4; the evaluation's "de-sparse": a baker who says she bakes bread). The model
/// writes the qualities of the soft skills in lower case ("zuverlässigkeit", "präzision"), as it does in the other languages, though
/// German writes its nouns with a capital: the skills list showed them so, and the strengths sentence of the summary read them as
/// adjectives ("Als Bäckerin bin ich zuverlässigkeit und präzision."), which the final check dropped as words of no dictionary. And
/// the summary's sentence "Ich backe Brot mit Präzision und Zuverlässigkeit." was dropped as saying nothing of the work of a
/// "Bäckerin": the title's stem "bäcke" is not the verb's "backe". The descriptions are the evaluation's, and every name and trade
/// in them is invented.
@Suite("A sparse German draft: the qualities take a capital and a stem matches through its umlaut (#359, P4)", .richDraft)
struct SparseGermanDraftTests {
    private static func sanitizer(_ language: String = "de") -> CVDataSanitizer {
        CVDataSanitizer(languageOfText: { _ in language }, lexicalClasses: ForcedLexicalTagger([:]), wordList: GermanDictionary())
    }

    private static func description(of id: String) throws -> String {
        try #require(DraftingInputs.all().first { $0.id == id }).description
    }

    private static let baker = CVData(personalInfo: PersonalInfo(title: "Bäckerin"))

    // MARK: A noun quality takes its capital

    @Test("A German quality that is a noun is written with a capital, and an adjective, a capitalised noun and a phrase stay as they are", arguments: [
        ("zuverlässigkeit", "Zuverlässigkeit"), ("präzision", "Präzision"), ("kreativität", "Kreativität"),
        ("detailgenauigkeit", "Detailgenauigkeit"), ("geduld", "Geduld"), ("ordnung", "Ordnung"), ("teamfähigkeit", "Teamfähigkeit"),
        ("zuverlässig", "zuverlässig"), ("kreativ", "kreativ"), ("ordentlich", "ordentlich"), ("sorgfältig", "sorgfältig"),
        ("freundlich", "freundlich"), ("ruhig", "ruhig"), ("Zuverlässigkeit", "Zuverlässigkeit"), ("Geduld", "Geduld"),
        ("verständnis für kunden", "verständnis für kunden"),
    ])
    func nounQualityCapitalised(quality: String, written: String) throws {
        let verdict = Self.sanitizer().skillCheck(technologies: [], softSkills: [quality], stated: [], against: try Self.description(of: "de-sparse"))

        #expect(verdict.softSkills == [written], "\(verdict.softSkills) \(verdict.dropped)")
    }

    @Test("The qualities of the evaluation's baker are written with a capital, in the order the model gave them, and none is lost")
    func bakersQualities() throws {
        let verdict = Self.sanitizer().skillCheck(
            technologies: [], softSkills: ["zuverlässigkeit", "präzision", "kreativität", "detailgenauigkeit"], stated: [],
            against: try Self.description(of: "de-sparse")
        )

        #expect(verdict.softSkills == ["Zuverlässigkeit", "Präzision", "Kreativität", "Detailgenauigkeit"], "\(verdict.dropped)")
    }

    @Test("The qualities of another language are not touched: an Italian and an English draft keep theirs in lower case", arguments: [
        ("it", ["precisione", "affidabilità", "pazienza"]), ("en", ["reliability", "precision", "patience"]),
    ] as [(String, [String])])
    func otherLanguagesKeepTheirCase(language: String, qualities: [String]) throws {
        let verdict = Self.sanitizer(language).skillCheck(technologies: [], softSkills: qualities, stated: [], against: try Self.description(of: "de-sparse"))

        #expect(verdict.softSkills == qualities, "\(verdict.dropped)")
    }

    @Test("A quality the description states as a noun, with its capital in the middle of a sentence, is the person's own and is no name")
    func statedNounQualityIsNoName() throws {
        let description = "Ich bin Bäckerin und backe jeden Morgen Brot mit Geduld und Sorgfalt für unsere Kunden."
        let verdict = Self.sanitizer().skillCheck(technologies: [], softSkills: ["Geduld", "Sorgfalt"], stated: [], against: description)

        #expect(verdict.softSkills == ["Geduld", "Sorgfalt"], "\(verdict.softSkills) \(verdict.dropped)")
    }

    // MARK: The strengths sentence reads them as nouns

    @Test("The floor of the baker's summary ends with the strengths sentence of the first two qualities, as nouns or as adjectives", arguments: [
        (["zuverlässigkeit", "präzision", "kreativität", "detailgenauigkeit"],
         "Ich arbeite als Bäckerin. Als Bäckerin arbeite ich mit Zuverlässigkeit und Präzision."),
        (["Zuverlässigkeit", "Präzision"], "Ich arbeite als Bäckerin. Als Bäckerin arbeite ich mit Zuverlässigkeit und Präzision."),
        (["zuverlässig", "ruhig"], "Ich arbeite als Bäckerin. Als Bäckerin bin ich zuverlässig und ruhig."),
    ] as [([String], String)])
    func floorWithStrengths(qualities: [String], floor: String) throws {
        let description = try Self.description(of: "de-sparse")
        let checker = Self.sanitizer()
        let skills = checker.skillCheck(technologies: [], softSkills: qualities, stated: [], against: description)

        let written = try checker.summaryFloor(
            of: Self.baker, summary: "Ich arbeite als Bäckerin.", most: CVDataSanitizer.summaryMost, qualities: skills.softSkills, against: description
        )

        #expect(written == floor, "\(String(describing: written)) \(skills.softSkills)")
    }

    @Test("The final check keeps the strengths sentence of a floor, and the capitalised qualities of the skills list; in a plain draft too",
          arguments: [true, false])
    func finalCheckKeepsTheFloor(isRich: Bool) async throws {
        try await DraftDepth.$pinned.withValue(isRich) {
            let description = try Self.description(of: "de-sparse")
            let checker = Self.sanitizer()
            let skills = checker.skillCheck(
                technologies: [], softSkills: ["zuverlässigkeit", "präzision", "kreativität", "detailgenauigkeit"], stated: [], against: description
            )
            let floor = try checker.summaryFloor(
                of: Self.baker, summary: "Ich arbeite als Bäckerin.", most: CVDataSanitizer.summaryMost, qualities: skills.softSkills, against: description
            )

            let final = try checker.sanitize(
                Self.baker, writing: DraftWriting(summary: floor, roleDescriptions: [], technologies: [], softSkills: skills.softSkills),
                against: description
            )

            #expect(final.summary == "Ich arbeite als Bäckerin. Als Bäckerin arbeite ich mit Zuverlässigkeit und Präzision.", "\(String(describing: final.summary))")
            #expect(final.skills.filter { $0.kind == .softSkill }.map(\.name) == ["Zuverlässigkeit", "Präzision", "Kreativität", "Detailgenauigkeit"])
        }
    }

    // MARK: A stem matches through its umlaut

    @Test("A summary sentence that names the work through a verb of the title's stem is kept, whether the title writes an umlaut the verb lacks or not", arguments: [
        ("Bäckerin", "Ich backe Brot mit Präzision und Zuverlässigkeit."),
        ("Verkäuferin", "Ich verkaufe Obst und Gemüse mit Freundlichkeit."),
        ("Wäscherin", "Ich wasche Hemden und Tischdecken mit Sorgfalt."),
    ])
    func stemThroughAnUmlaut(title: String, sentence: String) throws {
        let verdict = try Self.summaryCheck("Ich arbeite als \(title). \(sentence)", title: title)

        #expect(verdict.rejected.isEmpty, "\(verdict.rejected)")
        #expect(verdict.kept == ["Ich arbeite als \(title).", sentence], "\(verdict.kept)")
    }

    @Test("A summary sentence whose verb is none of the title's work still goes, for saying nothing of it", arguments: [
        ("Bäckerin", "Ich forme Brot mit Präzision und Zuverlässigkeit."),
        ("Bäckerin", "Ich verkaufe Obst und Gemüse mit Freundlichkeit."),
        ("Verkäuferin", "Ich backe Brot mit Präzision und Zuverlässigkeit."),
    ])
    func stemOfAnotherWork(title: String, sentence: String) throws {
        let verdict = try Self.summaryCheck("Ich arbeite als \(title). \(sentence)", title: title)

        #expect(verdict.kept == ["Ich arbeite als \(title)."], "\(verdict.kept)")
        #expect(verdict.rejected.first { $0.sentence == sentence }?.reason == CVDataSanitizer.namesNoWork, "\(verdict.rejected)")
    }

    /// The summary check of the sparse draft: the title is the only fact, and the `work` is the topic the request names.
    private static func summaryCheck(_ summary: String, title: String) throws -> CVDataSanitizer.SummaryVerdict {
        try sanitizer().summaryCheck(
            of: CVData(personalInfo: PersonalInfo(title: title)), summary: summary, field: title, work: [title], duties: [], qualities: [],
            against: "Ich bin \(title) und arbeite jeden Tag für unsere Kunden."
        )
    }
}

/// A dictionary that reads a word as written, as the device's German one does: a noun is known with its capital and not in lower
/// case, and every other word is known as it is. It knows no word of English, which no German quality is.
private struct GermanDictionary: WordList {
    private static let nouns: Set<String> = [
        "Bäckerin", "Verkäuferin", "Wäscherin", "Brot", "Brötchen", "Kuchen", "Kunden", "Obst", "Gemüse", "Hemden", "Tischdecken",
        "Zuverlässigkeit", "Präzision", "Kreativität", "Detailgenauigkeit", "Geduld", "Ordnung", "Teamfähigkeit", "Sorgfalt",
        "Freundlichkeit", "Verständnis",
    ]
    private static let lowerCaseNouns = Set(nouns.map { $0.lowercased() })

    func knows(_ word: String, inLanguage language: String) -> Bool? {
        switch language {
        case "de": word.first?.isUppercase == true ? Self.nouns.contains(word) : !Self.lowerCaseNouns.contains(word)
        case "en": false
        default: true
        }
    }
}
