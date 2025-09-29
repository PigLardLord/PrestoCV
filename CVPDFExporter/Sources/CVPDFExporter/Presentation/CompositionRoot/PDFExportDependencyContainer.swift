import Foundation

/// Dependency container for PDF export module
/// Follows Dependency Injection pattern and Single Responsibility Principle
public final class PDFExportDependencyContainer: @unchecked Sendable {

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

    /// Creates PDF export use case
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
    public func makePDFRenderer() -> PDFRendererProtocol {
        PDFRendererFactory.createRenderer()
    }

    /// Creates AI service
    public func makeAIService() -> CVTailoringServiceProtocol {
        LocalAIService()
    }

    // MARK: - Private Factory Methods

    private func makePDFExportEngine() -> PDFExportEngine {
        // Create adapter to bridge PDFRendererProtocol to HTMLToPDFRenderer
        let pdfRenderer = PDFRendererFactory.createRenderer()
        let htmlRenderer = PDFRendererAdapter(renderer: pdfRenderer)
        return PDFExportEngineImpl(renderer: htmlRenderer)
    }
}

// MARK: - Container Protocol (for testability)

public protocol DependencyContainerProtocol {
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

// MARK: - Mock Export Repository

final class MockExportRepository: ExportRepositoryProtocol, @unchecked Sendable {
    private var history: [ExportHistoryEntry] = []
    private var cache: [String: (data: Data, expiry: Date)] = [:]

    func saveExportHistory(_ entry: ExportHistoryEntry) async throws {
        history.insert(entry, at: 0)
    }

    func getExportHistory(limit: Int) async throws -> [ExportHistoryEntry] {
        Array(history.prefix(limit))
    }

    func cachePDF(data: Data, key: String, ttl: TimeInterval) async throws {
        let expiry = Date().addingTimeInterval(ttl)
        cache[key] = (data, expiry)
    }

    func getCachedPDF(key: String) async -> Data? {
        guard let entry = cache[key] else { return nil }
        if entry.expiry > Date() {
            return entry.data
        }
        cache.removeValue(forKey: key)
        return nil
    }

    func clearExpiredCache() async throws {
        let now = Date()
        cache = cache.filter { $0.value.expiry > now }
    }

    func clearAll() async throws {
        history.removeAll()
        cache.removeAll()
    }
}