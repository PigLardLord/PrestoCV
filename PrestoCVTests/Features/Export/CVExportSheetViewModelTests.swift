import Testing
import Foundation
@testable import PrestoCV
@testable import PrestoCVCore
@testable import CVPDFExporter

// MARK: - Mock CVExportService

extension ExportedPDF {
    /// A PDF the tests do not look into: one page, no thumbnail
    init(testFile url: URL) {
        self.init(url: url, pageCount: 1, thumbnail: nil)
    }
}

/// A service whose answers the tests choose. A call can be held until the test lets it go, which keeps the tests
/// free of sleeps; a held call ignores cancellation, like the real service, which cannot interrupt a render
/// that is under way.
actor MockCVExportService: CVExportServiceProtocol {

    enum Call {
        case preview
        case export
    }

    struct Response<Value: Sendable>: Sendable {
        var isHeld = false
        var result: Result<Value, Error>
    }

    private var availableTemplatesResult: Result<[Template], Error> = .success([
        Template(
            id: "modern",
            name: "Modern",
            description: "Modern template",
            htmlContent: "<html></html>",
            supportedVariables: []
        )
    ])

    private var previewResponses: [Response<String>] = []
    private var defaultPreview = Response<String>(result: .success("<html><body>Preview</body></html>"))

    private var exportResponses: [Response<ExportedPDF>] = []
    private var defaultExport = Response<ExportedPDF>(result: .success(ExportedPDF(testFile: URL(fileURLWithPath: "/tmp/test.pdf"))))

    private var heldCalls: [Call: [CheckedContinuation<Void, Never>]] = [:]
    private var waiters: [(call: Call, count: Int, continuation: CheckedContinuation<Void, Never>)] = []

    private(set) var availableTemplatesCalled = false
    private(set) var generatePreviewHTMLCallCount = 0
    private(set) var exportCallCount = 0
    private(set) var lastExportOptions: ExportOptions?
    private(set) var lastExportTemplateId: String?
    private(set) var cleanedUpURLs: [URL] = []

    var generatePreviewHTMLCalled: Bool { generatePreviewHTMLCallCount > 0 }
    var exportCalled: Bool { exportCallCount > 0 }
    var cleanupTempFileCalled: Bool { !cleanedUpURLs.isEmpty }

    // MARK: Configuration

    func setAvailableTemplatesResult(_ result: Result<[Template], Error>) {
        availableTemplatesResult = result
    }

    func setGeneratePreviewHTMLResult(_ result: Result<String, Error>) {
        defaultPreview.result = result
    }

    func setExportResult(_ result: Result<URL, Error>) {
        defaultExport.result = result.map(ExportedPDF.init(testFile:))
    }

    func setExportedPDF(_ pdf: ExportedPDF) {
        defaultExport.result = .success(pdf)
    }

    /// The next call of `generatePreviewHTML` gets this answer, after the test lets it go if it is held;
    /// later calls get the default
    func enqueuePreview(_ result: Result<String, Error>, held: Bool = false) {
        previewResponses.append(Response(isHeld: held, result: result))
    }

    /// The next call of `export` gets this answer, after the test lets it go if it is held; later calls get the default
    func enqueueExport(_ result: Result<URL, Error>, held: Bool = false) {
        exportResponses.append(Response(isHeld: held, result: result.map(ExportedPDF.init(testFile:))))
    }

    // MARK: Holding calls

    /// Returns when `count` calls of this kind are held
    func waitUntilHeld(_ call: Call, count: Int = 1) async {
        if heldCalls[call, default: []].count >= count { return }
        await withCheckedContinuation { waiters.append((call, count, $0)) }
    }

    /// Lets the call that has been held the longest go on
    func releaseHeld(_ call: Call) {
        guard !heldCalls[call, default: []].isEmpty else { return }
        heldCalls[call, default: []].removeFirst().resume()
    }

    private func hold(_ call: Call) async {
        await withCheckedContinuation { continuation in
            heldCalls[call, default: []].append(continuation)
            var stillWaiting: [(call: Call, count: Int, continuation: CheckedContinuation<Void, Never>)] = []
            var satisfied: [CheckedContinuation<Void, Never>] = []
            for waiter in waiters {
                if waiter.call == call && heldCalls[call, default: []].count >= waiter.count {
                    satisfied.append(waiter.continuation)
                } else {
                    stillWaiting.append(waiter)
                }
            }
            waiters = stillWaiting
            satisfied.forEach { $0.resume() }
        }
    }

    // MARK: CVExportServiceProtocol

    func availableTemplates() async throws -> [Template] {
        availableTemplatesCalled = true
        return try availableTemplatesResult.get()
    }

    func generatePreviewHTML(
        cv: CVModel,
        templateId: String,
        options: ExportOptions
    ) async throws -> String {
        generatePreviewHTMLCallCount += 1
        let response = previewResponses.isEmpty ? defaultPreview : previewResponses.removeFirst()
        if response.isHeld {
            await hold(.preview)
        }
        return try response.result.get()
    }

    func export(
        cv: CVModel,
        templateId: String,
        options: ExportOptions
    ) async throws -> ExportedPDF {
        exportCallCount += 1
        lastExportOptions = options
        lastExportTemplateId = templateId
        let response = exportResponses.isEmpty ? defaultExport : exportResponses.removeFirst()
        if response.isHeld {
            await hold(.export)
        }
        return try response.result.get()
    }

    func cleanupTempFile(at url: URL) async {
        cleanedUpURLs.append(url)
    }
}

