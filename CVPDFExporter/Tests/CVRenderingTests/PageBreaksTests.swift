import Testing
import CVRendering
import CVRenderingTestSupport

/// #467: what the native renderers' page-break check reads in the layout of a printed CV.
@Suite("#467 · page breaks read from a layout")
struct PageBreaksTests {
    static let titles = ["Profile", "Experience"]

    static func line(_ text: String, page: Int, y: Double) -> PDFTextLine {
        textLine(text, page: page, PDFBox(x: 40, y: y, width: 200, height: 12), glyphHeight: 10)
    }

    @Test("a page whose lowest line is a section title has that title alone at its foot, whatever the order of the lines")
    func titleAlone() {
        let layout = PDFLayout(pages: [a4Page, a4Page], lines: [
            Self.line("Line 1 of a profile that fills the page.", page: 0, y: 760),
            Self.line("Experience", page: 0, y: 40),
            Self.line("Line 30 of a profile that fills the page.", page: 0, y: 60),
            Self.line("Senior developer", page: 1, y: 760),
            Self.line("Duty 8 of the role, one line long.", page: 1, y: 600),
        ])
        #expect(PageBreaks.faults(in: layout, titles: Self.titles) == [.titleAlone(page: 0, title: "Experience")])
    }

    @Test("a title printed in capitals, or with its letters spaced out, is still the title")
    func printedTitle() {
        let layout = PDFLayout(pages: [a4Page, a4Page, a4Page], lines: [
            Self.line("EXPERIENCE", page: 0, y: 40),
            Self.line("P R O F I L E", page: 1, y: 40),
            Self.line("Senior developer", page: 2, y: 760),
        ])
        #expect(PageBreaks.faults(in: layout, titles: Self.titles)
                == [.titleAlone(page: 0, title: "EXPERIENCE"), .titleAlone(page: 1, title: "P R O F I L E")])
    }

    @Test("a title with its first entry below it on the same page, and a line that only contains a title's word, are no fault")
    func titleWithItsEntry() {
        let layout = PDFLayout(pages: [a4Page], lines: [
            Self.line("Experience", page: 0, y: 100),
            Self.line("Senior developer", page: 0, y: 80),
            Self.line("Line 4 of a profile with experience", page: 0, y: 60),
        ])
        #expect(PageBreaks.faults(in: layout, titles: Self.titles).isEmpty)
    }

    @Test("a page with no line is blank, the last one or one between two pages of text")
    func blankPage() {
        let layout = PDFLayout(pages: [a4Page, a4Page, a4Page, a4Page], lines: [
            Self.line("Line 1 of a profile that fills the page.", page: 0, y: 760),
            Self.line("Senior developer", page: 2, y: 760),
        ])
        #expect(PageBreaks.faults(in: layout, titles: Self.titles) == [.blankPage(page: 1), .blankPage(page: 3)])
    }
}
