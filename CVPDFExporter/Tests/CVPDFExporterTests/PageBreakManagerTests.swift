import Testing
import Foundation
@testable import CVPDFExporter

// MARK: - Page Break Manager Tests (Sprint 4)

@Suite("Page Break Manager")
struct PageBreakManagerTests {

    @Test("Page break manager initializes correctly")
    func pageBreakManagerInitializes() {
        // Given/When
        let manager = PageBreakManager()

        // Then
        #expect(manager.maxPages == 4)
    }

    @Test("Insert page break CSS into HTML")
    func insertPageBreakCSS() {
        // Given
        let manager = PageBreakManager()
        let html = """
        <html>
        <head>
            <style>body { font-size: 12pt; }</style>
        </head>
        <body>Content</body>
        </html>
        """

        // When
        let result = manager.insertPageBreaks(in: html)

        // Then
        #expect(result.contains("page-break"))
        #expect(result.contains("@media print"))
        #expect(result.contains("page-break-inside: avoid"))
    }

    @Test("Page break CSS respects existing styles")
    func pageBreakCSSRespectsExistingStyles() {
        // Given
        let manager = PageBreakManager()
        let html = """
        <html>
        <head>
            <style>
                body { color: blue; }
            </style>
        </head>
        <body>Content</body>
        </html>
        """

        // When
        let result = manager.insertPageBreaks(in: html)

        // Then
        #expect(result.contains("color: blue"))  // Original style preserved
        #expect(result.contains("page-break"))    // New styles added
    }

    @Test("Insert page break CSS when no style tag exists")
    func insertPageBreakCSSNoStyleTag() {
        // Given
        let manager = PageBreakManager()
        let html = """
        <html>
        <head></head>
        <body>Content</body>
        </html>
        """

        // When
        let result = manager.insertPageBreaks(in: html)

        // Then
        #expect(result.contains("<style>"))
        #expect(result.contains("page-break"))
    }

    @Test("Configure maximum pages")
    func configureMaximumPages() {
        // Given
        let manager = PageBreakManager(maxPages: 6)

        // Then
        #expect(manager.maxPages == 6)

        // When
        let defaultManager = PageBreakManager()

        // Then
        #expect(defaultManager.maxPages == 4)
    }

    @Test("Ensure critical elements avoid page breaks")
    func ensureCriticalElementsAvoidBreaks() {
        // Given
        let manager = PageBreakManager()
        let html = "<html><body>Content</body></html>"

        // When
        let result = manager.insertPageBreaks(in: html)

        // Then
        // Headers should not break after
        #expect(result.contains("page-break-after: avoid"))
        // Items should not break inside
        #expect(result.contains(".item"))
        #expect(result.contains("page-break-inside: avoid"))
        // Sections should not break inside
        #expect(result.contains(".section"))
    }

    @Test("Page break manager is thread safe")
    func pageBreakManagerIsThreadSafe() async {
        // Given
        let manager = PageBreakManager()
        let html = "<html><body>Test</body></html>"

        // When - process multiple HTML strings concurrently
        async let result1 = Task { manager.insertPageBreaks(in: html) }.value
        async let result2 = Task { manager.insertPageBreaks(in: html + "2") }.value
        async let result3 = Task { manager.insertPageBreaks(in: html + "3") }.value

        let results = await [result1, result2, result3]

        // Then
        for result in results {
            #expect(result.contains("page-break"))
        }
    }

    @Test("Returns original HTML if empty")
    func returnsOriginalIfEmpty() {
        // Given
        let manager = PageBreakManager()
        let html = ""

        // When
        let result = manager.insertPageBreaks(in: html)

        // Then
        #expect(result == html)
    }
}