// MARK: - CVExportSheetViewModel Tests

extension CVModel {
    /// A CV the exporter accepts: it has a name and an email
    static let exportable = CVModel(
        name: "Test CV",
        personalInfo: PrestoCVCore.PersonalInfo(name: "Ada Lovelace", email: "ada@example.com")
    )
}

@MainActor
@Suite("CVExportSheetViewModel Tests")
struct CVExportSheetViewModelTests {

    private let cv = CVModel.exportable

    private func makeViewModel(
        _ service: MockCVExportService,
        template: String? = "modern",
        debounce: Duration = .zero,
        store: InMemoryExportPreferencesStore = InMemoryExportPreferencesStore()
    ) -> CVExportSheetViewModel {
        let viewModel = CVExportSheetViewModel(exportService: service, preferencesStore: store, previewDebounce: debounce)
        viewModel.selectedTemplateId = template
        return viewModel
    }

    // MARK: - Loading templates

    @Test("loadTemplates populates templates array")
    func loadTemplatesPopulatesArray() async {
        let mockService = MockCVExportService()
        let viewModel = makeViewModel(mockService, template: nil)

        await viewModel.loadTemplates()

        #expect(viewModel.templates.count == 1)
        #expect(viewModel.templates.first?.id == "modern")
        #expect(viewModel.selectedTemplateId == "modern")
        #expect(await mockService.availableTemplatesCalled)
    }

    @Test("loadTemplates shows a message the user can act on, not the error's own text")
    func loadTemplatesShowsLocalizedMessage() async {
        let mockService = MockCVExportService()
        await mockService.setAvailableTemplatesResult(.failure(AppError.unknown("Registry corrupted at 0x1F")))
        let viewModel = makeViewModel(mockService, template: nil)

        await viewModel.loadTemplates()

        #expect(viewModel.templates.isEmpty)
        #expect(viewModel.errorMessage == String(localized: "export.error.no_templates"))
    }

    @Test("loadTemplates does not show a cancelled load as an error")
    func loadTemplatesIgnoresCancellation() async {
        let mockService = MockCVExportService()
        await mockService.setAvailableTemplatesResult(.failure(CancellationError()))
        let viewModel = makeViewModel(mockService, template: nil)

        await viewModel.loadTemplates()

        #expect(viewModel.errorMessage == nil)
    }

    @Test("loadTemplates tells the user when no template is installed")
    func loadTemplatesReportsEmptyList() async {
        let mockService = MockCVExportService()
        await mockService.setAvailableTemplatesResult(.success([]))
        let viewModel = makeViewModel(mockService, template: nil)

        await viewModel.loadTemplates()

        #expect(viewModel.templates.isEmpty)
        #expect(viewModel.selectedTemplateId == nil)
        #expect(viewModel.errorMessage == String(localized: "export.error.no_templates"))
    }

    // MARK: - Preview

    @Test("requestPreview makes the HTML and the options of the selection")
    func requestPreviewMakesHTMLAndOptions() async {
        let mockService = MockCVExportService()
        let viewModel = makeViewModel(mockService)
        viewModel.selectedColorPalette = .creative
        viewModel.selectedFontScheme = .serif

        await viewModel.requestPreview(for: cv).value

        #expect(viewModel.previewHTML?.contains("Preview") == true)
        #expect(viewModel.previewOptions?.templateId == "modern")
        #expect(viewModel.previewOptions?.customization == CustomizationOptions(colorPalette: .creative, fontScheme: .serif))
        #expect(await mockService.generatePreviewHTMLCalled)
    }

