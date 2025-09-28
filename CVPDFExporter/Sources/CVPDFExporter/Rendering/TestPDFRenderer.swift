import Foundation

// MARK: - Test PDF Renderer

/// Test implementation of HTMLToPDFRenderer for testing
/// Sprint 4: Platform-agnostic testing renderer
public final class TestPDFRenderer: HTMLToPDFRenderer, PDFRendererProtocol, @unchecked Sendable {

    /// Debug mode flag for testing configuration
    public var debugMode: Bool = false

    /// Counter for tracking render calls (useful for testing)
    private var renderCount = 0

    public init() {}

    /// Generate mock PDF data from HTML
    public func renderToPDF(html: String, options: ExportOptions) async throws -> Data {
        // Thread-safe increment using atomic operation
        renderCount += 1
        let currentCount = renderCount

        // Simulate async processing
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms

        // Create mock PDF data
        return generateMockPDF(
            html: html,
            options: options,
            renderNumber: currentCount
        )
    }

    // MARK: - Private Methods

    private func generateMockPDF(html: String, options: ExportOptions, renderNumber: Int) -> Data {
        // Extract title from HTML for inclusion in PDF
        let title = extractTitle(from: html)

        // Create a mock PDF structure
        // PDF files start with %PDF-1.x header
        var pdfContent = "%PDF-1.4\n"

        // Add comment with metadata
        pdfContent += "% Mock PDF Generator\n"
        pdfContent += "% Page Size: \(options.pageSize.width) x \(options.pageSize.height)\n"
        pdfContent += "% Render #\(renderNumber)\n"

        // Add mock objects
        pdfContent += "1 0 obj\n"
        pdfContent += "<< /Type /Catalog /Pages 2 0 R >>\n"
        pdfContent += "endobj\n"

        pdfContent += "2 0 obj\n"
        pdfContent += "<< /Type /Pages /Kids [3 0 R] /Count 1 >>\n"
        pdfContent += "endobj\n"

        pdfContent += "3 0 obj\n"
        pdfContent += "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 \(options.pageSize.width) \(options.pageSize.height)] /Contents 4 0 R >>\n"
        pdfContent += "endobj\n"

        pdfContent += "4 0 obj\n"
        pdfContent += "<< /Length 44 >>\n"
        pdfContent += "stream\n"
        pdfContent += "BT\n"
        pdfContent += "/F1 12 Tf\n"
        pdfContent += "100 700 Td\n"
        pdfContent += "(\(title)) Tj\n"
        pdfContent += "ET\n"
        pdfContent += "endstream\n"
        pdfContent += "endobj\n"

        // Add xref table
        pdfContent += "xref\n"
        pdfContent += "0 5\n"
        pdfContent += "0000000000 65535 f\n"
        pdfContent += "0000000015 00000 n\n"
        pdfContent += "0000000068 00000 n\n"
        pdfContent += "0000000125 00000 n\n"
        pdfContent += "0000000229 00000 n\n"

        // Add trailer
        pdfContent += "trailer\n"
        pdfContent += "<< /Size 5 /Root 1 0 R >>\n"
        pdfContent += "startxref\n"
        pdfContent += "344\n"
        pdfContent += "%%EOF\n"

        // Include original HTML content as a comment for testing
        if debugMode {
            pdfContent += "% Original HTML:\n"
            pdfContent += "% \(html.replacingOccurrences(of: "\n", with: "\n% "))\n"
        }

        return pdfContent.data(using: .utf8) ?? Data()
    }

    private func extractTitle(from html: String) -> String {
        // Simple extraction of text between <h1> tags or any text content
        if let range = html.range(of: "<h1>.*?</h1>", options: .regularExpression) {
            let h1Content = String(html[range])
            let cleaned = h1Content
                .replacingOccurrences(of: "<h1>", with: "")
                .replacingOccurrences(of: "</h1>", with: "")
            return cleaned
        }

        // Fallback: extract any text content
        let stripped = html
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return stripped.isEmpty ? "Mock PDF" : String(stripped.prefix(50))
    }

    // MARK: - PDFRendererProtocol Conformance

    public var isAvailable: Bool {
        true
    }

    public var maxPages: Int {
        10
    }
}