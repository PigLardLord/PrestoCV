import Testing
import Foundation

// The checks of the legacy app's catalog that no other catalog needs. The checks that every catalog must pass are in
// StringCatalogTests, run for this catalog and for the new app's.

@Suite("Localization catalog")
struct LocalizationCatalogTests {

    // MARK: Exemptions

    /// Texts that read the same in every language: symbols, abbreviations, formats.
    static let sameInEveryLanguage: Set<String> = [
        "%@. %@", "ai.generation.character_count", "common.ok", "cv.title.numbered", "export.font_preview_sample", "field.url",
        "format.required_indicator",
    ]

    /// Words that happen to be written the same in English and in these languages.
    static let sameInSomeLanguages: [String: Set<String>] = [
        "common.error": ["es"],
        "error.subject.cv": ["es", "fr", "it"],
        "export.color.minimal": ["de"],
        "export.color.modern": ["de"],
        "export.file_name": ["es", "fr", "it"],
        "export.font.modern": ["de"],
        "field.description": ["fr"],
        "section.certifications": ["fr"],
        "section.details": ["de"],
    ]

    /// Keys that a branch that has not landed yet is still rewriting or removing. An entry without a defect left
    /// fails `exemptionsAreStillNeeded`, so each one has to go as soon as its branch has landed.
    static let pendingKeys: Set<String> = []

    /// Keys that the code builds from other values, so that no literal names them.
    static let dynamicKeyPrefixes = ["language.level."]

    /// Names that keep their capital letter inside a sentence: Apple Intelligence, Siri, and the Settings app of the
    /// iPhone and of the Mac ("Ajustes del Sistema", "Réglages Système", "Impostazioni di Sistema").
    static let properNames: Set<String> = [
        "Apple", "Intelligence", "Siri", "Ajustes", "Réglages", "Impostazioni", "Sistema", "Système",
    ]

    /// Keys whose text is the name of a person in every language.
    static let personNames: Set<String> = ["export.font_preview_name"]

    /// Proper names that the text of one key keeps capitalised inside a sentence: the person, the city, the school and
    /// the degree of the example description on the AI screen.
    static let properNamesOfKey: [String: Set<String>] = [
        "ai.generation.example_text": [
            "Maria", "Rossi", "Don", "Milani", "Bologna", "Bolonia", "Bologne", "Bolonha",
            "Ciencias", "Educación", "Universidad", "Scienze", "Formazione", "Ciências", "Educação", "Universidade",
        ],
    ]

    /// Only the AI texts are checked for a promise of availability in the legacy catalog.
    static let promiseKeyPrefix = "ai."

    /// The exemptions of the legacy catalog, as the checks take them.
    static let legacyRules = StringRules(
        sameInEveryLanguage: sameInEveryLanguage,
        sameInSomeLanguages: sameInSomeLanguages,
        pendingKeys: pendingKeys,
        dynamicKeyPrefixes: dynamicKeyPrefixes,
        properNames: properNames,
        personNames: personNames,
        properNamesOfKey: properNamesOfKey,
        promiseKeyPrefix: promiseKeyPrefix,
        viewFolders: ["PrestoCV"]
    )

    static let catalogPath = "PrestoCV/Localizable.xcstrings"

    /// The Swift sources whose text reaches the user: the app, and the legacy packages it links.
    static let shippedFolders = [
        "PrestoCV", "PrestoCVCore/Sources/PrestoCVCore", "CVPDFExporter/Sources/CVPDFExporter", "CVGeneratorAI/Sources/CVGeneratorAI",
    ]

    private static func catalog() throws -> LocalizationCatalog {
        try LocalizationCatalog(contentsOf: Repository.root.appendingPathComponent(catalogPath))
    }

    // MARK: Tests

    @Test("The German texts call a CV a Lebenslauf, as the rest of the German app does")
    func germanTextsSayLebenslauf() throws {
        let catalog = try Self.catalog()
        let cv = try NSRegularExpression(pattern: #"\bCVs?\b"#)

        let english = catalog.keys.filter { key in
            (catalog.texts(of: key, in: "de") ?? []).contains { text in
                cv.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
            }
        }

        #expect(english.isEmpty, "German texts that say CV: \(english)")
    }

    @Test("The title of a CV with none names it a CV, with the word for one that the app uses in each language")
    func untitledCVSaysCV() throws {
        let catalog = try Self.catalog()

        for language in LocalizationCatalog.languages {
            // "New CV", "Nuovo CV", "Lebenslauf", "Novo currículo": the word for a CV ends the title of a new one
            let newCV = try #require(catalog.texts(of: "editor.new_cv", in: language)?.first, "editor.new_cv in \(language)")
            let word = try #require(newCV.split(separator: " ").last.map(String.init))
            for untitled in catalog.texts(of: "cv.untitled", in: language) ?? [] {
                #expect(untitled.range(of: word, options: .caseInsensitive) != nil,
                        "cv.untitled should say \(word) in \(language), as the rest of the app does: \(untitled)")
            }
        }
    }

