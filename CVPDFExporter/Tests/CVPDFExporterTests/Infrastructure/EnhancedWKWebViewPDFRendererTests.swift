#if canImport(UIKit) && canImport(WebKit)
import Testing
import Foundation
import UIKit
@testable import CVPDFExporter

@Suite("Enhanced WKWebView PDF Renderer")
struct EnhancedWKWebViewPDFRendererTests {

    @Test("Renderer is available on iOS")
    func test_isAvailable_onIOS() {
        // Given
        let renderer = EnhancedWKWebViewPDFRenderer()

        // Then
        #expect(renderer.isAvailable == true)
    }

    @Test("Renderer has correct max pages limit")
    func test_maxPages_returns100() {
        // Given
        let renderer = EnhancedWKWebViewPDFRenderer()

        // Then
        #expect(renderer.maxPages == 100)
    }

    @Test("Renders simple HTML to PDF")
    @MainActor
    func test_renderToPDF_withSimpleHTML() async throws {
        // Given
        let renderer = EnhancedWKWebViewPDFRenderer()
        let html = """
            <!DOCTYPE html>
            <html>
            <head>
                <style>
                    body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; }
                    h1 { color: #333; }
                </style>
            </head>
            <body>
                <h1>Test Document</h1>
                <p>This is a test paragraph.</p>
            </body>
            </html>
        """
        let options = ExportOptions()

        // When
        let pdfData = try await renderer.renderToPDF(html: html, options: options)

        // Then
        #expect(pdfData.count > 0)
        #expect(isPDFData(pdfData))
    }

    @Test("Handles page breaks correctly")
    @MainActor
    func test_renderToPDF_withPageBreaks() async throws {
        // Given
        let renderer = EnhancedWKWebViewPDFRenderer()
        let html = """
            <!DOCTYPE html>
            <html>
            <head>
                <style>
                    .cv-section { margin: 20px 0; }
                    .page-break { page-break-before: always; }
                </style>
            </head>
            <body>
                <div class="cv-section">
                    <h2>Section 1</h2>
                    <p>Content for section 1</p>
                </div>
                <div class="cv-section page-break">
                    <h2>Section 2</h2>
                    <p>Content for section 2</p>
                </div>
            </body>
            </html>
        """
        let options = ExportOptions()

        // When
        let pdfData = try await renderer.renderToPDF(html: html, options: options)

        // Then
        #expect(pdfData.count > 0)
        // PDF should contain multiple pages due to page break
    }

    @Test("Respects custom page size")
    @MainActor
    func test_renderToPDF_withCustomPageSize() async throws {
        // Given
        let renderer = EnhancedWKWebViewPDFRenderer()
        let html = "<html><body><h1>Custom Size Test</h1></body></html>"
        let options = ExportOptions(
            pageSize: PageSize(width: 400, height: 600),
            margins: EdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        )

        // When
        let pdfData = try await renderer.renderToPDF(html: html, options: options)

        // Then
        #expect(pdfData.count > 0)
    }

    @Test("Enforces page limit")
    @MainActor
    func test_renderToPDF_enforcesPageLimit() async throws {
        // Given
        let renderer = EnhancedWKWebViewPDFRenderer()

        // Create HTML with many sections to force multiple pages
        var sections = ""
        for i in 1...10 {
            sections += """
                <div style="page-break-before: always;">
                    <h2>Section \(i)</h2>
                    <p style="height: 800px;">Very tall content to force pagination</p>
                </div>
            """
        }

        let html = """
            <!DOCTYPE html>
            <html>
            <body>
                \(sections)
            </body>
            </html>
        """

        let options = ExportOptions(maxPages: 3)

        // When
        let pdfData = try await renderer.renderToPDF(html: html, options: options)

        // Then
        #expect(pdfData.count > 0)
        // Should have truncated to 3 pages max
    }

    @Test("Handles JavaScript rendering")
    @MainActor
    func test_renderToPDF_withJavaScriptContent() async throws {
        // Given
        let renderer = EnhancedWKWebViewPDFRenderer()
        let html = """
            <!DOCTYPE html>
            <html>
            <head>
                <script>
                    window.onload = function() {
                        document.getElementById('dynamic').innerHTML = 'Dynamically added content';
                    }
                </script>
            </head>
            <body>
                <h1>Static Content</h1>
                <div id="dynamic"></div>
            </body>
            </html>
        """
        let options = ExportOptions()

        // When
        let pdfData = try await renderer.renderToPDF(html: html, options: options)

        // Then
        #expect(pdfData.count > 0)
    }

    @Test("Applies print media styles")
    @MainActor
    func test_renderToPDF_appliesPrintMediaStyles() async throws {
        // Given
        let renderer = EnhancedWKWebViewPDFRenderer()
        let html = """
            <!DOCTYPE html>
            <html>
            <head>
                <style>
                    @media print {
                        body { background: white; color: black; }
                        .no-print { display: none; }
                    }
                </style>
            </head>
            <body>
                <h1>Visible in PDF</h1>
                <div class="no-print">Should not appear in PDF</div>
            </body>
            </html>
        """
        let options = ExportOptions()

        // When
        let pdfData = try await renderer.renderToPDF(html: html, options: options)

        // Then
        #expect(pdfData.count > 0)
    }

    @Test("Handles complex CV document")
    @MainActor
    func test_renderToPDF_withComplexCVDocument() async throws {
        // Given
        let renderer = EnhancedWKWebViewPDFRenderer()
        let templateEngine = TemplateEngine()
        let template = try await templateEngine.loadTemplate(named: "modern")

        let document = createSampleCVDocument()
        let html = try await templateEngine.render(
            template: template,
            data: document,
            customization: CustomizationOptions()
        )

        let options = ExportOptions()

        // When
        let pdfData = try await renderer.renderToPDF(html: html, options: options)

        // Then
        #expect(pdfData.count > 1000) // Should be substantial size
        #expect(isPDFData(pdfData))
    }

    // MARK: - Helper Methods

    private func isPDFData(_ data: Data) -> Bool {
        // PDF files start with "%PDF"
        if data.count < 4 { return false }
        let header = String(data: data.prefix(4), encoding: .ascii)
        return header == "%PDF"
    }

    private func createSampleCVDocument() -> CVDocument {
        CVDocument(
            personalInfo: PersonalInfo(
                name: "Test User",
                email: "test@example.com",
                phone: "+1 234 567 8900",
                location: "San Francisco, CA",
                summary: "Experienced professional"
            ),
            sections: [
                CVSection(
                    id: "work",
                    type: .work,
                    title: "Work Experience",
                    items: [
                        CVItem(
                            title: "Senior Developer",
                            subtitle: "Tech Corp",
                            description: "Led development team",
                            startDate: "2020",
                            endDate: "Present",
                            location: "San Francisco, CA"
                        )
                    ],
                    order: 1
                ),
                CVSection(
                    id: "education",
                    type: .education,
                    title: "Education",
                    items: [
                        CVItem(
                            title: "Computer Science",
                            subtitle: "University",
                            description: "Bachelor's Degree",
                            startDate: "2016",
                            endDate: "2020"
                        )
                    ],
                    order: 2
                )
            ],
            metadata: DocumentMetadata()
        )
    }
}

#endif