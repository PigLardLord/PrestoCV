import Testing
import PrestoCVDomain
@testable import PrestoCVImporting

/// A language and its level are told by where they stand: the level on the line under the language, a name next to a
/// level (ADR 0027, #303). Every CV here is invented.
@Suite("Reading a language and its level by where they stand")
struct LanguageLevelTests {

    private func read(_ text: String) -> Findings {
        let (document, sections) = pasted(text)
        var findings = Findings(document: document)
        for section in sections where section.kind == .languages { LanguageReader.read(section, into: &findings) }
        return findings
    }

    private func summary(_ found: Findings) -> [String] {
        found.cv.languages.map { "\($0.name.value)=\($0.level?.value.rawValue ?? "-")" }
    }

    // MARK: A level on a line of its own

    /// The heading of the languages, a language, the words of a native speaker, another language and its CEFR level.
    private static let ownLine: [(String, String, String, String)] = [
        ("Languages", "English", "Native", "Spanish"), ("Lingue", "Inglese", "Madrelingua", "Spagnolo"),
        ("Sprachen", "Englisch", "Muttersprache", "Spanisch"), ("Idiomas", "Inglés", "Lengua materna", "Alemán"),
        ("Langues", "Anglais", "Langue maternelle", "Espagnol"), ("Idiomas", "Inglês", "Língua materna", "Espanhol"),
    ]

    @Test("A native language on the line under it is its level, in each language's words", arguments: ownLine)
    func nativeUnderTheLanguage(heading: String, name: String, native: String, other: String) {
        let found = read("\(heading)\n\(name)\n\(native)\n\(other)\nB2")
        #expect(summary(found) == ["\(name)=native", "\(other)=b2"])
        #expect(found.cv.languages[0].level?.reading == .languageLevel)
        #expect(found.cv.languages[0].level?.check == nil)
        #expect(found.unplaced.isEmpty)
    }

    @Test("The native level and a level in words on their own lines give each language its own")
    func nativeAndWords() {
        let found = read("Languages\nEnglish\nNative\nSpanish\nAdvanced\nFrench\nB1")
        #expect(summary(found) == ["English=native", "Spanish=-", "French=b1"])
        #expect(found.cv.languages[1].levelWords?.value == "Advanced")
        #expect(found.unplaced.isEmpty)
    }

    @Test("A native level under a language that has words for its level replaces them")
    func nativeReplacesWords() {
        let found = read("Languages\nEnglish – fluent\nNative")
        #expect(summary(found) == ["English=native"])
        #expect(found.cv.languages[0].levelWords == nil)
        #expect(found.unplaced.map(\.text) == ["fluent"])
    }

    @Test("A line that only starts with the word Native is no level, and neither is a native word away from its language")
    func nativeNeedsItsPlace() {
        let notALevel = read("Languages\nEnglish\nNative Android developer")
        #expect(summary(notALevel) == ["English=-"])
        #expect(notALevel.unplaced.map(\.text) == ["Native Android developer"])

        let secondLevel = read("Languages\nEnglish: C1\nNative")
        #expect(summary(secondLevel) == ["English=c1"])
        #expect(secondLevel.unplaced.map(\.text) == ["Native"])

        let apart = read("Languages\nEnglish\nCambridge Certificate\nNative")
        #expect(summary(apart) == ["English=-"])
        #expect(apart.unplaced.map(\.text) == ["Cambridge Certificate", "Native"])

        let before = read("Languages\nNative\nEnglish")
        #expect(summary(before) == ["English=-"])
        #expect(before.unplaced.map(\.text) == ["Native"])
    }

    @Test("A native statement alone on its line that no language can take is shown, in each language's words", arguments: ownLine)
    func nativeThatCannotBeTaken(heading: String, name: String, native: String, other: String) {
        let afterALevel = read("\(heading)\n\(name): C1\n\(native)")
        #expect(summary(afterALevel) == ["\(name)=c1"])
        #expect(afterALevel.unplaced.map(\.text) == [native])

        let afterSeveral = read("\(heading)\n\(name), \(other)\n\(native)")
        #expect(summary(afterSeveral) == ["\(name)=-", "\(other)=-"])
        #expect(afterSeveral.unplaced.map(\.text) == [native])

        let afterAnotherLine = read("\(heading)\n\(name)\nCambridge Certificate\n\(native)")
        #expect(afterAnotherLine.cv.languages.map { $0.level?.value } == [nil])
        #expect(afterAnotherLine.unplaced.map(\.text) == ["Cambridge Certificate", native])
    }

    @Test("The label of the mother tongues above their language is a label, not a text left out")
    func nativeLabelAboveItsLanguage() {
        let found = read("Lingue\nMadrelingua\nItaliano\nAltre lingue\nInglese\nB2")
        #expect(summary(found) == ["Italiano=-", "Inglese=b2"])
        #expect(found.unplaced.isEmpty)
    }

    // MARK: A language outside the list

