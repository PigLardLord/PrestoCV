import Testing
import Foundation
@testable import CVPDFExporter

// MARK: - Page Break Manager Tests (Sprint 4)

@Suite("Page Break Manager")
struct PageBreakManagerTests {

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

    @Test("Headings are not cut across two pages")
    func headingsAreNotCut() {
        // Given
        let manager = PageBreakManager()
        let html = "<html><body>Content</body></html>"

        // When
        let result = manager.insertPageBreaks(in: html)

        // Then
        #expect(result.contains("h1, h2, h3, h4, h5, h6"))
        #expect(result.contains("page-break-inside: avoid"))
    }

    @Test("Sections and entries are left free to break across pages")
    func sectionsAndEntriesAreNotForcedTogether() {
        // Given
        let manager = PageBreakManager()
        let html = "<html><body>Content</body></html>"

        // When
        let result = manager.insertPageBreaks(in: html)

        // Then
        #expect(!result.contains(".item"))
        #expect(!result.contains(".section"))
        #expect(!result.contains(".skills-group"))
    }

    @Test("Blocks marked avoid-break stay whole")
    func avoidBreakBlocksStayWhole() {
        // Given
        let manager = PageBreakManager()
        let html = "<html><body>Content</body></html>"

        // When
        let result = manager.insertPageBreaks(in: html)

        // Then
        #expect(result.contains(".avoid-break"))
        #expect(result.contains("page-break-inside: avoid"))
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