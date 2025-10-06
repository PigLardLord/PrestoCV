import XCTest
@testable import CVPDFExporter

final class TemplatePreviewUseCaseTests: XCTestCase {

    var sut: TemplatePreviewUseCase!
    var templateEngine: MockTemplateEngine!
    var repository: MockTemplateRepository!

    override func setUp() {
        super.setUp()
        templateEngine = MockTemplateEngine()
        repository = MockTemplateRepository()
        sut = TemplatePreviewUseCase(
            templateEngine: templateEngine,
            repository: repository
        )
    }

    override func tearDown() {
        sut = nil
        templateEngine = nil
        repository = nil
        super.tearDown()
    }

    // MARK: - Tests

    func test_generatePreview_withValidTemplate_returnsHTML() async throws {
        // Given
        let template = Template(
            id: "modern",
            name: "Modern",
            htmlContent: "<html>{{name}}</html>"
        )
        repository.templates = [template]
        templateEngine.renderedHTML = "<html>John Doe</html>"

        let cv = createSampleCV()
        let customization = CustomizationOptions()

        // When
        let preview = try await sut.generatePreview(
            templateId: "modern",
            cv: cv,
            customization: customization
        )

        // Then
        XCTAssertTrue(preview.html.contains("John Doe"))
        XCTAssertEqual(preview.rawHTML, "<html>John Doe</html>")
        XCTAssertEqual(preview.templateId, "modern")
        XCTAssertNotNil(preview.generatedAt)
    }

    func test_generatePreview_withInvalidTemplate_throwsError() async throws {
        // Given
        repository.templates = []
        let cv = createSampleCV()

        // When/Then
        do {
            _ = try await sut.generatePreview(
                templateId: "nonexistent",
                cv: cv,
                customization: CustomizationOptions()
            )
            XCTFail("Should have thrown error")
        } catch TemplatePreviewError.templateNotFound {
            // Expected
        }
    }

    func test_generatePreview_injectsReadinessScriptsIntoHead() async throws {
        // Given
        let baseHTML = """
        <html>
            <head><title>CV</title></head>
            <body><p>Hello</p></body>
        </html>
        """
        let template = Template(id: "preview", name: "Preview", htmlContent: baseHTML)
        repository.templates = [template]
        templateEngine.renderedHTML = baseHTML

        let cv = createSampleCV()

        // When
        let preview = try await sut.generatePreview(
            templateId: "preview",
            cv: cv,
            customization: CustomizationOptions()
        )

        // Then
        let headSection = preview.html.components(separatedBy: "</head>").first ?? ""
        let bodySection = preview.html.components(separatedBy: "</head>").dropFirst().joined(separator: "</head>")

        XCTAssertTrue(headSection.contains("<script type=\"text/javascript\">"), "Readiness script tag should be inside <head>.")
        XCTAssertFalse(bodySection.contains("(function() {"), "Readiness script should not render as body text.")
    }

    func test_generateThumbnail_createsBase64Image() async throws {
        // Given
        let preview = TemplatePreview(
            templateId: "modern",
            html: "<html><body>Test</body></html>",
            rawHTML: "<html><body>Test</body></html>",
            generatedAt: Date()
        )
        templateEngine.thumbnailData = Data([0xFF, 0xD8, 0xFF]) // JPEG header

        // When
        let thumbnail = try await sut.generateThumbnail(for: preview)

        // Then
        XCTAssertNotNil(thumbnail)
        XCTAssertTrue(thumbnail.hasPrefix("data:image/jpeg;base64,"))
    }

    func test_batchGeneratePreviews_generatesMultiplePreviews() async throws {
        // Given
        let templates = [
            Template(id: "1", name: "Template1", htmlContent: "<html>1</html>"),
            Template(id: "2", name: "Template2", htmlContent: "<html>2</html>"),
            Template(id: "3", name: "Template3", htmlContent: "<html>3</html>")
        ]
        repository.templates = templates
        templateEngine.shouldReturnDifferentHTML = true

        let cv = createSampleCV()

        // When
        let previews = try await sut.batchGeneratePreviews(
            templateIds: ["1", "2", "3"],
            cv: cv,
            customization: CustomizationOptions()
        )

        // Then
        XCTAssertEqual(previews.count, 3)
        XCTAssertEqual(previews.map { $0.templateId }.sorted(), ["1", "2", "3"])
    }

    func test_cachePreview_storesAndRetrievesPreview() async throws {
        // Given
        let preview = TemplatePreview(
            templateId: "modern",
            html: "<html>Cached</html>",
            rawHTML: "<html>Cached</html>",
            generatedAt: Date()
        )

        // When
        await sut.cachePreview(preview, for: "cache-key")
        let cached = await sut.getCachedPreview(for: "cache-key")

        // Then
        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?.html, preview.html)
        XCTAssertEqual(cached?.templateId, preview.templateId)
    }

    func test_clearCache_removesAllCachedPreviews() async throws {
        // Given
        let preview1 = TemplatePreview(templateId: "1", html: "HTML1", rawHTML: "HTML1", generatedAt: Date())
        let preview2 = TemplatePreview(templateId: "2", html: "HTML2", rawHTML: "HTML2", generatedAt: Date())

        await sut.cachePreview(preview1, for: "key1")
        await sut.cachePreview(preview2, for: "key2")

        // When
        await sut.clearCache()

        // Then
        let cached1 = await sut.getCachedPreview(for: "key1")
        let cached2 = await sut.getCachedPreview(for: "key2")
        XCTAssertNil(cached1)
        XCTAssertNil(cached2)
    }

    // MARK: - Helpers

    private func createSampleCV() -> CVDocument {
        CVDocument(
            personalInfo: PersonalInfo(
                name: "John Doe",
                email: "john@example.com"
            )
        )
    }
}

// MARK: - Mock Template Engine

class MockTemplateEngine: TemplateEngine, @unchecked Sendable {
    var renderedHTML = "<html>Default</html>"
    var thumbnailData: Data?
    var shouldReturnDifferentHTML = false
    private var renderCount = 0

    func render(template: Template, data: CVDocument, customization: CustomizationOptions) async throws -> String {
        if shouldReturnDifferentHTML {
            renderCount += 1
            return "<html>Rendered \(renderCount)</html>"
        }
        return renderedHTML
    }
}
