import Testing
import Foundation
import PDFKit
@testable import PrestoCV
@testable import PrestoCVCore

/// The PDF that the export sheet makes, with the real renderer: its headings and fixed words are in the language the
/// CV is written in, whatever the language of the phone.
@MainActor
@Suite("Export - the PDF in the language of the CV")
struct ExportDocumentLanguageTests {

    /// Luca writes his CV in English for a job abroad, on a phone in Italian
    private static let englishCV = CVModel(
        name: "Luca – Sales",
        personalInfo: PersonalInfo(
            name: "Luca Ferrari", title: "Sales Manager", location: "Milan, Italy", email: "luca.ferrari@example.com",
            profile: "Sales and operations manager with over 20 years of experience in industrial distribution. Built and led "
                + "teams of up to 15 people, managed key accounts worth EUR 12M a year and introduced the company's first CRM."
        ),
        relevant_experience: [
            Experience(title: "Sales Manager", company: "Bianchi Componenti S.p.A.", location: "Monza", period: "2015 – 2024",
                       description: "- Led a team of 12 sales representatives across Lombardy and Piedmont"),
        ],
        languages: [Language(name: "Italian", level: .native)]
    )

    private func pdfText(of cv: CVModel, appLanguage: String) async throws -> String {
        let environment = try await ExportTestEnvironment.make()
        defer { environment.cleanUp() }
        let viewModel = CVExportSheetViewModel(
            cv: cv,
            exportService: environment.makeService(),
            preferencesStore: InMemoryExportPreferencesStore(),
            documentLanguageSink: { _ in },
            documentLanguageDetector: DocumentLanguageDetector(preferredLanguages: [appLanguage], read: NaturalLanguageReader.read),
            previewDebounce: .zero
        )
        viewModel.selectedTemplateId = "professional"

        await viewModel.requestPreview().value

        let pdf = try #require(viewModel.sharePDF, "\(viewModel.errorMessage ?? "no PDF")")
        let text = try #require(PDFDocument(url: pdf.url)?.string)
        await viewModel.stop().value
        // A design may set its headings in capitals, and a long line wraps: compare words, ignoring case
        return text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    @Test("An English CV exported on an Italian phone has English headings, \"at\" and \"Native\"", .timeLimit(.minutes(2)))
    func englishCVOnAnItalianPhone() async throws {
        let text = try await pdfText(of: Self.englishCV, appLanguage: "it-IT")

        #expect(text.localizedCaseInsensitiveContains("Work experience"))
        #expect(text.localizedCaseInsensitiveContains("at Bianchi"))
        #expect(text.localizedCaseInsensitiveContains("Native"))
        for italian in ["Esperienza professionale", "presso", "Madrelingua"] {
            #expect(!text.localizedCaseInsensitiveContains(italian), "\(italian) is in the PDF")
        }
    }

    @Test("A language chosen for the CV wins: the same CV set to Italian has Italian headings", .timeLimit(.minutes(2)))
    func chosenLanguageWins() async throws {
        var cv = Self.englishCV
        cv.documentLanguage = "it"

        let text = try await pdfText(of: cv, appLanguage: "en-US")

        #expect(text.localizedCaseInsensitiveContains("Esperienza professionale"))
        #expect(text.localizedCaseInsensitiveContains("Madrelingua"))
    }
}
