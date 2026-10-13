import Testing
import Foundation
import PDFKit
@testable import CVPDFExporter

@Suite("PDFExportUseCase")
struct PDFExportUseCaseTests {

    @Test("Should export CV to PDF successfully")
    func test_execute_withValidDocument_shouldReturnPDFData() async throws {
        // Given
        let mockRenderer = TestPDFRenderer()
        let mockRepository = TestExportRepository()
        let mockTemplateEngine = UseCaseMockTemplateEngine()

        let useCase = PDFExportUseCase(
            renderer: mockRenderer,
            repository: mockRepository,
            templateEngine: mockTemplateEngine
        )

        let document = createSampleDocument()
        let template = Template(
            id: "test",
            name: "Test Template",
            description: "Test",
            htmlContent: "<html>{{name}}</html>",
            supportedVariables: ["name"]
        )
        let options = ExportOptions()

        // When
        let result = try await useCase.execute(
            document: document,
            template: template,
            options: options
        )

        // Then
        #expect(result.pdfData.count > 0)
        #expect(result.pageCount == 1)
        #expect(await mockRenderer.renderCallCount == 1)
        #expect(await mockRepository.saveHistoryCallCount == 1)
    }

    @Test("Should handle invalid document")
    func test_execute_withEmptyDocument_shouldThrowError() async {
        // Given
        let mockRenderer = TestPDFRenderer()
        let mockRepository = TestExportRepository()
        let mockTemplateEngine = UseCaseMockTemplateEngine()

        let useCase = PDFExportUseCase(
            renderer: mockRenderer,
            repository: mockRepository,
            templateEngine: mockTemplateEngine
        )

        let emptyDocument = CVDocument(
            personalInfo: PersonalInfo(name: "", email: ""),
            sections: [],
            metadata: DocumentMetadata()
        )
        let template = Template(
            id: "test",
            name: "Test",
            description: "Test",
            htmlContent: "<html></html>",
            supportedVariables: []
        )
        let options = ExportOptions()

        // When/Then
        await #expect(throws: PDFExportError.self) {
            _ = try await useCase.execute(
                document: emptyDocument,
                template: template,
                options: options
            )
        }
    }

    @Test("Should report the real page count of the PDF")
    func test_execute_shouldReportPageCountOfDocument() async throws {
        // Given
        let useCase = makeUseCase(renderer: TestPDFRenderer(simulatedPageCount: 6))

        // When
        let result = try await useCase.execute(
            document: createSampleDocument(),
            template: Self.sampleTemplate,
            options: ExportOptions(maxPages: 10)
        )

        // Then: the document has six pages, whatever its size
        #expect(result.pageCount == 6)
        #expect(PDFDocument(data: result.pdfData)?.pageCount == 6)
    }

    @Test("Should export a PDF that has exactly the allowed number of pages")
    func test_execute_withPageCountAtTheLimit_shouldSucceed() async throws {
        // Given
        let useCase = makeUseCase(renderer: TestPDFRenderer(simulatedPageCount: 4))

        // When
        let result = try await useCase.execute(
            document: createSampleDocument(),
            template: Self.sampleTemplate,
            options: ExportOptions(maxPages: 4)
        )

        // Then
        #expect(result.pageCount == 4)
    }

    @Test("Should refuse a PDF with more pages than allowed instead of cutting it")
    func test_execute_withTooManyPages_shouldThrowTooManyPages() async throws {
        // Given
        let mockRepository = TestExportRepository()
        let useCase = makeUseCase(renderer: TestPDFRenderer(simulatedPageCount: 10), repository: mockRepository)

        // When/Then
        do {
            _ = try await useCase.execute(
                document: createSampleDocument(),
                template: Self.sampleTemplate,
                options: ExportOptions(maxPages: 4)
            )
            Issue.record("Expected tooManyPages")
        } catch PDFExportError.tooManyPages(let count, let limit) {
            #expect(count == 10)
            #expect(limit == 4)
        }
        #expect(await mockRepository.saveHistoryCallCount == 0)
    }

    @Test("Should refuse renderer output that is not a readable PDF")
    func test_execute_withUnreadablePDF_shouldThrowRenderingFailed() async throws {
        // Given
        let useCase = makeUseCase(renderer: TestPDFRenderer(output: Data(repeating: 0xFF, count: 4096)))

        // When/Then
        await #expect(throws: PDFExportError.self) {
            _ = try await useCase.execute(
                document: createSampleDocument(),
                template: Self.sampleTemplate,
                options: ExportOptions()
            )
        }
    }

    @Test("Should report the page count of a cached PDF")
    func test_execute_withCachedPDF_shouldReportItsPageCount() async throws {
        // Given
        let mockRepository = TestExportRepository(cachedPDF: TestPDFDocument.data(pageCount: 3))
        let mockRenderer = TestPDFRenderer()
        let useCase = makeUseCase(renderer: mockRenderer, repository: mockRepository, enableCaching: true)

        // When
        let result = try await useCase.execute(
            document: createSampleDocument(),
            template: Self.sampleTemplate,
            options: ExportOptions(maxPages: 10)
        )

        // Then
        #expect(result.pageCount == 3)
        #expect(await mockRenderer.renderCallCount == 0)
    }

    @Test("Should not return a cached PDF that is longer than the allowed page count")
    func test_execute_withCachedPDFOverTheLimit_shouldThrowTooManyPages() async throws {
        // Given
        let mockRepository = TestExportRepository(cachedPDF: TestPDFDocument.data(pageCount: 6))
        let useCase = makeUseCase(renderer: TestPDFRenderer(), repository: mockRepository, enableCaching: true)

        // When/Then
        await #expect(throws: PDFExportError.self) {
            _ = try await useCase.execute(
                document: createSampleDocument(),
                template: Self.sampleTemplate,
                options: ExportOptions(maxPages: 4)
            )
        }
    }

    @Test("Should cache PDF when enabled")
    func test_execute_withCacheEnabled_shouldCachePDF() async throws {
        // Given
        let mockRenderer = TestPDFRenderer()
        let mockRepository = TestExportRepository()
        let mockTemplateEngine = UseCaseMockTemplateEngine()

        let useCase = PDFExportUseCase(
            renderer: mockRenderer,
            repository: mockRepository,
            templateEngine: mockTemplateEngine,
            enableCaching: true
        )

        let document = createSampleDocument()
        let template = Template(
            id: "test",
            name: "Test",
            description: "Test",
            htmlContent: "<html>{{name}}</html>",
            supportedVariables: ["name"]
        )
        let options = ExportOptions()

        // When
        _ = try await useCase.execute(
            document: document,
            template: template,
            options: options
        )

        // Then
        #expect(await mockRepository.cachePDFCallCount == 1)
    }

    // MARK: - Helpers

    private static let sampleTemplate = Template(
        id: "test",
        name: "Test Template",
        description: "Test",
        htmlContent: "<html>{{name}}</html>",
        supportedVariables: ["name"]
    )

    private func makeUseCase(
        renderer: TestPDFRenderer,
        repository: TestExportRepository = TestExportRepository(),
        enableCaching: Bool = false
    ) -> PDFExportUseCase {
        PDFExportUseCase(
            renderer: renderer,
            repository: repository,
            templateEngine: UseCaseMockTemplateEngine(),
            enableCaching: enableCaching
        )
    }

    private func createSampleDocument() -> CVDocument {
        CVDocument(
            personalInfo: PersonalInfo(
                name: "John Doe",
                email: "john@example.com",
                phone: "+1 234 567 8900"
            ),
            sections: [
                CVSection(
                    id: "work",
                    type: .work,
                    title: "Experience",
                    items: [
                        CVItem(
                            title: "Senior Developer",
                            subtitle: "Tech Corp",
                            description: "Led development team"
                        )
                    ]
                )
            ],
            metadata: DocumentMetadata()
        )
    }
}

