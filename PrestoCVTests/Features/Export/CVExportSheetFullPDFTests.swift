import Testing
import Foundation
@testable import PrestoCV
@testable import PrestoCVCore

/// The PDF full screen: the preview of the export sheet opens the PDF that is shared, with all its pages, and closing it
/// leaves the sheet as it was.
@MainActor
@Suite("CVExportSheetViewModel Tests - the full PDF")
struct CVExportSheetFullPDFTests {

    private func makeViewModel(
        _ service: MockCVExportService = MockCVExportService(),
        cv: CVModel = .exportable
    ) -> CVExportSheetViewModel {
        let viewModel = CVExportSheetViewModel(
            cv: cv,
            exportService: service,
            preferencesStore: InMemoryExportPreferencesStore(),
            documentLanguageSink: { _ in },
            lookSink: { _ in },
            exportPolicy: .standard,
            documentLanguageDetector: englishDocumentLanguageDetector,
            appLocale: Locale(identifier: "en"),
            previewDebounce: .zero
        )
        viewModel.selectedTemplateId = "modern"
        return viewModel
    }

    private func threePages(in service: MockCVExportService) async {
        await service.setExportedPDF(ExportedPDF(url: URL(fileURLWithPath: "/tmp/three.pdf"), pageCount: 3, thumbnail: nil))
    }

    // MARK: - Opening

    @Test("The full PDF is the PDF the share button shares")
    func fullPDFIsTheSharedPDF() async {
        let service = MockCVExportService()
        await threePages(in: service)
        let viewModel = makeViewModel(service)
        await viewModel.requestPreview().value

        viewModel.showFullPDF()

        #expect(viewModel.fullPDF == viewModel.sharePDF)
        #expect(viewModel.fullPDF?.url == URL(fileURLWithPath: "/tmp/three.pdf"))
        #expect(viewModel.fullPDF?.pageCount == 3)
    }

    @Test("Nothing opens before the PDF is rendered")
    func nothingOpensBeforeThePDF() async {
        let viewModel = makeViewModel()

        #expect(!viewModel.canShowFullPDF)
        viewModel.showFullPDF()

        #expect(viewModel.fullPDF == nil)
    }

    @Test("Nothing opens while the PDF is rendering")
    func nothingOpensWhileRendering() async {
        let service = MockCVExportService()
        await service.enqueueExport(.success(URL(fileURLWithPath: "/tmp/slow.pdf")), held: true)
        let viewModel = makeViewModel(service)
        let task = viewModel.requestPreview()
        await service.waitUntilHeld(.export)

        #expect(viewModel.isPreparingPDF)
        #expect(!viewModel.canShowFullPDF)
        viewModel.showFullPDF()
        #expect(viewModel.fullPDF == nil)

        await service.releaseHeld(.export)
        await task.value
        #expect(viewModel.canShowFullPDF)
    }

    @Test("Nothing opens for a CV without a name, which gets no PDF")
    func nothingOpensWithoutAName() async {
        let viewModel = makeViewModel(cv: CVModel(name: "Draft", personalInfo: PrestoCVCore.PersonalInfo(name: "", email: "ada@example.com")))
        await viewModel.requestPreview().value

        #expect(viewModel.sharePDF == nil)
        #expect(!viewModel.canShowFullPDF)
        #expect(viewModel.fullPDFAccessibilityLabel == nil)
        viewModel.showFullPDF()

        #expect(viewModel.fullPDF == nil)
    }

    // MARK: - Closing

    @Test("Closing the full PDF keeps the PDF of the sheet, so that it can still be shared")
    func closingKeepsThePDF() async {
        let service = MockCVExportService()
        await threePages(in: service)
        let viewModel = makeViewModel(service)
        await viewModel.requestPreview().value
        let shared = viewModel.sharePDF
        viewModel.showFullPDF()

        viewModel.closeFullPDF()

        #expect(viewModel.fullPDF == nil)
        #expect(viewModel.sharePDF == shared)
        #expect(viewModel.canShowFullPDF)
        #expect(await service.cleanedUpURLs.isEmpty)
    }

    @Test("Closing the full PDF keeps the choices of the sheet")
    func closingKeepsTheChoices() async {
        let viewModel = makeViewModel()
        viewModel.selectedColorPalette = .creative
        viewModel.selectedFontScheme = .serif
        viewModel.documentLanguageChoice = .italian
        await viewModel.requestPreview().value
        viewModel.showFullPDF()

        viewModel.closeFullPDF()

        #expect(viewModel.selectedTemplateId == "modern")
        #expect(viewModel.selectedColorPalette == .creative)
        #expect(viewModel.selectedFontScheme == .serif)
        #expect(viewModel.documentLanguageChoice == .italian)
    }