    @Test("requestPreview clears the preview when no template is selected")
    func requestPreviewClearsWithoutTemplate() async {
        let mockService = MockCVExportService()
        let viewModel = makeViewModel(mockService)
        await viewModel.requestPreview(for: cv).value
        viewModel.selectedTemplateId = nil

        await viewModel.requestPreview(for: cv).value

        #expect(viewModel.previewHTML == nil)
        #expect(viewModel.previewOptions == nil)
        #expect(!viewModel.isPreviewLoading)
        #expect(!viewModel.isPreparingPDF)
        #expect(await mockService.generatePreviewHTMLCallCount == 1)
    }

    @Test("isPreviewLoading is true while the preview is made and false after")
    func isPreviewLoadingDuringGeneration() async {
        let mockService = MockCVExportService()
        await mockService.enqueuePreview(.success("<html>held</html>"), held: true)
        let viewModel = makeViewModel(mockService)

        let task = viewModel.requestPreview(for: cv)
        await mockService.waitUntilHeld(.preview)

        #expect(viewModel.isPreviewLoading, "isPreviewLoading should be true during generation")
        await mockService.releaseHeld(.preview)
        await task.value
        #expect(!viewModel.isPreviewLoading, "isPreviewLoading should be false after generation completes")
    }

    @Test("a failed preview ends the loading, shows a localized message and asks for no PDF")
    func failedPreviewShowsMessage() async {
        let mockService = MockCVExportService()
        await mockService.setGeneratePreviewHTMLResult(.failure(AppError.unknown("Template engine exploded")))
        let viewModel = makeViewModel(mockService)

        await viewModel.requestPreview(for: cv).value

        #expect(!viewModel.isPreviewLoading)
        #expect(!viewModel.isPreparingPDF)
        #expect(viewModel.previewHTML == nil)
        #expect(viewModel.previewOptions == nil)
        #expect(viewModel.errorMessage == String(localized: "export.error.preview_failed"))
        #expect(await mockService.exportCallCount == 0)
    }

    @Test("a later request wins over an earlier one that finishes after it")
    func laterRequestWins() async {
        let mockService = MockCVExportService()
        await mockService.enqueuePreview(.success("<html>first</html>"), held: true)
        await mockService.enqueuePreview(.success("<html>second</html>"))
        let viewModel = makeViewModel(mockService)

        let first = viewModel.requestPreview(for: cv)
        await mockService.waitUntilHeld(.preview)
        let second = viewModel.requestPreview(for: cv)
        await second.value
        #expect(viewModel.previewHTML == "<html>second</html>")

        await mockService.releaseHeld(.preview)
        await first.value

        #expect(viewModel.previewHTML == "<html>second</html>", "the late result of the first request is left out")
        #expect(!viewModel.isPreviewLoading)
    }

    @Test("the spinner stays on until the latest request is done, even when an earlier one ends first")
    func loadingStaysOnUntilLatestRequestEnds() async {
        let mockService = MockCVExportService()
        await mockService.enqueuePreview(.success("<html>first</html>"), held: true)
        await mockService.enqueuePreview(.success("<html>second</html>"), held: true)
        let viewModel = makeViewModel(mockService)

        let first = viewModel.requestPreview(for: cv)
        await mockService.waitUntilHeld(.preview, count: 1)
        let second = viewModel.requestPreview(for: cv)
        await mockService.waitUntilHeld(.preview, count: 2)
        await mockService.releaseHeld(.preview)
        await first.value

        #expect(viewModel.isPreviewLoading, "the superseded request must not turn the spinner off")
        #expect(viewModel.previewHTML == nil)

        await mockService.releaseHeld(.preview)
        await second.value
        #expect(!viewModel.isPreviewLoading)
        #expect(viewModel.previewHTML == "<html>second</html>")
    }