// MARK: - Mocks

private actor TestPDFRenderer: PDFRendererProtocol {
    private var _renderCallCount = 0
    private let output: Data

    var renderCallCount: Int {
        _renderCallCount
    }

    /// Renders a valid PDF with `simulatedPageCount` pages
    init(simulatedPageCount: Int = 1) {
        self.output = TestPDFDocument.data(pageCount: simulatedPageCount)
    }

    /// Renders exactly `output`, valid PDF or not
    init(output: Data) {
        self.output = output
    }

    nonisolated func renderToPDF(html: String, options: ExportOptions) async throws -> Data {
        await incrementCallCount()
        return output
    }

    private func incrementCallCount() {
        _renderCallCount += 1
    }

    nonisolated var isAvailable: Bool { true }
    nonisolated var maxPages: Int { 100 }
}

private actor TestExportRepository: ExportRepositoryProtocol {
    private var _saveHistoryCallCount = 0
    private var _cachePDFCallCount = 0
    private let cachedPDF: Data?

    init(cachedPDF: Data? = nil) {
        self.cachedPDF = cachedPDF
    }

    var saveHistoryCallCount: Int {
        _saveHistoryCallCount
    }

    var cachePDFCallCount: Int {
        _cachePDFCallCount
    }

    nonisolated func saveExportHistory(_ entry: ExportHistoryEntry) async throws {
        await incrementSaveHistory()
    }

    private func incrementSaveHistory() {
        _saveHistoryCallCount += 1
    }

    nonisolated func getExportHistory(limit: Int) async throws -> [ExportHistoryEntry] {
        []
    }

    nonisolated func cachePDF(data: Data, key: String, ttl: TimeInterval) async throws {
        await incrementCachePDF()
    }

    private func incrementCachePDF() {
        _cachePDFCallCount += 1
    }

    nonisolated func getCachedPDF(key: String) async -> Data? {
        cachedPDF
    }

    nonisolated func clearExpiredCache() async throws {}
    nonisolated func clearAll() async throws {}
}

private actor UseCaseMockTemplateEngine: TemplateEngine {
    func render(template: Template, data: CVDocument, customization: CustomizationOptions) async throws -> String {
        "<html><body>\(data.personalInfo.name)</body></html>"
    }
}