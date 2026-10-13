#if canImport(UIKit) && canImport(WebKit)
import Testing
import Foundation
import UIKit
import PDFKit
@testable import CVPDFExporter

@Suite("Enhanced WKWebView PDF Renderer")
struct EnhancedWKWebViewPDFRendererTests {

    @Test("Renderer is available on iOS")
    @MainActor
    func test_isAvailable_onIOS() {
        // Given
        let renderer = EnhancedWKWebViewPDFRenderer()

        // Then
        #expect(renderer.isAvailable == true)
    }

    @Test("Renderer has correct max pages limit")
    @MainActor
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
        let mediaBox = PDFDocument(data: pdfData)?.page(at: 0)?.bounds(for: .mediaBox)
        #expect(mediaBox?.width == 400)
        #expect(mediaBox?.height == 600)
    }

    @Test("Stores the title and author of the options in the PDF")
    @MainActor
    func test_renderToPDF_storesTitleAndAuthor() async throws {
        // Given
        let renderer = EnhancedWKWebViewPDFRenderer()
        let options = ExportOptions().withDocumentInfo(title: "Ada Lovelace – CV", author: "Ada Lovelace")

        // When
        let pdfData = try await renderer.renderToPDF(html: "<html><body><h1>Ada</h1></body></html>", options: options)

        // Then
        let attributes = PDFDocument(data: pdfData)?.documentAttributes
        #expect(attributes?[PDFDocumentAttribute.titleAttribute] as? String == "Ada Lovelace – CV")
        #expect(attributes?[PDFDocumentAttribute.authorAttribute] as? String == "Ada Lovelace")
        #expect(attributes?[PDFDocumentAttribute.creatorAttribute] as? String == "PrestoCV")
    }

    @Test("Leaves the title and author out when the options have none")
    @MainActor
    func test_renderToPDF_withoutDocumentInfo() async throws {
        // Given
        let renderer = EnhancedWKWebViewPDFRenderer()

        // When
        let pdfData = try await renderer.renderToPDF(html: "<html><body><h1>Anon</h1></body></html>", options: ExportOptions())

        // Then
        let attributes = PDFDocument(data: pdfData)?.documentAttributes
        #expect(attributes?[PDFDocumentAttribute.titleAttribute] == nil)
        #expect(attributes?[PDFDocumentAttribute.authorAttribute] == nil)
    }

    @Test("Refuses a document longer than the page limit instead of cutting it")
    @MainActor
    func test_renderToPDF_refusesDocumentOverPageLimit() async throws {
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

        // When/Then
        do {
            _ = try await renderer.renderToPDF(html: html, options: options)
            Issue.record("Expected tooManyPages")
        } catch PDFExportError.tooManyPages(let count, let limit) {
            #expect(count > 3)
            #expect(limit == 3)
        }
    }

    @Test("Keeps every page when the limit allows them")
    @MainActor
    func test_renderToPDF_keepsAllPagesWithinLimit() async throws {
        // Given
        let renderer = EnhancedWKWebViewPDFRenderer()
        let sections = (1...6).map { index in
            """
            <div style="page-break-before: always;"><h2>Section \(index)</h2><p>Short content</p></div>
            """
        }.joined()
        let html = "<!DOCTYPE html><html><body>\(sections)</body></html>"

        // When
        let pdfData = try await renderer.renderToPDF(html: html, options: ExportOptions(maxPages: 20))

        // Then: nothing is dropped, and the document needs at least a page per section
        let pageCount = try #require(PDFDocument(data: pdfData)?.pageCount)
        #expect(pageCount >= 6)

        // And: the page count the renderer reports in its error is the number of pages that fit the limit
        do {
            _ = try await renderer.renderToPDF(html: html, options: ExportOptions(maxPages: pageCount - 1))
            Issue.record("Expected tooManyPages")
        } catch PDFExportError.tooManyPages(let count, let limit) {
            #expect(count == pageCount)
            #expect(limit == pageCount - 1)
        }
    }

    @Test("Stops waiting for a page that never reports it is ready", .timeLimit(.minutes(1)))
    @MainActor
    func test_renderToPDF_doesNotWaitForeverForReadiness() async throws {
        // Given: the page defines the readiness promise before the renderer's own script, and never resolves it
        let renderer = EnhancedWKWebViewPDFRenderer()
        let html = """
            <!DOCTYPE html>
            <html>
            <head>
                <script>
                    window.__cvPreview = { awaitReady: function() { return new Promise(function() {}); } };
                </script>
            </head>
            <body><h1>Never ready</h1></body>
            </html>
        """

        // When
        let pdfData = try await renderer.renderToPDF(html: html, options: ExportOptions())

        // Then
        #expect(isPDFData(pdfData))
    }

    @Test("Renders again after a render on the same renderer")
    @MainActor
    func test_renderToPDF_rendersTwiceInARow() async throws {
        // Given
        let renderer = EnhancedWKWebViewPDFRenderer()
        let html = "<!DOCTYPE html><html><body><h1>Again</h1></body></html>"

        // When
        let first = try await renderer.renderToPDF(html: html, options: ExportOptions())
        let second = try await renderer.renderToPDF(html: html, options: ExportOptions())

        // Then
        #expect(isPDFData(first))
        #expect(isPDFData(second))
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
        let templateEngine = MustacheTemplateEngine()
        let template = try await TemplateTestStorage.loadBundledTemplate("modern")

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