    @Test("A name next to a CEFR level or the words of a native speaker is a language, whatever the name", arguments: [
        ("Quechua: C1", "Quechua", LanguageProficiency.c1), ("Tigrinya – Native", "Tigrinya", .native),
        ("Wolof (B2)", "Wolof", .b2), ("C1 – Quechua", "Quechua", .c1), ("Tigrinya: Muttersprache", "Tigrinya", .native),
        ("Wolof - madrelingua", "Wolof", .native), ("Quechua (langue maternelle)", "Quechua", .native),
        ("QUECHUA | A2", "QUECHUA", .a2), ("Tigrinya / B1", "Tigrinya", .b1),
    ])
    func nameNextToALevel(text: String, name: String, level: LanguageProficiency) throws {
        let found = read("Languages\n\(text)")
        let language = try #require(found.cv.languages.first)
        #expect(found.cv.languages.count == 1)
        #expect(language.name.value == name)
        #expect(language.level?.value == level)
        #expect(language.level?.reading == .languageLevel)
        #expect(language.level?.check == nil)
        #expect(found.unplaced.isEmpty)
    }

    @Test("Languages of a line, listed ones and others, are told apart item by item")
    func severalInALine() {
        let found = read("Languages\nEnglish – Native, Quechua: C1; Wolof (A2)")
        #expect(summary(found) == ["English=native", "Quechua=c1", "Wolof=a2"])
        #expect(found.unplaced.isEmpty)
    }

    @Test("The languages of the second example of the study, in each language's words", arguments: [
        ("Languages", "German: Native", "Slovenian: C1", "Thai: A2"), ("Lingue", "Tedesco: madrelingua", "Sloveno: C1", "Tailandese: A2"),
        ("Sprachen", "Deutsch: Muttersprache", "Slowenisch: C1", "Thai: A2"), ("Idiomas", "Alemán: lengua materna", "Esloveno: C1", "Tailandés: A2"),
        ("Langues", "Allemand: langue maternelle", "Slovène: C1", "Thaï: A2"), ("Idiomas", "Alemão: língua materna", "Esloveno: C1", "Tailandês: A2"),
    ])
    func languagesOutsideTheOldList(heading: String, first: String, second: String, third: String) {
        let found = read("\(heading)\n\(first)\n\(second)\n\(third)")
        #expect(found.cv.languages.map { $0.level?.value } == [.native, .c1, .a2])
        #expect(found.unplaced.isEmpty)
    }

    @Test("A name above a line that is only a level is a language; above anything else it is not")
    func nameAboveItsLevel() {
        let found = read("Languages\nQuechua\nNative\nTigrinya\nC1\nWolof | B2")
        #expect(summary(found) == ["Quechua=native", "Tigrinya=c1", "Wolof=b2"])
        #expect(found.unplaced.isEmpty)

        let row = read("Languages\nQuechua | Native\nTigrinya\t\tC1")
        #expect(summary(row) == ["Quechua=native", "Tigrinya=c1"])

        let words = read("Languages\nQuechua\nAdvanced")
        #expect(words.cv.languages.isEmpty)
        #expect(words.unplaced.map(\.text) == ["Quechua", "Advanced"])

        let other = read("Languages\nQuechua\nProject Manager")
        #expect(other.cv.languages.isEmpty)
        #expect(other.unplaced.map(\.text) == ["Quechua", "Project Manager"])
    }

    private static let labels = [
        "Level: B2", "Niveau: B2", "Sprachniveau: B2", "Livello: B2", "Nivel – B2", "Reading: B2", "Listening – C1", "Cambridge Certificate – C1",
        "Goethe-Zertifikat (B2)", "Cambridge Certificate C1", "Project Manager B2", "Room 12: C1", "Native: C1", "Mother tongue: Native",
    ]

    @Test("A label of a level, a skill or a certificate beside a level is no language", arguments: labels)
    func labelsAreNoLanguage(text: String) {
        let found = read("Languages\n\(text)")
        #expect(found.cv.languages.isEmpty)
        #expect(found.unplaced.map(\.text) == [text])
    }

    /// "Reading: B2" under a language is that language's level in a Europass grid: it stays as before.
    @Test("A label beside a level, under a language with none, is no language of its own", arguments: labels.filter { !["Reading", "Listening"].contains(where: $0.hasPrefix) })
    func labelsUnderALanguage(text: String) {
        let found = read("Languages\nEnglish\n\(text)")
        #expect(summary(found) == ["English=-"])
        #expect(found.unplaced.map(\.text) == [text])
    }

    @Test("Several levels, or a name with a level and more beside it, are no language by their shape")
    func shapeIsStrict() {
        let two = read("Languages\nQuechua: C1 and B2")
        #expect(two.cv.languages.isEmpty)
        #expect(two.unplaced.map(\.text) == ["Quechua: C1 and B2"])

        let long = read("Languages\nTranslator of legal texts for the courts: C1")
        #expect(long.cv.languages.isEmpty)
        #expect(long.unplaced.map(\.text) == ["Translator of legal texts for the courts: C1"])

        let lower = read("Languages\nnative speaker of the group: C1")
        #expect(lower.cv.languages.isEmpty)
    }
}
