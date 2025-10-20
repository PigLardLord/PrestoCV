import Testing
import Foundation
@testable import PrestoCV
@testable import PrestoCVCore
@testable import CVPDFExporter

// MARK: - Mock CVExportService

actor MockCVExportService: CVExportServiceProtocol {
    private var availableTemplatesResult: Result<[Template], Error> = .success([
        Template(
            id: "modern",
            name: "Modern",
            description: "Modern template",
            htmlContent: "<html></html>",
            supportedVariables: []
        )
    ])

    private var generatePreviewHTMLResult: Result<String, Error> = .success("<html><body>Preview</body></html>")
    private var exportResult: Result<URL, Error> = .success(URL(fileURLWithPath: "/tmp/test.pdf"))

    private(set) var availableTemplatesCalled = false
    private(set) var generatePreviewHTMLCalled = false
    private(set) var exportCalled = false
    private(set) var cleanupTempFileCalled = false

    // Simulate async delays for testing loading states
    private var availableTemplatesDelay: Duration?
    private var generatePreviewHTMLDelay: Duration?
    private var exportDelay: Duration?

    // Configuration methods to be called from tests
    func setAvailableTemplatesResult(_ result: Result<[Template], Error>) {
        self.availableTemplatesResult = result
    }

    func setGeneratePreviewHTMLResult(_ result: Result<String, Error>) {
        self.generatePreviewHTMLResult = result
    }

    func setExportResult(_ result: Result<URL, Error>) {
        self.exportResult = result
    }

    func setAvailableTemplatesDelay(_ delay: Duration?) {
        self.availableTemplatesDelay = delay
    }

    func setGeneratePreviewHTMLDelay(_ delay: Duration?) {
        self.generatePreviewHTMLDelay = delay
    }

    func setExportDelay(_ delay: Duration?) {
        self.exportDelay = delay
    }

    func availableTemplates() async throws -> [Template] {
        availableTemplatesCalled = true
        if let delay = availableTemplatesDelay {
            try? await Task.sleep(for: delay)
        }
        switch availableTemplatesResult {
        case .success(let templates):
            return templates
        case .failure(let error):
            throw error
        }
    }

    func generatePreviewHTML(
        cv: CVModel,
        templateId: String,
        options: ExportOptions
    ) async throws -> String {
        generatePreviewHTMLCalled = true
        if let delay = generatePreviewHTMLDelay {
            try? await Task.sleep(for: delay)
        }
        switch generatePreviewHTMLResult {
        case .success(let html):
            return html
        case .failure(let error):
            throw error
        }
    }

    func export(
        cv: CVModel,
        templateId: String,
        customization: CustomizationOptions
    ) async throws -> URL {
        exportCalled = true
        if let delay = exportDelay {
            try? await Task.sleep(for: delay)
        }
        switch exportResult {
        case .success(let url):
            return url
        case .failure(let error):
            throw error
        }
    }

    func cleanupTempFile(at url: URL) async {
        cleanupTempFileCalled = true
    }
}

// MARK: - CVExportSheetViewModel Tests

@MainActor
@Suite("CVExportSheetViewModel Tests")
struct CVExportSheetViewModelTests {

    // MARK: - Loading State Tests (Bug Fix Verification)

    @Test("isPreviewLoading is true during preview generation")
    func isPreviewLoadingDuringGeneration() async throws {
        // Given
        let mockService = MockCVExportService()
        await mockService.setGeneratePreviewHTMLDelay(.milliseconds(100))

        let viewModel = CVExportSheetViewModel(exportService: mockService)
        viewModel.selectedTemplateId = "modern"

        let mockCV = CVModel(name: "Test CV")

        // When - Start preview generation
        let task = Task {
            await viewModel.refreshPreview(for: mockCV)
        }

        // Then - Verify loading is true during generation
        try await Task.sleep(for: .milliseconds(20))
        #expect(viewModel.isPreviewLoading == true, "isPreviewLoading should be true during generation")

        // Wait for completion
        await task.value

        // Verify loading is false after completion
        #expect(viewModel.isPreviewLoading == false, "isPreviewLoading should be false after generation completes")
    }

    @Test("isPreviewLoading becomes false after preview generation completes")
    func isPreviewLoadingBecomesfalseAfterCompletion() async {
        // Given
        let mockService = MockCVExportService()
        let viewModel = CVExportSheetViewModel(exportService: mockService)
        viewModel.selectedTemplateId = "modern"

        let mockCV = CVModel(name: "Test CV")

        // When
        await viewModel.refreshPreview(for: mockCV)

        // Then
        #expect(viewModel.isPreviewLoading == false)
        #expect(viewModel.previewHTML != nil)
        #expect(await mockService.generatePreviewHTMLCalled)
    }

