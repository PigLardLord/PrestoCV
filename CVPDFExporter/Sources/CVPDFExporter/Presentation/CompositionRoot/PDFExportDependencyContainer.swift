import Foundation

/// Dependency container for PDF export module
/// Follows Dependency Injection pattern and Single Responsibility Principle
public final class PDFExportDependencyContainer: @unchecked Sendable {

    // MARK: - Singleton Instances (Shared)

    private let templateRepository: BundledTemplateRepository
    private let templateCache: TemplateCache
    private let exportRepository: NullExportRepository

    // MARK: - Initialization

    /// - Parameter templateRepository: Where the templates come from; the installed bundled templates by default
    public init(templateRepository: BundledTemplateRepository = BundledTemplateRepository()) {
        self.templateRepository = templateRepository
        self.templateCache = TemplateCache()
        self.exportRepository = NullExportRepository()
    }

    // MARK: - Factory Methods (Public API)

    /// Creates PDF export use case
    /// The renderer is built on the main actor, where WebKit and UIKit live.
    @MainActor
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

    /// Creates platform-appropriate PDF renderer
    @MainActor
    public func makePDFRenderer() -> PDFRendererProtocol {
        PDFRendererFactory.createRenderer()
    }

    /// Creates AI service
    public func makeAIService() -> CVTailoringServiceProtocol {
        LocalAIService()
    }

    // MARK: - Private Factory Methods

    @MainActor
    private func makePDFExportEngine() -> PDFExportEngine {
        // Create adapter to bridge PDFRendererProtocol to HTMLToPDFRenderer
        let pdfRenderer = PDFRendererFactory.createRenderer()
        let htmlRenderer = PDFRendererAdapter(renderer: pdfRenderer)
        return PDFExportEngineImpl(renderer: htmlRenderer)
    }
}

// MARK: - Container Protocol (for testability)

public protocol DependencyContainerProtocol {
    @MainActor
    func makeExportUseCase() -> PDFExportUseCase
    func makeTemplateSelectionUseCase() -> TemplateSelectionUseCase
    func makeTemplatePreviewUseCase() -> TemplatePreviewUseCase
    func makeCVTailoringUseCase() -> CVTailoringUseCase
    func makeExportManager() -> ExportManager
}

extension PDFExportDependencyContainer: DependencyContainerProtocol {}

// MARK: - PDF Renderer Adapter

/// Adapter to bridge PDFRendererProtocol to HTMLToPDFRenderer
final class PDFRendererAdapter: HTMLToPDFRenderer, @unchecked Sendable {
    private let renderer: PDFRendererProtocol

    init(renderer: PDFRendererProtocol) {
        self.renderer = renderer
    }

    func renderToPDF(html: String, options: ExportOptions) async throws -> Data {
        try await renderer.renderToPDF(html: html, options: options)
    }
}

// MARK: - Null Export Repository

/// An export repository that keeps nothing: the app neither lists past exports nor reuses cached PDFs,
/// so there is nothing to remember, and no state that grows with every export.
final class NullExportRepository: ExportRepositoryProtocol {
    func saveExportHistory(_ entry: ExportHistoryEntry) async throws {}

    func getExportHistory(limit: Int) async throws -> [ExportHistoryEntry] { [] }

    func cachePDF(data: Data, key: String, ttl: TimeInterval) async throws {}

    func getCachedPDF(key: String) async -> Data? { nil }

    func clearExpiredCache() async throws {}

    func clearAll() async throws {}
}
