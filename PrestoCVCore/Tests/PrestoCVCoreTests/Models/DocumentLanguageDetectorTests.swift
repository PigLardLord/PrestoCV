import Testing
import Foundation
import Synchronization
@testable import PrestoCVCore

/// What "Automatic" stands for: the language the CV is written in, when its own words tell it clearly, and otherwise
/// the language of the app. The recognizer is a stand-in here; the app's tests read real CVs with the system's one.
@Suite("DocumentLanguageDetector")
struct DocumentLanguageDetectorTests {

    /// A recognizer that gives the same reading for any text, and keeps the texts it was given
    final class FixedReader: Sendable {
        private let reading: DocumentLanguageDetector.Reading
        private let texts = Mutex<[String]>([])

        init(dominant: String?, likelihoods: [DocumentLanguage: Double]) {
            reading = DocumentLanguageDetector.Reading(dominantLanguage: dominant, likelihoods: likelihoods)
        }

        var readTexts: [String] { texts.withLock { $0 } }

        func read(_ text: String) -> DocumentLanguageDetector.Reading {
            texts.withLock { $0.append(text) }
            return reading
        }
    }

    private static let englishReader = FixedReader(dominant: "en", likelihoods: [.english: 0.99, .italian: 0.01])

    private func detector(_ reader: FixedReader, preferred: [String] = ["it-IT"]) -> DocumentLanguageDetector {
        DocumentLanguageDetector(preferredLanguages: preferred, read: reader.read)
    }

    /// A CV with a summary of twenty words
    private static let cvWithSummary = CVModel(
        personalInfo: PersonalInfo(
            title: "Sales Manager",
            profile: "Sales and operations manager with over twenty years of experience in industrial distribution, leading teams and key accounts."
        )
    )

    // MARK: - Detected

    @Test("A CV that reads clearly as a supported language is printed in it, whatever the app's language")
    func clearTextGivesItsLanguage() {
        let language = detector(FixedReader(dominant: "en", likelihoods: [.english: 0.99])).automaticLanguage(for: Self.cvWithSummary)

        #expect(language == .english)
    }

    @Test("Each supported language can be the CV's own", arguments: DocumentLanguage.allCases)
    func everySupportedLanguageCanBeDetected(language: DocumentLanguage) {
        let reader = FixedReader(dominant: "\(language.rawValue)-XX", likelihoods: [language: 0.95])

        #expect(detector(reader, preferred: ["ja"]).automaticLanguage(for: Self.cvWithSummary) == language)
    }

    // MARK: - Falling back

    @Test("A CV with too few words follows the app's language: job titles alone are often in another language")
    func fewWordsFollowTheApp() {
        let cv = CVModel(
            personalInfo: PersonalInfo(name: "Luca Ferrari", title: "Sales Manager"),
            relevant_experience: [
                Experience(title: "Sales Manager", company: "Bianchi Componenti"),
                Experience(title: "Area Sales Representative", company: "Bianchi Componenti"),
                Experience(title: "Logistics Coordinator", company: "TransAlpi Logistica"),
            ]
        )

        #expect(detector(Self.englishReader).automaticLanguage(for: cv) == .italian)
    }

    @Test("A CV with no text follows the app's language")
    func emptyCVFollowsTheApp() {
        #expect(detector(Self.englishReader, preferred: ["de-AT", "en"]).automaticLanguage(for: CVModel()) == .german)
    }

    @Test("An unclear reading follows the app's language: a mixed text could be either", arguments: [0.5, 0.79])
    func unclearReadingFollowsTheApp(likelihood: Double) {
        let reader = FixedReader(dominant: "en", likelihoods: [.english: likelihood, .italian: 1 - likelihood])

        #expect(detector(reader).automaticLanguage(for: Self.cvWithSummary) == .italian)
    }

    @Test("A CV in another language follows the app's language, even when it looks like a supported one")
    func otherLanguageFollowsTheApp() {
        // Swedish read as one of the six languages looks German
        let reader = FixedReader(dominant: "sv", likelihoods: [.german: 0.98])

        #expect(detector(reader).automaticLanguage(for: Self.cvWithSummary) == .italian)
    }

    @Test("A CV the recognizer cannot read follows the app's language")
    func unreadableTextFollowsTheApp() {
        let reader = FixedReader(dominant: nil, likelihoods: [:])

        #expect(detector(reader).automaticLanguage(for: Self.cvWithSummary) == .italian)
    }

    @Test("With neither a clear text nor a supported app language, the PDF is in English")
    func noLanguageAtAllIsEnglish() {
        #expect(detector(Self.englishReader, preferred: ["ja-JP"]).automaticLanguage(for: CVModel()) == .english)
    }

    // MARK: - What is read

    @Test("The recognizer reads the summary, the titles and the descriptions, and none of the names")
    func readsTheCVsOwnWords() throws {
        let reader = FixedReader(dominant: "en", likelihoods: [.english: 0.99])
        let cv = CVModel(
            personalInfo: PersonalInfo(
                name: "Luca Ferrari", title: "TitleWord", location: "Milano", email: "luca@example.com",
                profile: "SummaryWord and enough other words to make the text long enough for the recognizer to read it"
            ),
            relevant_experience: [
                Experience(title: "JobWord", company: "Bianchi Componenti", location: "Monza", description: "JobDescriptionWord"),
            ],
            education: [Education(degree: "DegreeWord", school: "Politecnico di Milano", description: "SchoolDescriptionWord")],
            skills: [Skill(name: "Salesforce")],
            interests: ["Montagna"]
        )

        _ = detector(reader).automaticLanguage(for: cv)

        let text = try #require(reader.readTexts.first)
        for word in ["SummaryWord", "TitleWord", "JobWord", "JobDescriptionWord", "DegreeWord", "SchoolDescriptionWord"] {
            #expect(text.contains(word), "\(word) is not read")
        }
        for name in ["Luca", "Milano", "example.com", "Bianchi", "Monza", "Politecnico", "Salesforce", "Montagna"] {
            #expect(!text.contains(name), "\(name) is read")
        }
    }

    @Test("The recognizer reads at most the first characters of a long CV, so that it can run on every change")
    func readsABoundedText() throws {
        let reader = FixedReader(dominant: "en", likelihoods: [.english: 0.99])
        let entry = Experience(title: "Nurse", description: String(repeating: "Cared for patients on a busy ward. ", count: 40))
        let cv = CVModel(relevant_experience: Array(repeating: entry, count: 10))

        _ = detector(reader).automaticLanguage(for: cv)

        let text = try #require(reader.readTexts.first)
        #expect(text.count == DocumentLanguageDetector.maximumCharacters)
    }

    // MARK: - The chosen language

    @Test("The language chosen for a CV is its document language, when the PDF can be written in it", arguments: [
        ("it", DocumentLanguage?.some(.italian)), ("pt-BR", .portuguese), ("DE", .german), ("ja", nil), ("", nil),
    ])
    func chosenLanguage(tag: String, expected: DocumentLanguage?) {
        #expect(CVModel(documentLanguage: tag).chosenDocumentLanguage == expected)
    }

    @Test("A CV with no document language has no chosen language")
    func noChosenLanguage() {
        #expect(CVModel().chosenDocumentLanguage == nil)
    }
}
