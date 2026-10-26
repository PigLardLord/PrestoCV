import Testing
import Foundation
@testable import PrestoCV
@testable import PrestoCVCore

/// The export sheet shows the language of the PDF's headings, makes the preview and the PDF in it, and lets the user
/// change it: automatic is the language the CV is written in, and a language chosen for the CV wins.
@MainActor
@Suite("CVExportSheetViewModel Tests - the language of the PDF")
struct CVExportSheetLanguageTests {

    /// Luca's CV, written in English for a job abroad
    private static let englishCV = CVModel(
        name: "Luca – Sales",
        personalInfo: PersonalInfo(
            name: "Luca Ferrari", title: "Sales Manager", email: "luca.ferrari@example.com",
            profile: "Sales and operations manager with over 20 years of experience in industrial distribution. Built and led "
                + "teams of up to 15 people, managed key accounts worth EUR 12M a year and introduced the company's first CRM."
        )
    )

    /// The phone of the user is in Italian
    private func makeViewModel(
        cv: CVModel,
        service: MockCVExportService = MockCVExportService(),
        sink: @escaping DocumentLanguageSink = { _ in }
    ) -> CVExportSheetViewModel {
        let viewModel = CVExportSheetViewModel(
            cv: cv,
            exportService: service,
            preferencesStore: InMemoryExportPreferencesStore(),
            documentLanguageSink: sink,
            exportPolicy: .standard,
            documentLanguageDetector: DocumentLanguageDetector(preferredLanguages: ["it-IT"], read: NaturalLanguageReader.read),
            appLocale: Locale(identifier: "en"),
            previewDebounce: .zero
        )
        viewModel.selectedTemplateId = "modern"
        return viewModel
    }

    private func headings(in language: DocumentLanguage) -> String {
        String(format: String(localized: "export.language.headings"), language.name(in: Locale(identifier: "en")))
    }

    // MARK: - What the sheet shows

    @Test("An English CV on an Italian phone shows English headings before anything is made")
    func showsTheLanguageOfTheCV() {
        let viewModel = makeViewModel(cv: Self.englishCV)

        #expect(viewModel.documentLanguageChoice == nil, "The CV has no language of its own chosen")
        #expect(viewModel.documentLanguage == .english)
        #expect(viewModel.documentLanguageText == headings(in: .english))
        #expect(viewModel.automaticDocumentLanguageTitle == String(format: String(localized: "language.automatic"), "English"))
    }

    @Test("A CV with too few words to tell shows the app's language")
    func showsTheAppLanguageForAShortCV() {
        let viewModel = makeViewModel(cv: .exportable)

        #expect(viewModel.documentLanguage == .italian)
        #expect(viewModel.documentLanguageText == headings(in: .italian))
    }

    @Test("A language chosen for the CV wins over the language it is written in")
    func chosenLanguageWins() {
        var cv = Self.englishCV
        cv.documentLanguage = "de"

        let viewModel = makeViewModel(cv: cv)

        #expect(viewModel.documentLanguageChoice == .german)
        #expect(viewModel.documentLanguage == .german)
        #expect(viewModel.documentLanguageText == headings(in: .german))
    }

    @Test("The headings are named in the language of the app")
    func headingsTextNamesTheLanguage() {
        let viewModel = makeViewModel(cv: Self.englishCV)
        let appLanguage = Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en")

        #expect(viewModel.documentLanguageText.contains(appLanguage.localizedString(forLanguageCode: "en") ?? "English"))
    }

    // MARK: - What the sheet makes

    @Test("The preview and the PDF are made in the language the sheet shows")
    func previewAndPDFAreInTheShownLanguage() async {
        let service = MockCVExportService()
        let viewModel = makeViewModel(cv: Self.englishCV, service: service)

        await viewModel.requestPreview().value

        #expect(await service.lastPreviewCV?.documentLanguage == "en")
        #expect(await service.lastExportCV?.documentLanguage == "en")
        #expect(await service.lastExportCV?.personalInfo == Self.englishCV.personalInfo, "Only the language is set")
    }

    @Test("Choosing another language makes a new preview and PDF in it")
    func choosingALanguageRemakesThePDF() async {
        let service = MockCVExportService()
        let viewModel = makeViewModel(cv: Self.englishCV, service: service)
        let before = viewModel.selection

        viewModel.documentLanguageChoice = .french
        #expect(viewModel.selection != before, "A new language is a new selection, which the sheet makes a preview of")
        await viewModel.requestPreview().value

        #expect(viewModel.documentLanguage == .french)
        #expect(viewModel.documentLanguageText == headings(in: .french))
        #expect(await service.lastPreviewCV?.documentLanguage == "fr")
        #expect(await service.lastExportCV?.documentLanguage == "fr")
    }

    @Test("Going back to automatic makes the PDF in the language of the CV again")
    func backToAutomatic() async {
        let service = MockCVExportService()
        var cv = Self.englishCV
        cv.documentLanguage = "es"
        let viewModel = makeViewModel(cv: cv, service: service)

        viewModel.documentLanguageChoice = nil
        await viewModel.requestPreview().value

        #expect(viewModel.documentLanguage == .english)
        #expect(await service.lastExportCV?.documentLanguage == "en")
    }

    @Test("Automatic follows the CV the sheet exports: each sheet makes its PDF in the language of its own CV")
    func automaticFollowsTheCV() async {
        let service = MockCVExportService()
        let shortCV = makeViewModel(cv: .exportable, service: service)
        let englishCV = makeViewModel(cv: Self.englishCV, service: service)
        #expect(shortCV.documentLanguage == .italian)

        await englishCV.requestPreview().value

        #expect(englishCV.documentLanguage == .english)
        #expect(await service.lastExportCV?.documentLanguage == "en")
    }

    // MARK: - Where the language goes

    @Test("Each language chosen in the sheet goes to the CV, automatic as none")
    func chosenLanguageGoesToTheCV() {
        var sent: [DocumentLanguage?] = []
        let viewModel = makeViewModel(cv: Self.englishCV, sink: { sent.append($0) })

        viewModel.documentLanguageChoice = .french
        viewModel.documentLanguageChoice = .french
        viewModel.documentLanguageChoice = nil

        #expect(sent == [.french, nil], "The same language chosen again is not sent twice")
    }

    @Test("A design chosen in the sheet does not touch the language of the CV")
    func designDoesNotTouchTheLanguage() {
        var sent: [DocumentLanguage?] = []
        let viewModel = makeViewModel(cv: Self.englishCV, sink: { sent.append($0) })

        viewModel.selectedTemplateId = "classic"
        viewModel.selectedColorPalette = .creative
        viewModel.selectedFontScheme = .serif

        #expect(sent.isEmpty)
    }
}
