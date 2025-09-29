import XCTest
@testable import CVPDFExporter

final class PDFExportDependencyContainerTests: XCTestCase {

    var sut: PDFExportDependencyContainer!

    override func setUp() {
        super.setUp()
        sut = PDFExportDependencyContainer()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Tests

    func test_init_createsContainer() {
        // Then
        XCTAssertNotNil(sut)
    }

    func test_makeExportUseCase_returnsConfiguredUseCase() {
        // When
        let useCase = sut.makeExportUseCase()

        // Then
        XCTAssertNotNil(useCase)
    }

    func test_makeTemplateSelectionUseCase_returnsConfiguredUseCase() {
        // When
        let useCase = sut.makeTemplateSelectionUseCase()

        // Then
        XCTAssertNotNil(useCase)
    }

    func test_makeTemplatePreviewUseCase_returnsConfiguredUseCase() {
        // When
        let useCase = sut.makeTemplatePreviewUseCase()

        // Then
        XCTAssertNotNil(useCase)
    }

    func test_makeCVTailoringUseCase_returnsConfiguredUseCase() {
        // When
        let useCase = sut.makeCVTailoringUseCase()

        // Then
        XCTAssertNotNil(useCase)
    }

    func test_makeTemplateRepository_returnsSameInstance() {
        // When
        let repo1 = sut.makeTemplateRepository()
        let repo2 = sut.makeTemplateRepository()

        // Then
        XCTAssertTrue(repo1 === repo2) // Should be same instance (Singleton)
    }

    func test_makeTemplateEngine_returnsNewInstance() {
        // When
        let engine1 = sut.makeTemplateEngine()
        let engine2 = sut.makeTemplateEngine()

        // Then
        // Each call should return a new instance
        XCTAssertNotNil(engine1)
        XCTAssertNotNil(engine2)
    }

    func test_makePDFRenderer_returnsAppropriateRenderer() {
        // When
        let renderer = sut.makePDFRenderer()

        // Then
        XCTAssertNotNil(renderer)
        #if canImport(UIKit)
        XCTAssertTrue(renderer is EnhancedWKWebViewPDFRenderer || renderer is WKWebViewPDFRenderer)
        #elseif canImport(AppKit)
        XCTAssertTrue(renderer is ProperMacOSPDFRenderer || renderer is MacOSPDFRenderer)
        #else
        XCTAssertTrue(renderer is TestPDFRenderer)
        #endif
    }

    func test_makeAIService_returnsLocalAIService() {
        // When
        let service = sut.makeAIService()

        // Then
        XCTAssertNotNil(service)
        XCTAssertTrue(service.isAvailable)
    }

    func test_makeExportManager_returnsConfiguredExportManager() {
        // When
        let manager = sut.makeExportManager()

        // Then
        XCTAssertNotNil(manager)
    }
}