    @Test("a selection that changes in quick succession makes one preview")
    func quickChangesMakeOnePreview() async {
        let mockService = MockCVExportService()
        let viewModel = makeViewModel(mockService, debounce: .milliseconds(500))

        // The three requests follow each other without a pause, so the first two are cancelled while they wait
        viewModel.requestPreview(for: cv)
        viewModel.selectedColorPalette = .modern
        viewModel.requestPreview(for: cv)
        viewModel.selectedFontScheme = .serif
        let last = viewModel.requestPreview(for: cv)
        await last.value

        #expect(await mockService.generatePreviewHTMLCallCount == 1)
        #expect(viewModel.previewOptions?.customization == CustomizationOptions(colorPalette: .modern, fontScheme: .serif))
    }

    // MARK: - Cancellation

    @Test("stop ends the work in progress and a result that arrives later is not shown")
    func stopDiscardsLateResults() async {
        let mockService = MockCVExportService()
        await mockService.enqueuePreview(.success("<html>late</html>"), held: true)
        let viewModel = makeViewModel(mockService)
        let task = viewModel.requestPreview(for: cv)
        await mockService.waitUntilHeld(.preview)

        await viewModel.stop().value
        await mockService.releaseHeld(.preview)
        await task.value

        #expect(viewModel.previewHTML == nil)
        #expect(!viewModel.isPreviewLoading)
        #expect(!viewModel.isPreparingPDF)
        #expect(await mockService.exportCallCount == 0)
    }

    @Test("a request cancelled while its service call fails does not show the failure")
    func cancelledRequestShowsNoError() async {
        let mockService = MockCVExportService()
        await mockService.enqueuePreview(.failure(AppError.unknown("late failure")), held: true)
        let viewModel = makeViewModel(mockService)
        let task = viewModel.requestPreview(for: cv)
        await mockService.waitUntilHeld(.preview)

        await viewModel.stop().value
        await mockService.releaseHeld(.preview)
        await task.value

        #expect(viewModel.errorMessage == nil)
    }

