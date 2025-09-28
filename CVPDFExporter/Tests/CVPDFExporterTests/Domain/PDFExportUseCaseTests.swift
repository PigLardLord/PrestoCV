import Testing
import Foundation
@testable import CVPDFExporter

@Suite("PDFExportUseCase")
struct PDFExportUseCaseTests {

    @Test("Should export CV to PDF successfully")
    func test_execute_withValidDocument_shouldReturnPDFData() async throws {
        // Given
        let mockRenderer = TestPDFRenderer()
        let mockRepository = TestExportRepository()
        let mockTemplateEngine = MockTemplateEngine()

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
        let mockTemplateEngine = MockTemplateEngine()

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

    @Test("Should respect page limits")
    func test_execute_withTooManyPages_shouldEnforceLimit() async throws {
        // Given
        let mockRenderer = TestPDFRenderer(simulatedPageCount: 10)
        let mockRepository = TestExportRepository()
        let mockTemplateEngine = MockTemplateEngine()

        let useCase = PDFExportUseCase(
            renderer: mockRenderer,
            repository: mockRepository,
            templateEngine: mockTemplateEngine
        )

        let document = createSampleDocument()
        let template = Template(
            id: "test",
            name: "Test",
            description: "Test",
            htmlContent: "<html>{{name}}</html>",
            supportedVariables: ["name"]
        )
        let options = ExportOptions(maxPages: 4)

        // When
        let result = try await useCase.execute(
            document: document,
            template: template,
            options: options
        )

        // Then
        #expect(result.pageCount <= 4)
        #expect(result.wasContentTruncated == true)
    }

    @Test("Should cache PDF when enabled")
    func test_execute_withCacheEnabled_shouldCachePDF() async throws {
        // Given
        let mockRenderer = TestPDFRenderer()
        let mockRepository = TestExportRepository()
        let mockTemplateEngine = MockTemplateEngine()

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
    private let simulatedPageCount: Int

    var renderCallCount: Int {
        _renderCallCount
    }

    init(simulatedPageCount: Int = 1) {
        self.simulatedPageCount = simulatedPageCount
    }

    nonisolated func renderToPDF(html: String, options: ExportOptions) async throws -> Data {
        await incrementCallCount()
        return Data(repeating: 0xFF, count: simulatedPageCount * 1024) // Mock PDF data
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
        nil
    }

    nonisolated func clearExpiredCache() async throws {}
    nonisolated func clearAll() async throws {}
}

private actor MockTemplateEngine: TemplateEngine {
    func render(template: Template, data: CVDocument, customization: CustomizationOptions) async throws -> String {
        "<html><body>\(data.personalInfo.name)</body></html>"
    }
}