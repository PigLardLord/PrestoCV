import Testing
@testable import CVRendering
import CVRenderingTestSupport

/// #467: what the native renderers' page-break check reads in the layout of a printed CV.
@Suite("#467 · page breaks read from a layout")
struct PageBreaksTests {
    static let starts = ["Profile", "Experience", "Senior developer", "Example GmbH"]
    static let margin = 36.0

    static func line(_ text: String, page: Int, y: Double) -> PDFTextLine {
        textLine(text, page: page, PDFBox(x: 40, y: y, width: 200, height: 12), glyphHeight: 10)
    }

    static func faults(_ layout: PDFLayout) -> [PageBreakFault] {
        PageBreaks.faults(in: layout, starts: starts, margin: margin)
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
        #expect(Self.faults(layout) == [.startSplit(page: 0, line: "Experience")])
    }

    @Test("a page whose lowest line is the head of a section's first entry splits that start from the entry's description")
    func headAlone() {
        let layout = PDFLayout(pages: [a4Page, a4Page], lines: [
            Self.line("Experience", page: 0, y: 70),
            Self.line("Senior developer", page: 0, y: 55),
            Self.line("Example GmbH", page: 0, y: 40),
            Self.line("Duty 1 of the role, one line long.", page: 1, y: 760),
        ])
        #expect(Self.faults(layout) == [.startSplit(page: 0, line: "Example GmbH")])
    }

    @Test("a title printed in capitals, or with its letters spaced out, is still the title")
    func printedTitle() {
        let layout = PDFLayout(pages: [a4Page, a4Page, a4Page], lines: [
            Self.line("EXPERIENCE", page: 0, y: 40),
            Self.line("P R O F I L E", page: 1, y: 40),
            Self.line("Duty 1 of the role, one line long.", page: 2, y: 760),
        ])
        #expect(Self.faults(layout) == [.startSplit(page: 0, line: "EXPERIENCE"), .startSplit(page: 1, line: "P R O F I L E")])
    }

    @Test("a start with its first description line below it on the same page, and a line that only contains a start's word, are no fault")
    func startWithItsEntry() {
        let layout = PDFLayout(pages: [a4Page], lines: [
            Self.line("Experience", page: 0, y: 100),
            Self.line("Senior developer", page: 0, y: 80),
            Self.line("Line 4 of a profile with experience", page: 0, y: 60),
        ])
        #expect(Self.faults(layout).isEmpty)
    }

    @Test("a page with no line is blank, the last one or one between two pages of text")
    func blankPage() {
        let layout = PDFLayout(pages: [a4Page, a4Page, a4Page, a4Page], lines: [
            Self.line("Line 1 of a profile that fills the page.", page: 0, y: 760),
            Self.line("Duty 1 of the role, one line long.", page: 2, y: 760),
        ])
        #expect(Self.faults(layout) == [.blankPage(page: 1), .blankPage(page: 3)])
    }

    @Test("a line reaching past the tolerance into the top or the bottom margin was cut by the page's edge; one inside it is not")
    func cutLine() {
        let layout = PDFLayout(pages: [a4Page], lines: [
            Self.line("Top of a skills row", page: 0, y: 842 - 36 - 12 + 1.5),
            Self.line("Line 1 of a profile that fills the page.", page: 0, y: 842 - 36 - 12 + 1),
            Self.line("Line 30 of a profile that fills the page.", page: 0, y: 35),
            Self.line("Foot of a skills row", page: 0, y: 34.5),
        ])
        #expect(Self.faults(layout) == [.cut(page: 0, text: "Top of a skills row"), .cut(page: 0, text: "Foot of a skills row")])
    }

    @Test("the whole check adds the document's text the PDF lacks and the lines outside the page, after the page faults")
    func wholeDocument() {
        let document = RenderedDocument(html: "", textNodes: ["Alex Example", "Skill 200 with a long name"])
        let layout = PDFLayout(pages: [a4Page, a4Page], lines: [
            Self.line("Alex Example", page: 0, y: 760),
            Self.line("Experience", page: 0, y: 40),
            textLine("Skill 199 with a long name", page: 1, PDFBox(x: 500, y: 400, width: 100, height: 12), glyphHeight: 10),
        ])
        let faults = PageBreaks.faults(of: document, printedAs: layout, text: "Alex Example\nExperience\nSkill 199 with a long name",
                                       starts: Self.starts, page: .a4)
        #expect(faults == [.startSplit(page: 0, line: "Experience"), .missing(["Skill 200 with a long name"]),
                           .geometry([.outsidePage(page: 1, text: "Skill 199 with a long name")])])
    }
}
