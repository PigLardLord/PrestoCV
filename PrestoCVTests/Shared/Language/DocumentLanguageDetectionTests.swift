import Testing
import Foundation
@testable import PrestoCV
@testable import PrestoCVCore

/// "Automatic" with the system's recognizer, on real CVs: the PDF is in the language the CV is written in, and in the
/// app's language when the CV's words do not tell it clearly.
@Suite("Document language detection - the system's recognizer on real CVs")
struct DocumentLanguageDetectionTests {

    private static let samples = ["technical_cv", "business_cv", "creative_cv", "academic_cv", "healthcare_cv"]

    private static let resources = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("PrestoCV/Resources", isDirectory: true)

    /// A bundled sample CV, in one of the six languages
    private static func sample(_ name: String, in language: DocumentLanguage) throws -> CVModel {
        let file = language == .english ? "\(name).json" : "\(name).\(language.rawValue).json"
        return try JSONDecoder().decode(CVModel.self, from: Data(contentsOf: resources.appendingPathComponent(file)))
    }

    private func detector(appLanguage: String) -> DocumentLanguageDetector {
        DocumentLanguageDetector(preferredLanguages: [appLanguage], read: NaturalLanguageReader.read)
    }

    /// A summary and two jobs, as Luca wrote them: in English, for a job abroad
    private static let englishCV = CVModel(
        personalInfo: PersonalInfo(
            name: "Luca Ferrari", title: "Sales Manager", location: "Milan, Italy",
            profile: "Sales and operations manager with over 20 years of experience in industrial distribution. Built and led "
                + "teams of up to 15 people, managed key accounts worth EUR 12M a year and introduced the company's first CRM."
        ),
        relevant_experience: [
            Experience(title: "Sales Manager", company: "Bianchi Componenti S.p.A.", location: "Monza", period: "2015 – 2024",
                       description: "- Led a team of 12 sales representatives across Lombardy and Piedmont\n- Grew revenue from EUR 8M to EUR 12M in five years"),
            Experience(title: "Logistics Coordinator", company: "TransAlpi Logistica S.r.l.", location: "Bergamo", period: "2002 – 2008",
                       description: "- Planned daily routes for a fleet of 30 trucks"),
        ]
    )

    // MARK: - The CV's own language

    @Test("Each sample CV is printed in the language it is written in, whatever the app's language",
          arguments: samples, DocumentLanguage.allCases)
    func samplesAreInTheirOwnLanguage(name: String, language: DocumentLanguage) throws {
        let cv = try Self.sample(name, in: language)
        let otherAppLanguage = language == .english ? "it" : "en"

        #expect(detector(appLanguage: otherAppLanguage).automaticLanguage(for: cv) == language)
    }

    @Test("An English CV on an Italian phone is printed in English")
    func englishCVOnAnItalianPhone() {
        #expect(detector(appLanguage: "it-IT").automaticLanguage(for: Self.englishCV) == .english)
    }

    // MARK: - The app's language

    @Test("A CV with a few job titles in English follows the app's language: many CVs keep English job titles")
    func englishJobTitlesAloneFollowTheApp() {
        let cv = CVModel(
            personalInfo: PersonalInfo(name: "Giulia Bianchi", title: "Key Account Manager"),
            relevant_experience: [
                Experience(title: "Key Account Manager", company: "Barilla"),
                Experience(title: "Junior Sales Analyst", company: "Ferrero"),
                Experience(title: "Customer Service Specialist", company: "Lavazza"),
            ]
        )

        #expect(detector(appLanguage: "it-IT").automaticLanguage(for: cv) == .italian)
    }

    @Test("A summary of a few words follows the app's language", arguments: [
        "Senior nurse.", "Experienced sales manager in Milan.", "Software engineer, iOS and Swift.",
    ])
    func shortSummaryFollowsTheApp(summary: String) {
        let cv = CVModel(personalInfo: PersonalInfo(profile: summary))

        #expect(detector(appLanguage: "de-DE").automaticLanguage(for: cv) == .german)
    }

    @Test("A CV in a language the PDF has no headings for follows the app's language, even one that looks like another",
          arguments: [
              // Swedish, which read as one of the six languages looks German
              "Sjuksköterska med tio års erfarenhet av akutsjukvård. Jag har arbetat på sjukhuset i Stockholm och lett ett team på åtta personer under fem år.",
              // Catalan, which looks Spanish
              "Infermera amb deu anys d'experiència a urgències. He treballat a l'hospital de Barcelona i sóc responsable d'un equip de vuit persones des de fa cinc anys.",
              // Dutch, which looks German
              "Verpleegkundige met tien jaar ervaring op de spoedeisende hulp. Ik heb gewerkt in het ziekenhuis van Amsterdam en was verantwoordelijk voor een team van acht mensen.",
          ])
    func unsupportedLanguageFollowsTheApp(summary: String) {
        let cv = CVModel(personalInfo: PersonalInfo(profile: summary))

        #expect(detector(appLanguage: "it-IT").automaticLanguage(for: cv) == .italian)
    }

    @Test("A CV with no words follows the app's language")
    func emptyCVFollowsTheApp() {
        #expect(detector(appLanguage: "fr-FR").automaticLanguage(for: CVModel()) == .french)
    }

    // MARK: - The recognizer

    @Test("The recognizer names the language of a text, and how likely each of the six languages is")
    func readerReadsTheLanguage() throws {
        let reading = NaturalLanguageReader.read(Self.englishCV.personalInfo.profile)

        #expect(reading.dominantLanguage == "en")
        #expect(try #require(reading.likelihoods[.english]) > 0.9)
    }

    @Test("The recognizer weighs only the six languages: a Japanese text is none of them")
    func readerWeighsOnlyTheSixLanguages() {
        let reading = NaturalLanguageReader.read("私は東京で十年間、看護師として病院で働いてきました。大学で看護学を学び、二〇一二年に卒業しました。")

        #expect(reading.dominantLanguage == "ja")
        #expect(reading.likelihoods.values.allSatisfy { $0 < DocumentLanguageDetector.minimumLikelihood })
    }
}
