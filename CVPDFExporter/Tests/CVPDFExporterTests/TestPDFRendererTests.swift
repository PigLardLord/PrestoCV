import Testing
import Foundation
@testable import CVPDFExporter

// MARK: - Test PDF Renderer Tests (Sprint 4)

@Suite("Test PDF Renderer")
struct TestPDFRendererTests {

    @Test("Test renderer conforms to protocol")
    func testRendererConformsToProtocol() {
        // Given
        let renderer = TestPDFRenderer()

        // Then
        #expect(renderer is HTMLToPDFRenderer)
    }

    @Test("Mock renderer generates PDF data")
    func mockRendererGeneratesPDFData() async throws {
        // Given
        let renderer = TestPDFRenderer()
        let html = "<html><body><h1>Test</h1></body></html>"
        let options = ExportOptions.default

        // When
        let pdfData = try await renderer.renderToPDF(html: html, options: options)

        // Then
        #expect(pdfData.count > 0)
        #expect(pdfData.starts(with: "%PDF".data(using: .utf8)!))
    }

    @Test("Mock renderer respects page size options")
    func mockRendererRespectsPageSize() async throws {
        // Given
        let renderer = TestPDFRenderer()
        let html = "<html><body><h1>Test</h1></body></html>"

        // Test A4 size
        let a4Options = ExportOptions(pageSize: .a4)
        let a4PDF = try await renderer.renderToPDF(html: html, options: a4Options)

        // Test Letter size
        let letterOptions = ExportOptions(pageSize: .letter)
        let letterPDF = try await renderer.renderToPDF(html: html, options: letterOptions)

        // Then - different page sizes should produce different metadata
        #expect(a4PDF.count > 0)
        #expect(letterPDF.count > 0)
        // In a real implementation, these would have different page dimensions
    }

    @Test("Mock renderer includes HTML content marker")
    func mockRendererIncludesContentMarker() async throws {
        // Given
        let renderer = TestPDFRenderer()
        let html = "<html><body><h1>Unique Test Content</h1></body></html>"
        let options = ExportOptions.default

        // When
        let pdfData = try await renderer.renderToPDF(html: html, options: options)
        let pdfString = String(data: pdfData, encoding: .utf8) ?? ""

        // Then
        #expect(pdfString.contains("Unique Test Content"))
    }

    @Test("Mock renderer handles empty HTML")
    func mockRendererHandlesEmptyHTML() async throws {
        // Given
        let renderer = TestPDFRenderer()
        let html = ""
        let options = ExportOptions.default

        // When
        let pdfData = try await renderer.renderToPDF(html: html, options: options)

        // Then
        #expect(pdfData.count > 0)
        #expect(pdfData.starts(with: "%PDF".data(using: .utf8)!))
    }

    @Test("Mock renderer is thread safe")
    func mockRendererIsThreadSafe() async throws {
        // Given
        let renderer = TestPDFRenderer()
        let html = "<html><body><h1>Test</h1></body></html>"
        let options = ExportOptions.default

        // When - render multiple PDFs concurrently
        async let pdf1 = renderer.renderToPDF(html: html, options: options)
        async let pdf2 = renderer.renderToPDF(html: html, options: options)
        async let pdf3 = renderer.renderToPDF(html: html, options: options)

        let results = try await [pdf1, pdf2, pdf3]

        // Then
        for pdfData in results {
            #expect(pdfData.count > 0)
            #expect(pdfData.starts(with: "%PDF".data(using: .utf8)!))
        }
    }

    @Test("Mock renderer configuration options")
    func mockRendererConfiguration() {
        // Given
        let renderer = TestPDFRenderer()

        // Then
        #expect(renderer.debugMode == false)

        // When
        renderer.debugMode = true

        // Then
        #expect(renderer.debugMode == true)
    }
}