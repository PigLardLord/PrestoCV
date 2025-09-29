import Foundation
@testable import CVPDFExporter

/// Test dependency container that uses mock renderers
public final class MockDependencyContainer {

    // MARK: - Singleton Instances (Shared)

    private let templateRepository: BundledTemplateRepository
    private let templateCache: TemplateCache
    private let exportRepository: MockExportRepository

    // MARK: - Initialization

    public init() {
        self.templateRepository = BundledTemplateRepository()
        self.templateCache = TemplateCache()
        self.exportRepository = MockExportRepository()
    }

    // MARK: - Factory Methods (Public API)

    /// Creates PDF export use case with mock renderer
    public func makeExportUseCase() -> PDFExportUseCase {
        PDFExportUseCase(
            renderer: makePDFRenderer(),
            repository: exportRepository,
            templateEngine: makeTemplateEngine()
        )
    }

    /// Creates template selection use case
    public func makeTemplateSelectionUseCase() -> TemplateSelectionUseCase {
        TemplateSelectionUseCase(repository: makeTemplateRepository())
    }

    /// Creates template preview use case
    public func makeTemplatePreviewUseCase() -> TemplatePreviewUseCase {
        TemplatePreviewUseCase(
            templateEngine: makeTemplateEngine(),
            repository: makeTemplateRepository()
        )
    }

    /// Creates CV tailoring use case
    public func makeCVTailoringUseCase() -> CVTailoringUseCase {
        CVTailoringUseCase(aiService: makeAIService())
    }

    /// Creates export manager (main entry point)
    public func makeExportManager() -> ExportManager {
        ExportManager()
    }

    // MARK: - Infrastructure Factory Methods

    /// Returns shared template repository instance
    public func makeTemplateRepository() -> BundledTemplateRepository {
        templateRepository
    }

    /// Creates new template engine instance
    public func makeTemplateEngine() -> TemplateEngine {
        MustacheTemplateEngine()
    }

    /// Creates mock PDF renderer for testing
    public func makePDFRenderer() -> PDFRendererProtocol {
        TestMockPDFRenderer()
    }

    /// Creates AI service
    public func makeAIService() -> CVTailoringServiceProtocol {
        LocalAIService()
    }

    // MARK: - Private Factory Methods

    private func makePDFExportEngine() -> PDFExportEngine {
        PDFExportEngineImpl(renderer: PDFRendererAdapter(renderer: makePDFRenderer()))
    }
}

extension MockDependencyContainer: DependencyContainerProtocol {}

/// Test mock PDF renderer that doesn't actually render
final class TestMockPDFRenderer: PDFRendererProtocol, @unchecked Sendable {

    var renderCallCount = 0
    var lastHtmlRendered: String?
    var shouldFail = false
    var mockData = Data("Mock PDF Content".utf8)

    func renderToPDF(html: String, options: ExportOptions) async throws -> Data {
        renderCallCount += 1
        lastHtmlRendered = html

        if shouldFail {
            throw PDFExportError.renderingFailed("Mock render failure")
        }

        // Simulate some processing time
        try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds

        return mockData
    }

    var isAvailable: Bool { true }
    var maxPages: Int { 100 }
}

/// PDF Renderer Adapter (copied from main source)
final class PDFRendererAdapter: HTMLToPDFRenderer, @unchecked Sendable {
    private let renderer: PDFRendererProtocol

    init(renderer: PDFRendererProtocol) {
        self.renderer = renderer
    }

    func renderToPDF(html: String, options: ExportOptions) async throws -> Data {
        try await renderer.renderToPDF(html: html, options: options)
    }
}