    @Test("A capital letter is expected at the start of a sentence, in an abbreviation and in a proper name")
    func titleCaseWordsSkipsLegitimateCapitals() throws {
        #expect(try StringChecks.titleCaseWords(in: "Crea Tu CV Perfecto", properNames: Self.properNames) == ["Tu", "Perfecto"])
        #expect(try StringChecks.titleCaseWords(in: "Crea tu CV perfecto", properNames: Self.properNames).isEmpty)
        #expect(try StringChecks.titleCaseWords(in: "Impossibile creare il PDF. Riprova.", properNames: Self.properNames).isEmpty)
        #expect(try StringChecks.titleCaseWords(in: "C1 - Avanzado", properNames: Self.properNames).isEmpty)
        #expect(try StringChecks.titleCaseWords(in: "O Apple Intelligence está desativado. Abra Ajustes.", properNames: Self.properNames).isEmpty)
    }

    @Test("The product is called PrestoCV in every language")
    func productIsCalledPrestoCV() throws {
        let catalog = try Self.catalog()

        for language in LocalizationCatalog.languages {
            let welcome = catalog.texts(of: "welcome.title", in: language) ?? []
            #expect(welcome.count == 1 && welcome[0].contains("PrestoCV"), "welcome.title does not name PrestoCV in \(language)")
        }
    }

    @Test("A promise of availability is found as a word, in any case; a text without one, or a duration, passes")
    func availabilityPromiseIsFoundAsAWord() {
        #expect(StringChecks.availabilityPromise(in: "Getting ready, available soon", language: "en") == "soon")
        #expect(StringChecks.availabilityPromise(in: "In preparazione, presto disponibile", language: "it") == "presto")
        #expect(StringChecks.availabilityPromise(in: "Bald verfügbar", language: "de") == "bald")
        #expect(StringChecks.availabilityPromise(in: "Try again later.", language: "en") == "later")
        #expect(StringChecks.availabilityPromise(in: "Riprova più tardi.", language: "it") == "più tardi")
        #expect(StringChecks.availabilityPromise(in: "Downloading the model", language: "en") == nil)
        #expect(StringChecks.availabilityPromise(in: "Not available right now", language: "en") == nil)
        #expect(StringChecks.availabilityPromise(in: "Apple Intelligence is busy right now. Please try again.", language: "en") == nil)
        #expect(StringChecks.availabilityPromise(in: "This can take up to a minute.", language: "en") == nil, "A duration is not a promise of availability")
    }

    @Test("The welcome speaks to everyone, not to a man or to a woman")
    func welcomeIsGenderNeutral() throws {
        let catalog = try Self.catalog()
        // A welcome that opens with the adjective agrees with the person: "Benvenuto", "Bienvenida". The noun inside
        // a sentence speaks to everyone ("Ti diamo il benvenuto", "Te damos la bienvenida"), and so does the French
        // "Bienvenue" that opens one, where "Bienvenu" is the adjective of a man.
        let gendered = [
            "es": #"^Bienvenid[oa]s?\b"#,
            "fr": #"^Bienvenus?\b"#,
            "it": #"^Benvenut[oaie]\b"#,
            "pt": #"^Bem-vind[oa]s?\b"#,
        ]

        for (language, pattern) in gendered {
            let form = try NSRegularExpression(pattern: pattern)
            for text in catalog.texts(of: "welcome.title", in: language) ?? [] {
                let match = form.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
                #expect(match == nil, "welcome.title speaks to a man or to a woman in \(language): \(text)")
            }
        }
    }

    @Test("The text of a view is looked up in the catalog, not written in the code")
    func viewsHaveNoHardCodedText() throws {
        let catalog = try Self.catalog()
        let views = "Text|Label|Button|Section|Toggle|TextField|SecureField|Picker|Menu|NavigationLink|DisclosureGroup|LabeledContent|ProgressView|Link"
        let modifiers = "navigationTitle|accessibilityLabel|accessibilityHint|accessibilityValue|help|badge"
        let patterns = [
            "\\b(?:\(views))\\(\\s*\(stringLiteral)",
            "\\.(?:\(modifiers))\\(\\s*\(stringLiteral)",
        ]
        var hardCoded: [String] = []
        for file in try SwiftSource.trackedFiles(in: ["PrestoCV"]).map(SwiftSource.init(url:)) {
            for pattern in patterns {
                for literal in file.code.matches(of: pattern) {
                    let format = literal.asFormatKey
                    let isLookedUp = catalog.strings[literal] != nil || catalog.strings[format] != nil
                        || catalog.strings[literal.asNumberFormatKey] != nil
                    // A text of values and symbols only, such as "\(a) / \(b)", has nothing to translate.
                    let hasWords = format.replacingOccurrences(of: "%@", with: "").range(of: #"\p{L}{2,}"#, options: .regularExpression) != nil
                    if !isLookedUp && hasWords {
                        hardCoded.append("\"\(literal)\" (\(file.path))")
                    }
                }
            }
        }

        #expect(hardCoded.isEmpty, "Text written in the code instead of the catalog: \(hardCoded)")
    }

    @Test("An error message is looked up in the catalog, not written in the code")
    func errorMessagesAreNotWrittenInTheCode() throws {
        let violations = try StringChecks.hardCodedErrorMessages(
            catalog: try Self.catalog(), sources: try SwiftSource.trackedFiles(in: Self.shippedFolders))

        #expect(violations.isEmpty, "Files that write the message of an error in the code: \(violations)")
    }
}