    @Test("It can be opened again after it was closed")
    func canBeOpenedAgain() async {
        let viewModel = makeViewModel()
        await viewModel.requestPreview().value
        viewModel.showFullPDF()
        viewModel.closeFullPDF()

        viewModel.showFullPDF()

        #expect(viewModel.fullPDF == viewModel.sharePDF)
    }

    // MARK: - The sheet going away

    @Test("The sheet closing removes the PDF with the full PDF")
    func stopClosesTheFullPDF() async {
        let service = MockCVExportService()
        let viewModel = makeViewModel(service)
        await viewModel.requestPreview().value
        viewModel.showFullPDF()

        await viewModel.stop().value

        #expect(viewModel.fullPDF == nil)
        #expect(viewModel.sharePDF == nil)
        #expect(await service.cleanedUpURLs == [URL(fileURLWithPath: "/tmp/test.pdf")])
    }

    @Test("A sheet covered by the full PDF has not gone away: its PDF stays, to be shown and shared")
    func coveredSheetKeepsItsPDF() async {
        let service = MockCVExportService()
        let viewModel = makeViewModel(service)
        await viewModel.requestPreview().value
        viewModel.showFullPDF()

        await viewModel.sheetDisappeared().value

        #expect(viewModel.fullPDF == viewModel.sharePDF)
        #expect(viewModel.sharePDF != nil)
        #expect(await service.cleanedUpURLs.isEmpty)
    }

    @Test("A sheet that goes away without the full PDF removes its PDF")
    func sheetGoingAwayRemovesItsPDF() async {
        let service = MockCVExportService()
        let viewModel = makeViewModel(service)
        await viewModel.requestPreview().value

        await viewModel.sheetDisappeared().value

        #expect(viewModel.sharePDF == nil)
        #expect(await service.cleanedUpURLs == [URL(fileURLWithPath: "/tmp/test.pdf")])
    }

    @Test("A new selection removes the PDF and so the full PDF")
    func newSelectionClosesTheFullPDF() async {
        let viewModel = makeViewModel()
        await viewModel.start()
        await viewModel.requestPreview().value
        viewModel.showFullPDF()
        #expect(viewModel.fullPDF != nil)

        viewModel.selectedColorPalette = .minimal

        #expect(viewModel.fullPDF == nil)
        #expect(!viewModel.canShowFullPDF)
        await viewModel.stop().value
    }

    // MARK: - What VoiceOver reads

    @Test("The preview is announced with the number of pages once the PDF is rendered")
    func labelHasThePageCount() async {
        let service = MockCVExportService()
        await threePages(in: service)
        let viewModel = makeViewModel(service)
        #expect(viewModel.fullPDFAccessibilityLabel == nil)

        await viewModel.requestPreview().value

        #expect(viewModel.fullPDFAccessibilityLabel == String(localized: "export.preview.open \(3)"))
        #expect(viewModel.fullPDFAccessibilityLabel?.contains("3") == true)
    }

    @Test("A one-page PDF is announced with the singular")
    func labelOfOnePage() async {
        let viewModel = makeViewModel()
        await viewModel.requestPreview().value

        #expect(viewModel.fullPDFAccessibilityLabel == String(localized: "export.preview.open \(1)"))
    }

    @Test("The announcement has a plural form for one page and one for several, in every language",
          arguments: ["de", "en", "es", "fr", "it", "pt"])
    func labelHasBothPluralForms(language: String) throws {
        let path = try #require(Bundle.main.path(forResource: language, ofType: "lproj"))
        let bundle = try #require(Bundle(path: path))

        let one = String(localized: "export.preview.open \(1)", bundle: bundle)
        let several = String(localized: "export.preview.open \(3)", bundle: bundle)

        #expect(one.contains("1"))
        #expect(several.contains("3"))
        // The same sentence with the other number is a different one: the noun changes with it
        #expect(one.replacingOccurrences(of: "1", with: "3") != several)
        #expect(several != "export.preview.open 3")
    }

    @Test("In English the announcement reads Show the full PDF, with one page and with several")
    func englishLabel() throws {
        let path = try #require(Bundle.main.path(forResource: "en", ofType: "lproj"))
        let bundle = try #require(Bundle(path: path))

        #expect(String(localized: "export.preview.open \(1)", bundle: bundle) == "Show the full PDF, 1 page")
        #expect(String(localized: "export.preview.open \(3)", bundle: bundle) == "Show the full PDF, 3 pages")
    }
}