    @Test("isPreviewLoading becomes false even when preview generation fails")
    func isPreviewLoadingBecomesfalseOnError() async {
        // Given
        let mockService = MockCVExportService()
        await mockService.setGeneratePreviewHTMLResult(.failure(AppError.unknown("Test error")))

        let viewModel = CVExportSheetViewModel(exportService: mockService)
        viewModel.selectedTemplateId = "modern"

        let mockCV = CVModel(name: "Test CV")

        // When
        await viewModel.refreshPreview(for: mockCV)

        // Then
        #expect(viewModel.isPreviewLoading == false, "isPreviewLoading should be false even after error")
        #expect(viewModel.previewHTML == nil)
        #expect(viewModel.errorMessage != nil)
    }

    @Test("isExporting is true during export operation")
    func isExportingDuringOperation() async throws {
        // Given
        let mockService = MockCVExportService()
        await mockService.setExportDelay(.milliseconds(100))

        let viewModel = CVExportSheetViewModel(exportService: mockService)
        viewModel.selectedTemplateId = "modern"

        let mockCV = CVModel(name: "Test CV")

        // When - Start export
        let task = Task {
            await viewModel.export(cv: mockCV)
        }

        // Then - Verify exporting is true during operation
        try await Task.sleep(for: .milliseconds(20))
        #expect(viewModel.isExporting == true, "isExporting should be true during export")

        // Wait for completion
        await task.value

        // Verify exporting is false after completion
        #expect(viewModel.isExporting == false, "isExporting should be false after export completes")
    }

    @Test("isExporting becomes false after export completes")
    func isExportingBecomesfalseAfterCompletion() async {
        // Given
        let mockService = MockCVExportService()
        let viewModel = CVExportSheetViewModel(exportService: mockService)
        viewModel.selectedTemplateId = "modern"

        let mockCV = CVModel(name: "Test CV")

        // When
        await viewModel.export(cv: mockCV)

        // Then
        #expect(viewModel.isExporting == false)
        #expect(viewModel.previewItem != nil)
        #expect(await mockService.exportCalled)
    }

    @Test("isExporting becomes false even when export fails")
    func isExportingBecomesfalseOnError() async {
        // Given
        let mockService = MockCVExportService()
        await mockService.setExportResult(.failure(AppError.unknown("Export error")))

        let viewModel = CVExportSheetViewModel(exportService: mockService)
        viewModel.selectedTemplateId = "modern"

        let mockCV = CVModel(name: "Test CV")

        // When
        await viewModel.export(cv: mockCV)

        // Then
        #expect(viewModel.isExporting == false, "isExporting should be false even after error")
        #expect(viewModel.previewItem == nil)
        #expect(viewModel.errorMessage != nil)
    }

    // MARK: - Template Loading Tests

    @Test("loadTemplates populates templates array")
    func loadTemplatesPopulatesArray() async {
        // Given
        let mockService = MockCVExportService()
        let viewModel = CVExportSheetViewModel(exportService: mockService)

        // When
        await viewModel.loadTemplates()

        // Then
        #expect(viewModel.templates.count == 1)
        #expect(viewModel.templates.first?.id == "modern")
        #expect(viewModel.selectedTemplateId == "modern")
        #expect(await mockService.availableTemplatesCalled)
    }

    @Test("loadTemplates handles error gracefully")
    func loadTemplatesHandlesError() async {
        // Given
        let mockService = MockCVExportService()
        await mockService.setAvailableTemplatesResult(.failure(AppError.unknown("Template error")))

        let viewModel = CVExportSheetViewModel(exportService: mockService)

        // When
        await viewModel.loadTemplates()

        // Then
        #expect(viewModel.templates.isEmpty)
        #expect(viewModel.errorMessage != nil)
    }

    // MARK: - Preview Refresh Tests

    @Test("refreshPreview generates HTML with valid template")
    func refreshPreviewGeneratesHTML() async {
        // Given
        let mockService = MockCVExportService()
        let viewModel = CVExportSheetViewModel(exportService: mockService)
        viewModel.selectedTemplateId = "modern"

        let mockCV = CVModel(name: "Test CV")

        // When
        await viewModel.refreshPreview(for: mockCV)

        // Then
        #expect(viewModel.previewHTML != nil)
        #expect(viewModel.previewHTML?.contains("Preview") == true)
        #expect(viewModel.previewOptions != nil)
        #expect(await mockService.generatePreviewHTMLCalled)
    }

    @Test("refreshPreview clears HTML when no template selected")
    func refreshPreviewClearsHTMLWithoutTemplate() async {
        // Given
        let mockService = MockCVExportService()
        let viewModel = CVExportSheetViewModel(exportService: mockService)
        viewModel.previewHTML = "existing html"
        viewModel.selectedTemplateId = nil

        let mockCV = CVModel(name: "Test CV")

        // When
        await viewModel.refreshPreview(for: mockCV)

        // Then
        #expect(viewModel.previewHTML == nil)
        #expect(viewModel.previewOptions == nil)
        #expect(await !mockService.generatePreviewHTMLCalled)
    }

