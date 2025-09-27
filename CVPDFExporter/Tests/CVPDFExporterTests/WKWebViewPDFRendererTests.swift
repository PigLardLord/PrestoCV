#if canImport(UIKit)
import XCTest
import WebKit
@testable import CVPDFExporter

@MainActor
final class WKWebViewPDFRendererTests: XCTestCase {

    private var sut: WKWebViewPDFRenderer!

    override func setUp() async throws {
        try await super.setUp()
        sut = WKWebViewPDFRenderer()
    }

    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Rendering Tests

    func testRenderToPDFWithSimpleHTML() async throws {
        // Given
        let html = """
        <!DOCTYPE html>
        <html>
        <head><title>Test</title></head>
        <body><h1>Test Document</h1><p>This is a test.</p></body>
        </html>
        """
        let options = ExportOptions.default

        // When
        let pdfData = try await sut.renderToPDF(html: html, options: options)

        // Then
        XCTAssertFalse(pdfData.isEmpty)
        XCTAssertTrue(isPDFData(pdfData))
    }

    func testRenderToPDFWithComplexHTML() async throws {
        // Given
        let html = createComplexHTML()
        let options = ExportOptions.default

        // When
        let pdfData = try await sut.renderToPDF(html: html, options: options)

        // Then
        XCTAssertFalse(pdfData.isEmpty)
        XCTAssertTrue(pdfData.count > 2000, "Complex HTML should generate larger PDF")
        XCTAssertTrue(isPDFData(pdfData))
    }

    func testRenderToPDFWithCustomPageSize() async throws {
        // Given
        let html = "<html><body><h1>Custom Size Test</h1></body></html>"
        let options = ExportOptions(
            pageSize: .letter,
            margins: .uniform(36)
        )

        // When
        let pdfData = try await sut.renderToPDF(html: html, options: options)

        // Then
        XCTAssertFalse(pdfData.isEmpty)
        XCTAssertTrue(isPDFData(pdfData))
    }

    func testRenderToPDFWithEmptyHTML() async throws {
        // Given
        let html = ""
        let options = ExportOptions.default

        // When
        let pdfData = try await sut.renderToPDF(html: html, options: options)

        // Then
        XCTAssertFalse(pdfData.isEmpty, "Even empty HTML should generate PDF")
        XCTAssertTrue(isPDFData(pdfData))
    }

    func testRenderToPDFWithInvalidHTML() async throws {
        // Given - malformed HTML
        let html = "<html><body><h1>Unclosed tag<p>Missing closing tags"
        let options = ExportOptions.default

        // When
        let pdfData = try await sut.renderToPDF(html: html, options: options)

        // Then - should still generate PDF (browsers are forgiving)
        XCTAssertFalse(pdfData.isEmpty)
        XCTAssertTrue(isPDFData(pdfData))
    }

    func testRenderToPDFWithCSS() async throws {
        // Given
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <style>
                body { font-family: Arial; margin: 50px; }
                h1 { color: blue; }
                .highlight { background-color: yellow; }
            </style>
        </head>
        <body>
            <h1>Styled Document</h1>
            <p class="highlight">This text is highlighted.</p>
        </body>
        </html>
        """
        let options = ExportOptions.default

        // When
        let pdfData = try await sut.renderToPDF(html: html, options: options)

        // Then
        XCTAssertFalse(pdfData.isEmpty)
        XCTAssertTrue(isPDFData(pdfData))
    }

    func testRenderToPDFWithJavaScript() async throws {
        // Given - HTML with JavaScript (should be ignored in PDF)
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <script>document.write('This should not execute');</script>
        </head>
        <body>
            <h1>Document with JS</h1>
            <div id="dynamic"></div>
            <script>
                document.getElementById('dynamic').innerHTML = 'Dynamic content';
            </script>
        </body>
        </html>
        """
        let options = ExportOptions.default

        // When
        let pdfData = try await sut.renderToPDF(html: html, options: options)

        // Then
        XCTAssertFalse(pdfData.isEmpty)
        XCTAssertTrue(isPDFData(pdfData))
    }

    // MARK: - Margin Tests

