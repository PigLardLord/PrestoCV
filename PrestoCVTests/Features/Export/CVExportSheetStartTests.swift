import Testing
import Foundation
@testable import PrestoCV
@testable import PrestoCVCore
@testable import CVPDFExporter

/// The sheet on screen: it loads the templates when it shows, makes the first preview of its own CV, and a new one for
/// each change of the selection until it closes.
@MainActor
@Suite("CVExportSheetViewModel Tests - the sheet on screen")
struct CVExportSheetStartTests {

    private let service = MockCVExportService()

    private func makeViewModel(
        cv: CVModel = .exportable,
        stored: ExportPreferences = ExportPreferences()
    ) -> CVExportSheetViewModel {
        CVExportSheetViewModel(
            cv: cv,
            exportService: service,
            preferencesStore: InMemoryExportPreferencesStore(stored: stored),
            documentLanguageSink: { _ in },
            exportPolicy: .standard,
            documentLanguageDetector: englishDocumentLanguageDetector,
            appLocale: Locale(identifier: "en"),
            previewDebounce: .zero
        )
    }

    /// Starts the sheet and returns once its first PDF is being made, which the service holds until the test lets it go.
    private func startHoldingTheFirstPDF(_ viewModel: CVExportSheetViewModel) async {
        await service.enqueueExport(.success(URL(fileURLWithPath: "/tmp/first.pdf")), held: true)
        await viewModel.start()
        await service.waitUntilHeld(.export)
    }

    private func finish(_ viewModel: CVExportSheetViewModel) async {
        await viewModel.stop().value
        await service.releaseHeld(.export)
    }

    // MARK: - Loading

    @Test("The sheet is loading until its templates are, and then selects one")
    func loadsTheTemplatesWhenItShows() async {
        let viewModel = makeViewModel()
        #expect(viewModel.isLoadingTemplates)

        await viewModel.start()

        #expect(!viewModel.isLoadingTemplates)
        #expect(viewModel.templates.map(\.id) == ["modern"])
        #expect(viewModel.selectedTemplateId == "modern")
        await viewModel.stop().value
    }

    @Test("A sheet whose templates cannot be loaded stops loading and says so")
    func stopsLoadingWhenTheTemplatesFail() async {
        await service.setAvailableTemplatesResult(.failure(AppError.unknown("Registry corrupted")))
        let viewModel = makeViewModel()

        await viewModel.start()

        #expect(!viewModel.isLoadingTemplates)
        #expect(viewModel.errorMessage == String(localized: "export.error.no_templates"))
        #expect(!viewModel.isPreviewLoading, "Without a template there is nothing to preview")
    }

    // MARK: - The first preview

    @Test("Showing the sheet makes the preview and the PDF of the CV it was opened with")
    func firstPreviewIsOfItsCV() async {
        let cv = CVModel(name: "Ward nurse", personalInfo: PersonalInfo(name: "Marta Rinaldi", email: "marta@example.com"))
        let viewModel = makeViewModel(cv: cv)

        await startHoldingTheFirstPDF(viewModel)

        #expect(viewModel.previewHTML != nil)
        #expect(await service.lastPreviewCV?.personalInfo == cv.personalInfo)
        #expect(await service.lastExportCV?.personalInfo == cv.personalInfo)
        await finish(viewModel)
    }

    @Test("The design chosen last makes one preview when the sheet shows, not one for each of its values")
    func restoredChoiceMakesOnePreview() async {
        let viewModel = makeViewModel(
            stored: ExportPreferences(templateId: "modern", colorPalette: .creative, fontScheme: .serif)
        )

        await startHoldingTheFirstPDF(viewModel)

        #expect(await service.generatePreviewHTMLCallCount == 1)
        #expect(await service.lastExportOptions?.customization == CustomizationOptions(colorPalette: .creative, fontScheme: .serif))
        await finish(viewModel)
    }

    // MARK: - A new preview for each choice

    @Test("While the sheet shows, a new template, palette, font or language makes a new preview",
          arguments: [
              "template",
              "palette",
              "font",
              "language",
          ])
    func eachChoiceMakesANewPreview(choice: String) async {
        await service.setAvailableTemplatesResult(.success([
            Template(id: "modern", name: "Modern", htmlContent: "<html></html>"),
            Template(id: "classic", name: "Classic", htmlContent: "<html></html>"),
        ]))
        let viewModel = makeViewModel()
        await startHoldingTheFirstPDF(viewModel)
        #expect(!viewModel.isPreviewLoading, "The first preview is made")

        switch choice {
        case "template": viewModel.selectedTemplateId = "classic"
        case "palette": viewModel.selectedColorPalette = .creative
        case "font": viewModel.selectedFontScheme = .serif
        default: viewModel.documentLanguageChoice = .french
        }

        #expect(viewModel.isPreviewLoading, "The \(choice) makes a new preview")
        await finish(viewModel)
    }

    @Test("Choosing what is already chosen makes no new preview")
    func sameChoiceMakesNoPreview() async {
        let viewModel = makeViewModel()
        await startHoldingTheFirstPDF(viewModel)

        viewModel.selectedColorPalette = viewModel.selectedColorPalette
        viewModel.selectedTemplateId = viewModel.selectedTemplateId

        #expect(!viewModel.isPreviewLoading)
        #expect(viewModel.isPreparingPDF, "The first PDF is still being made")
        await finish(viewModel)
    }

    @Test("Before the sheet shows, a choice makes no preview")
    func noPreviewBeforeTheSheetShows() {
        let viewModel = makeViewModel()

        viewModel.selectedTemplateId = "modern"
        viewModel.selectedColorPalette = .creative

        #expect(!viewModel.isPreviewLoading)
        #expect(viewModel.previewHTML == nil)
    }

    @Test("Once the sheet has closed, a choice makes no preview")
    func noPreviewAfterTheSheetCloses() async {
        let viewModel = makeViewModel()
        await startHoldingTheFirstPDF(viewModel)
        await finish(viewModel)

        viewModel.selectedColorPalette = .creative

        #expect(!viewModel.isPreviewLoading)
        #expect(!viewModel.isPreparingPDF)
    }
}