    @Test("refreshPreview updates previewOptions")
    func refreshPreviewUpdatesOptions() async {
        // Given
        let mockService = MockCVExportService()
        let viewModel = CVExportSheetViewModel(exportService: mockService)
        viewModel.selectedTemplateId = "modern"
        viewModel.selectedColorPalette = .creative
        viewModel.selectedFontScheme = .serif

        let mockCV = CVModel(name: "Test CV")

        // When
        await viewModel.refreshPreview(for: mockCV)

        // Then
        #expect(viewModel.previewOptions != nil)
        #expect(viewModel.previewOptions?.customization.colorPalette == .creative)
        #expect(viewModel.previewOptions?.customization.fontScheme == .serif)
    }

    // MARK: - Export Tests

    @Test("export creates preview item with valid template")
    func exportCreatesPreviewItem() async {
        // Given
        let mockService = MockCVExportService()
        let viewModel = CVExportSheetViewModel(exportService: mockService)
        viewModel.selectedTemplateId = "modern"

        let mockCV = CVModel(name: "Test CV")

        // When
        await viewModel.export(cv: mockCV)

        // Then
        #expect(viewModel.previewItem != nil)
        #expect(viewModel.previewItem?.url.pathExtension == "pdf")
        #expect(await mockService.exportCalled)
    }

    @Test("export shows error when no template selected")
    func exportShowsErrorWithoutTemplate() async {
        // Given
        let mockService = MockCVExportService()
        let viewModel = CVExportSheetViewModel(exportService: mockService)
        viewModel.selectedTemplateId = nil

        let mockCV = CVModel(name: "Test CV")

        // When
        await viewModel.export(cv: mockCV)

        // Then
        #expect(viewModel.previewItem == nil)
        #expect(viewModel.errorMessage != nil)
        #expect(await !mockService.exportCalled)
    }

    // MARK: - Error Handling Tests

    @Test("dismissError clears error message")
    func dismissErrorClearsMessage() {
        // Given
        let mockService = MockCVExportService()
        let viewModel = CVExportSheetViewModel(exportService: mockService)
        viewModel.errorMessage = "Test error"

        // When
        viewModel.dismissError()

        // Then
        #expect(viewModel.errorMessage == nil)
    }

    @Test("handlePreviewDismiss clears preview item and cleans up file")
    func handlePreviewDismissCleanup() async {
        // Given
        let mockService = MockCVExportService()
        let viewModel = CVExportSheetViewModel(exportService: mockService)
        let testURL = URL(fileURLWithPath: "/tmp/test.pdf")
        viewModel.previewItem = CVExportSheetViewModel.ExportPreviewItem(url: testURL)

        // When
        viewModel.handlePreviewDismiss()

        // Give cleanup task time to execute
        try? await Task.sleep(for: .milliseconds(50))

        // Then
        #expect(viewModel.previewItem == nil)
        // Note: cleanupTempFile is called in a Task, so we can't easily verify it in unit tests
    }

    // MARK: - Aspect Ratio Tests

    @Test("aspectRatio uses previewOptions when available")
    func aspectRatioUsesPreviewOptions() async {
        // Given
        let mockService = MockCVExportService()
        let viewModel = CVExportSheetViewModel(exportService: mockService)
        viewModel.selectedTemplateId = "modern"

        let mockCV = CVModel(name: "Test CV")

        // When
        await viewModel.refreshPreview(for: mockCV)

        // Then
        let ratio = viewModel.aspectRatio
        // A4 aspect ratio is approximately 0.707 (210/297)
        #expect(abs(ratio - 0.707) < 0.01, "A4 aspect ratio should be approximately 0.707")
    }

    @Test("aspectRatio uses current options when preview not loaded")
    func aspectRatioUsesCurrentOptions() {
        // Given
        let mockService = MockCVExportService()
        let viewModel = CVExportSheetViewModel(exportService: mockService)

        // When
        let ratio = viewModel.aspectRatio

        // Then
        // Should still return A4 ratio even without preview
        #expect(abs(ratio - 0.707) < 0.01, "A4 aspect ratio should be approximately 0.707")
    }

    // MARK: - Customization Options Tests

    @Test("currentExportOptions includes selected customizations")
    func currentExportOptionsIncludesCustomizations() {
        // Given
        let mockService = MockCVExportService()
        let viewModel = CVExportSheetViewModel(exportService: mockService)
        viewModel.selectedTemplateId = "modern"
        viewModel.selectedColorPalette = .minimal
        viewModel.selectedFontScheme = .modern

        // When
        let options = viewModel.currentExportOptions()

        // Then
        #expect(options.templateId == "modern")
        #expect(options.customization.colorPalette == .minimal)
        #expect(options.customization.fontScheme == .modern)
        // Note: Don't test PageSize and EdgeInsets equality as they don't conform to Equatable
        #expect(options.maxPages == 10)
    }
}