    func testRenderToPDFWithDifferentMargins() async throws {
        let html = "<html><body><h1>Margin Test</h1></body></html>"

        // Test with no margins
        let noMarginOptions = ExportOptions(
            pageSize: .a4,
            margins: EdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        )
        let pdfNoMargin = try await sut.renderToPDF(html: html, options: noMarginOptions)
        XCTAssertFalse(pdfNoMargin.isEmpty)

        // Test with large margins
        let largeMarginOptions = ExportOptions(
            pageSize: .a4,
            margins: .uniform(144) // 2 inches
        )
        let pdfLargeMargin = try await sut.renderToPDF(html: html, options: largeMarginOptions)
        XCTAssertFalse(pdfLargeMargin.isEmpty)

        // Test with asymmetric margins
        let asymmetricOptions = ExportOptions(
            pageSize: .a4,
            margins: EdgeInsets(top: 36, left: 72, bottom: 36, right: 108)
        )
        let pdfAsymmetric = try await sut.renderToPDF(html: html, options: asymmetricOptions)
        XCTAssertFalse(pdfAsymmetric.isEmpty)
    }

    // MARK: - Performance Tests

    func testRenderPerformance() async throws {
        let html = createComplexHTML()
        let options = ExportOptions.default

        let startTime = Date()
        _ = try await sut.renderToPDF(html: html, options: options)
        let endTime = Date()

        let timeInterval = endTime.timeIntervalSince(startTime)
        XCTAssertLessThan(timeInterval, 3.0, "Rendering should complete within 3 seconds")
    }

    func testConcurrentRenderingRequests() async throws {
        let html = "<html><body><h1>Concurrent Test</h1></body></html>"
        let options = ExportOptions.default

        // Launch multiple concurrent rendering tasks
        async let pdf1 = sut.renderToPDF(html: html, options: options)
        async let pdf2 = sut.renderToPDF(html: html, options: options)
        async let pdf3 = sut.renderToPDF(html: html, options: options)

        // Wait for all to complete
        let results = try await (pdf1, pdf2, pdf3)

        // Verify all generated valid PDFs
        XCTAssertTrue(isPDFData(results.0))
        XCTAssertTrue(isPDFData(results.1))
        XCTAssertTrue(isPDFData(results.2))
    }

    // MARK: - Helper Methods

    private func isPDFData(_ data: Data) -> Bool {
        // Check if data starts with PDF header
        let pdfHeader = Data([0x25, 0x50, 0x44, 0x46]) // %PDF
        return data.prefix(4) == pdfHeader
    }

    private func createComplexHTML() -> String {
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Complex Test Document</title>
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                    line-height: 1.6;
                    color: #333;
                    padding: 40px;
                }
                h1 { color: #2C3E50; margin-bottom: 20px; font-size: 24pt; }
                h2 { color: #34495E; margin-top: 30px; margin-bottom: 15px; font-size: 18pt; }
                .section { margin-bottom: 30px; page-break-inside: avoid; }
                .item { margin-bottom: 15px; padding: 10px; background: #f5f5f5; }
                table { width: 100%; border-collapse: collapse; margin: 20px 0; }
                th, td { padding: 10px; border: 1px solid #ddd; text-align: left; }
                th { background: #f0f0f0; font-weight: bold; }
                ul { margin-left: 20px; }
                li { margin-bottom: 5px; }
            </style>
        </head>
        <body>
            <h1>Complex Test Document</h1>

            <div class="section">
                <h2>Section 1: Text Content</h2>
                <p>This is a paragraph with <strong>bold text</strong> and <em>italic text</em>.</p>
                <p>Here's another paragraph with multiple lines of content to test text wrapping
                and line height. Lorem ipsum dolor sit amet, consectetur adipiscing elit.</p>
            </div>

            <div class="section">
                <h2>Section 2: Lists</h2>
                <ul>
                    <li>First item</li>
                    <li>Second item with <strong>formatting</strong></li>
                    <li>Third item</li>
                </ul>
            </div>

            <div class="section">
                <h2>Section 3: Table</h2>
                <table>
                    <thead>
                        <tr>
                            <th>Column 1</th>
                            <th>Column 2</th>
                            <th>Column 3</th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr>
                            <td>Data 1</td>
                            <td>Data 2</td>
                            <td>Data 3</td>
                        </tr>
                        <tr>
                            <td>Data 4</td>
                            <td>Data 5</td>
                            <td>Data 6</td>
                        </tr>
                    </tbody>
                </table>
            </div>

            <div class="section">
                <h2>Section 4: Complex Layout</h2>
                <div class="item">
                    <h3>Item Title</h3>
                    <p>Item description with details.</p>
                </div>
                <div class="item">
                    <h3>Another Item</h3>
                    <p>More content here.</p>
                </div>
            </div>
        </body>
        </html>
        """
    }
}
#endif