    @Test("a request replaced while its export fails does not show the failure")
    func replacedRequestShowsNoExportError() async {
        let mockService = MockCVExportService()
        let secondFile = URL(fileURLWithPath: "/tmp/second.pdf")
        await mockService.enqueueExport(.failure(PDFExportError.renderingFailed("late failure")), held: true)
        await mockService.enqueueExport(.success(secondFile))
        let viewModel = makeViewModel(mockService)
        let first = viewModel.requestPreview(for: cv)
        await mockService.waitUntilHeld(.export)

        let second = viewModel.requestPreview(for: cv)
        await second.value
        await mockService.releaseHeld(.export)
        await first.value

        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.sharePDF?.url == secondFile)
    }

    @Test("a cancellation reported by the service is not shown")
    func serviceCancellationIsNotShown() async {
        let mockService = MockCVExportService()
        await mockService.setGeneratePreviewHTMLResult(.failure(CancellationError()))
        let viewModel = makeViewModel(mockService)

        await viewModel.requestPreview(for: cv).value

        #expect(viewModel.errorMessage == nil)
        #expect(!viewModel.isPreviewLoading)
        #expect(!viewModel.isPreparingPDF)
    }

    // MARK: - The PDF to share

    @Test("the PDF is kept with its page count and the picture of its first page")
    func pdfKeepsPageCountAndThumbnail() async {
        let mockService = MockCVExportService()
        let thumbnail = Data([0x89, 0x50, 0x4E, 0x47])
        await mockService.setExportedPDF(ExportedPDF(url: URL(fileURLWithPath: "/tmp/three.pdf"), pageCount: 3, thumbnail: thumbnail))
        let viewModel = makeViewModel(mockService)

        await viewModel.requestPreview(for: cv).value

        #expect(viewModel.sharePDF?.pageCount == 3)
        #expect(viewModel.sharePDF?.thumbnail == thumbnail)
    }

    @Test("the page count is told once the PDF is rendered, and not before")
    func pageCountTextFollowsThePDF() async {
        let mockService = MockCVExportService()
        await mockService.setExportedPDF(ExportedPDF(url: URL(fileURLWithPath: "/tmp/three.pdf"), pageCount: 3, thumbnail: nil))
        let viewModel = makeViewModel(mockService)
        #expect(viewModel.pageCountText == nil)

        await viewModel.requestPreview(for: cv).value

        #expect(viewModel.pageCountText == String(format: String(localized: "export.page_count"), 3))
    }

    @Test("the pages have the same white border on every side")
    func pagesHaveAUniformBorder() {
        let margins = makeViewModel(MockCVExportService()).currentExportOptions().margins

        #expect(margins.top == CVExportSheetViewModel.pageMargin)
        #expect(margins.left == margins.top)
        #expect(margins.bottom == margins.top)
        #expect(margins.right == margins.top)
    }

    @Test("the PDF is rendered after the preview, with the same options")
    func pdfIsRenderedWithThePreviewOptions() async {
        let mockService = MockCVExportService()
        let viewModel = makeViewModel(mockService)
        viewModel.selectedColorPalette = .creative
        viewModel.selectedFontScheme = .serif

        await viewModel.requestPreview(for: cv).value

        #expect(viewModel.sharePDF == ExportedPDF(testFile: URL(fileURLWithPath: "/tmp/test.pdf")))
        #expect(viewModel.sharePDF?.fileName == "test.pdf")
        #expect(!viewModel.isPreparingPDF)
        let exportOptions = await mockService.lastExportOptions
        let previewOptions = viewModel.previewOptions
        #expect(exportOptions?.maxPages == CVExportSheetViewModel.maxPages)
        #expect(exportOptions?.maxPages == previewOptions?.maxPages)
        #expect(exportOptions?.templateId == "modern")
        #expect(exportOptions?.customization == previewOptions?.customization)
        #expect(exportOptions?.pageSize.width == previewOptions?.pageSize.width)
        #expect(exportOptions?.pageSize.height == previewOptions?.pageSize.height)
        #expect(await mockService.lastExportTemplateId == "modern")
    }

    @Test("the PDF is not rendered while the preview is still being made")
    func pdfWaitsForThePreview() async {
        let mockService = MockCVExportService()
        await mockService.enqueuePreview(.success("<html>held</html>"), held: true)
        let viewModel = makeViewModel(mockService)

        let task = viewModel.requestPreview(for: cv)
        await mockService.waitUntilHeld(.preview)

        #expect(await mockService.exportCallCount == 0)
        #expect(viewModel.isPreparingPDF)
        #expect(viewModel.sharePDF == nil)
        await mockService.releaseHeld(.preview)
        await task.value
        #expect(await mockService.exportCallCount == 1)
    }

    @Test("a PDF that cannot be rendered shows a localized message and nothing to share")
    func failedPDFShowsMessage() async {
        let mockService = MockCVExportService()
        await mockService.setExportResult(.failure(AppError.unknown("Export error 0x7")))
        let viewModel = makeViewModel(mockService)

        await viewModel.requestPreview(for: cv).value

        #expect(viewModel.sharePDF == nil)
        #expect(!viewModel.isPreparingPDF)
        #expect(viewModel.errorMessage == String(localized: "export.error.failed"))
        #expect(viewModel.previewHTML != nil, "the preview is still shown")
    }

    @Test("a CV that needs too many pages says how many")
    func tooManyPagesShowsBothNumbers() async {
        let mockService = MockCVExportService()
        await mockService.setExportResult(.failure(PDFExportError.tooManyPages(count: 12, limit: 10)))
        let viewModel = makeViewModel(mockService)

        await viewModel.requestPreview(for: cv).value

        #expect(viewModel.errorMessage == String(format: String(localized: "export.error.too_many_pages"), 12, 10))
        #expect(viewModel.sharePDF == nil)
    }

    @Test("a CV without name or email asks for them")
    func missingNameAndEmailAsksForThem() async {
        let mockService = MockCVExportService()
        await mockService.setExportResult(.failure(PDFExportError.invalidContent("Document must have an email")))
        let viewModel = makeViewModel(mockService)

        await viewModel.requestPreview(for: cv).value

        #expect(viewModel.errorMessage == String(localized: "export.error.missing_name_email"))
    }

    @Test("a new selection removes the PDF of the old one at once and its file after")
    func newSelectionRemovesOldPDF() async {
        let mockService = MockCVExportService()
        let oldFile = URL(fileURLWithPath: "/tmp/old.pdf")
        await mockService.enqueueExport(.success(oldFile))
        let viewModel = makeViewModel(mockService)
        await viewModel.requestPreview(for: cv).value
        #expect(viewModel.sharePDF?.url == oldFile)

        viewModel.selectedColorPalette = .minimal
        let task = viewModel.requestPreview(for: cv)

        #expect(viewModel.sharePDF == nil, "the old PDF no longer matches the selection")
        #expect(viewModel.isPreparingPDF)
        await task.value
        #expect(await mockService.cleanedUpURLs == [oldFile])
        #expect(viewModel.sharePDF != nil)
    }

    @Test("a PDF that finishes for a replaced request is removed and not shown")
    func latePDFIsRemoved() async {
        let mockService = MockCVExportService()
        let lateFile = URL(fileURLWithPath: "/tmp/late.pdf")
        let currentFile = URL(fileURLWithPath: "/tmp/current.pdf")
        await mockService.enqueueExport(.success(lateFile), held: true)
        await mockService.enqueueExport(.success(currentFile))
        let viewModel = makeViewModel(mockService)

        let first = viewModel.requestPreview(for: cv)
        await mockService.waitUntilHeld(.export)
        viewModel.selectedFontScheme = .serif
        let second = viewModel.requestPreview(for: cv)
        await second.value
        await mockService.releaseHeld(.export)
        await first.value

        #expect(viewModel.sharePDF?.url == currentFile)
        #expect(await mockService.cleanedUpURLs == [lateFile])
    }

    @Test("stop still removes the PDF when the view model is released before the cleanup runs")
    func stopRemovesThePDFOfAReleasedViewModel() async {
        let mockService = MockCVExportService()
        var viewModel: CVExportSheetViewModel? = makeViewModel(mockService)
        await viewModel?.requestPreview(for: cv).value
        #expect(viewModel?.sharePDF != nil)

        // The sheet is dismissed and its view model released before the cleanup task gets to run
        let cleanup = viewModel?.stop()
        viewModel = nil
        await cleanup?.value

        #expect(await mockService.cleanedUpURLs == [URL(fileURLWithPath: "/tmp/test.pdf")])
    }

    @Test("a new request still removes the displaced PDF when the view model is released before the cleanup runs")
    func newRequestRemovesTheDisplacedPDFOfAReleasedViewModel() async {
        let mockService = MockCVExportService()
        var viewModel: CVExportSheetViewModel? = makeViewModel(mockService)
        await viewModel?.requestPreview(for: cv).value
        #expect(viewModel?.sharePDF != nil)

        let task = viewModel?.requestPreview(for: cv)
        viewModel = nil
        await task?.value

        #expect(await mockService.cleanedUpURLs == [URL(fileURLWithPath: "/tmp/test.pdf")])
    }

    @Test("stop removes the PDF, and the sheet is left idle")
    func stopRemovesThePDF() async {
        let mockService = MockCVExportService()
        let viewModel = makeViewModel(mockService)
        await viewModel.requestPreview(for: cv).value
        #expect(viewModel.sharePDF != nil)

        await viewModel.stop().value

        #expect(viewModel.sharePDF == nil)
        #expect(await mockService.cleanedUpURLs == [URL(fileURLWithPath: "/tmp/test.pdf")])
        #expect(!viewModel.isPreviewLoading)
        #expect(!viewModel.isPreparingPDF)
    }

    @Test("a PDF that finishes after stop is removed and not shown")
    func pdfFinishingAfterStopIsRemoved() async {
        let mockService = MockCVExportService()
        await mockService.enqueueExport(.success(URL(fileURLWithPath: "/tmp/late.pdf")), held: true)
        let viewModel = makeViewModel(mockService)
        let task = viewModel.requestPreview(for: cv)
        await mockService.waitUntilHeld(.export)

        await viewModel.stop().value
        await mockService.releaseHeld(.export)
        await task.value

        #expect(viewModel.sharePDF == nil)
        #expect(await mockService.cleanedUpURLs == [URL(fileURLWithPath: "/tmp/late.pdf")])
    }

    // MARK: - A CV the exporter would refuse

    @Test("a CV without a name or an email gets its preview but no PDF, and a hint instead of an alert",
          arguments: [
              PrestoCVCore.PersonalInfo(name: "", email: ""),
              PrestoCVCore.PersonalInfo(name: "Ada Lovelace", email: ""),
              PrestoCVCore.PersonalInfo(name: "", email: "ada@example.com"),
              PrestoCVCore.PersonalInfo(name: "   ", email: "\n")
          ])
    func incompleteCVGetsNoPDF(personalInfo: PrestoCVCore.PersonalInfo) async {
        let mockService = MockCVExportService()
        let viewModel = makeViewModel(mockService)

        await viewModel.requestPreview(for: CVModel(name: "Draft", personalInfo: personalInfo)).value

        #expect(viewModel.previewHTML != nil, "the preview shows what is missing")
        #expect(viewModel.shareBlocker == String(localized: "export.error.missing_name_email"))
        #expect(viewModel.sharePDF == nil)
        #expect(!viewModel.isPreparingPDF)
        #expect(viewModel.errorMessage == nil, "no alert when the sheet opens")
        #expect(await mockService.exportCallCount == 0)
    }

    @Test("a complete CV has nothing in the way of the PDF")
    func completeCVHasNoBlocker() async {
        let viewModel = makeViewModel(MockCVExportService())

        await viewModel.requestPreview(for: cv).value

        #expect(viewModel.shareBlocker == nil)
        #expect(viewModel.sharePDF != nil)
    }

    @Test("a CV that becomes complete gets its PDF at the next request")
    func blockerClearsWhenCVIsComplete() async {
        let mockService = MockCVExportService()
        let viewModel = makeViewModel(mockService)
        await viewModel.requestPreview(for: CVModel(name: "Draft")).value
        #expect(viewModel.shareBlocker != nil)

        await viewModel.requestPreview(for: cv).value

        #expect(viewModel.shareBlocker == nil)
        #expect(viewModel.sharePDF != nil)
        #expect(await mockService.exportCallCount == 1)
    }

    // MARK: - Selection

    @Test("the selection value changes with the template, the palette and the font")
    func selectionChangesWithEachChoice() {
        let viewModel = makeViewModel(MockCVExportService(), template: nil)
        let initial = viewModel.selection

        viewModel.selectedTemplateId = "modern"
        let withTemplate = viewModel.selection
        viewModel.selectedColorPalette = .creative
        let withPalette = viewModel.selection
        viewModel.selectedFontScheme = .serif
        let withFont = viewModel.selection

        #expect(initial != withTemplate)
        #expect(withTemplate != withPalette)
        #expect(withPalette != withFont)
        #expect(withFont == ExportSelection(templateId: "modern", colorPalette: .creative, fontScheme: .serif))
        #expect(viewModel.selection == withFont, "the same choice is the same value")
    }

    @Test("currentExportOptions includes selected customizations")
    func currentExportOptionsIncludesCustomizations() {
        let viewModel = makeViewModel(MockCVExportService())
        viewModel.selectedColorPalette = .minimal
        viewModel.selectedFontScheme = .modern

        let options = viewModel.currentExportOptions()

        #expect(options.templateId == "modern")
        #expect(options.customization.colorPalette == .minimal)
        #expect(options.customization.fontScheme == .modern)
        #expect(options.maxPages == CVExportSheetViewModel.maxPages)
        #expect(options.maxPages != ExportOptions.default.maxPages)
    }

    @Test("aspectRatio uses previewOptions when available")
    func aspectRatioUsesPreviewOptions() async {
        let viewModel = makeViewModel(MockCVExportService())

        await viewModel.requestPreview(for: cv).value

        // A4 aspect ratio is approximately 0.707 (210/297)
        #expect(abs(viewModel.aspectRatio - 0.707) < 0.01, "A4 aspect ratio should be approximately 0.707")
    }

    @Test("aspectRatio uses current options when preview not loaded")
    func aspectRatioUsesCurrentOptions() {
        let viewModel = makeViewModel(MockCVExportService(), template: nil)

        #expect(abs(viewModel.aspectRatio - 0.707) < 0.01, "A4 aspect ratio should be approximately 0.707")
    }

    // MARK: - Errors

    @Test("a preview that the web view cannot load shows a localized message")
    func previewLoadFailureShowsMessage() {
        let viewModel = makeViewModel(MockCVExportService())

        viewModel.reportPreviewLoadFailure(AppError.unknown("WKErrorDomain 4"))

        #expect(viewModel.errorMessage == String(localized: "export.error.preview_failed"))
    }

    @Test("a preview load that is cancelled shows nothing")
    func cancelledPreviewLoadShowsNothing() {
        let viewModel = makeViewModel(MockCVExportService())

        viewModel.reportPreviewLoadFailure(CancellationError())

        #expect(viewModel.errorMessage == nil)
    }

    @Test("dismissError clears error message")
    func dismissErrorClearsMessage() {
        let viewModel = makeViewModel(MockCVExportService())
        viewModel.errorMessage = "Test error"

        viewModel.dismissError()

        #expect(viewModel.errorMessage == nil)
    }
}
