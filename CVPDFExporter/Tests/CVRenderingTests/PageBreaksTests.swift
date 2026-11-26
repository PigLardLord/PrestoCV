import Testing
@testable import CVRendering
@testable import CVRenderingTestSupport

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

    @Test("a line wholly in a margin that the neighbouring page prints in the same place is the copy the page clips: no fault, and not the page's foot")
    func clippedCopy() {
        // A4 less its margins is a page step of 770pt; WebKit rounds it to its own pixels, here 0.4pt short.
        let layout = PDFLayout(pages: [a4Page, a4Page, a4Page], lines: [
            Self.line("Line 8 of a profile that fills the page.", page: 0, y: 392),
            Self.line("Experience", page: 0, y: 22),
            Self.line("Experience", page: 1, y: 791.6),
            Self.line("Senior developer", page: 1, y: 770),
            Self.line("Duty 8 of the role, one line long.", page: 1, y: 40),
            Self.line("Duty 8 of the role, one line long.", page: 2, y: 810.4),
            Self.line("Duty 9 of the role, one line long.", page: 2, y: 760),
        ])
        #expect(Self.faults(layout).isEmpty)
    }

    @Test("a line wholly in a margin that no neighbouring page prints in its place is hidden, and a page that shows no line is blank")
    func hiddenLine() {
        let layout = PDFLayout(pages: [a4Page, a4Page, a4Page], lines: [
            Self.line("Line 1 of a profile that fills the page.", page: 0, y: 760),
            Self.line("Experience", page: 0, y: 22),
            Self.line("Experience", page: 1, y: 700),
            Self.line("Duty 1 of the role, one line long.", page: 1, y: 600),
            Self.line("Duty 9 of the role, one line long.", page: 1, y: 810),
            Self.line("Duty 9 of the role, one line long.", page: 2, y: 10),
        ])
        #expect(Self.faults(layout) == [.hidden(page: 0, text: "Experience"), .hidden(page: 1, text: "Duty 9 of the role, one line long."),
                                        .hidden(page: 2, text: "Duty 9 of the role, one line long."), .blankPage(page: 2)])
    }

    @Test("the whole check adds the document's text the PDF lacks and the lines outside the page, after the page faults")
    func wholeDocument() {
        let document = RenderedDocument(html: "", textNodes: ["Alex Example", "Skill 200 with a long name"])
        let layout = PDFLayout(pages: [a4Page, a4Page], lines: [
            Self.line("Alex Example", page: 0, y: 760),
            Self.line("Experience", page: 0, y: 40),
            textLine("Skill 199 with a long name", page: 1, PDFBox(x: 500, y: 400, width: 100, height: 12), glyphHeight: 10),
        ])
        let faults = PageBreaks.faults(of: document, printedAs: layout,
                                       starts: Self.starts, page: .a4)
        #expect(faults == [.startSplit(page: 0, line: "Experience"), .missing(["Skill 200 with a long name"]),
                           .geometry([.outsidePage(page: 1, text: "Skill 199 with a long name")])])
    }

    @Test("two expected identical nodes of which one prints, beside the clipped copy the next page also prints, lack one: the copy is not a second print")
    func clippedCopyIsNotAnOccurrence() {
        let document = RenderedDocument(html: "", textNodes: ["Skill 1 with a long name", "Skill 1 with a long name"])
        let layout = PDFLayout(pages: [a4Page, a4Page], lines: [
            Self.line("Skill 1 with a long name", page: 0, y: 22),
            Self.line("Skill 1 with a long name", page: 1, y: 792),
            Self.line("Line 1 of a profile that fills the page.", page: 0, y: 760),
        ])
        let faults = PageBreaks.faults(of: document, printedAs: layout, starts: Self.starts, page: .a4)
        #expect(faults == [.missing(["Skill 1 with a long name"])])
    }

    @Test("an expected node that two visible lines print is duplicated content")
    func visibleDuplicate() {
        let document = RenderedDocument(html: "", textNodes: ["Skill 1 with a long name"])
        let layout = PDFLayout(pages: [a4Page], lines: [
            Self.line("Skill 1 with a long name", page: 0, y: 700),
            Self.line("Skill 1 with a long name", page: 0, y: 500),
        ])
        let faults = PageBreaks.faults(of: document, printedAs: layout, starts: Self.starts, page: .a4)
        #expect(faults == [.duplicated(["Skill 1 with a long name"])])
    }

    @Test("a node printed once on its page and once more as the clipped copy beside it, with the same count of nodes, is complete and not duplicated")
    func clippedCopyIsNoDuplicate() {
        let document = RenderedDocument(html: "", textNodes: ["Skill 1 with a long name", "Line 1 of a profile that fills the page."])
        let layout = PDFLayout(pages: [a4Page, a4Page], lines: [
            Self.line("Line 1 of a profile that fills the page.", page: 0, y: 760),
            Self.line("Skill 1 with a long name", page: 0, y: 22),
            Self.line("Skill 1 with a long name", page: 1, y: 792),
        ])
        let faults = PageBreaks.faults(of: document, printedAs: layout, starts: Self.starts, page: .a4)
        #expect(faults.isEmpty)
    }

    @Test("a node that wraps into two visible lines, both printed twice, is duplicated content")
    func wrappedDuplicate() {
        let duty = "Duty 1 of the role, long enough to wrap onto a second line."
        let document = RenderedDocument(html: "", textNodes: [duty])
        let layout = PDFLayout(pages: [a4Page], lines: [
            Self.line("Duty 1 of the role, long enough", page: 0, y: 700),
            Self.line("to wrap onto a second line.", page: 0, y: 686),
            Self.line("Duty 1 of the role, long enough", page: 0, y: 500),
            Self.line("to wrap onto a second line.", page: 0, y: 486),
        ])
        let faults = PageBreaks.faults(of: document, printedAs: layout, starts: Self.starts, page: .a4)
        #expect(faults == [.duplicated([duty])])
    }

    @Test("a node printed once beside a longer node that starts with it and wraps after it is complete and not duplicated")
    func wrappedNodeStartingWithAnother() {
        let document = RenderedDocument(html: "", textNodes: ["Experience", "Experience with X"])
        let layout = PDFLayout(pages: [a4Page], lines: [
            Self.line("Experience", page: 0, y: 700),
            Self.line("Experience", page: 0, y: 680),
            Self.line("with X", page: 0, y: 666),
        ])
        let faults = PageBreaks.faults(of: document, printedAs: layout, starts: Self.starts, page: .a4)
        #expect(faults.isEmpty)
    }

    @Test("a print in another reading order than the document's, as a sidebar's, where one node's text runs across two others, is not duplicated")
    func otherReadingOrder() {
        let document = RenderedDocument(html: "", textNodes: ["Greg", "Go", "Officer"])
        let layout = PDFLayout(pages: [a4Page], lines: [
            Self.line("Go", page: 0, y: 700),
            Self.line("Greg", page: 0, y: 680),
            Self.line("Officer", page: 0, y: 666),
        ])
        let faults = PageBreaks.faults(of: document, printedAs: layout, starts: Self.starts, page: .a4)
        #expect(faults.isEmpty)
    }

    @Test("only the first line of a wrapped node repeated at a page break is duplicated content of that node")
    func repeatedFirstLine() {
        let duty = "Duty 1 of the role, long enough to wrap onto a second line."
        let other = "Skill 1 with a long name"
        let document = RenderedDocument(html: "", textNodes: [other, duty])
        let layout = PDFLayout(pages: [a4Page, a4Page], lines: [
            Self.line(other, page: 0, y: 740),
            Self.line("Duty 1 of the role, long enough", page: 0, y: 700),
            Self.line("Duty 1 of the role, long enough", page: 1, y: 700),
            Self.line("to wrap onto a second line.", page: 1, y: 686),
        ])
        let faults = PageBreaks.faults(of: document, printedAs: layout, starts: Self.starts, page: .a4)
        #expect(faults == [.duplicated([duty])])
    }

    @Test("only the second line of a wrapped node repeated is duplicated content of that node")
    func repeatedLastLine() {
        let duty = "Duty 1 of the role, long enough to wrap onto a second line."
        let document = RenderedDocument(html: "", textNodes: [duty])
        let layout = PDFLayout(pages: [a4Page], lines: [
            Self.line("Duty 1 of the role, long enough", page: 0, y: 700),
            Self.line("to wrap onto a second line.", page: 0, y: 686),
            Self.line("to wrap onto a second line.", page: 0, y: 500),
        ])
        let faults = PageBreaks.faults(of: document, printedAs: layout, starts: Self.starts, page: .a4)
        #expect(faults == [.duplicated([duty])])
    }

    @Test("the first line of a wrapped node repeated after the whole node is duplicated content of that node")
    func repeatedFirstLineAfterTheNode() {
        let duty = "Duty 1 of the role, long enough to wrap onto a second line."
        let document = RenderedDocument(html: "", textNodes: [duty])
        let layout = PDFLayout(pages: [a4Page], lines: [
            Self.line("Duty 1 of the role, long enough", page: 0, y: 700),
            Self.line("to wrap onto a second line.", page: 0, y: 686),
            Self.line("Duty 1 of the role, long enough", page: 0, y: 500),
        ])
        let faults = PageBreaks.faults(of: document, printedAs: layout, starts: Self.starts, page: .a4)
        #expect(faults == [.duplicated([duty])])
    }

    @Test("a correct print of many identical nodes beside separators tries none of their lines as left over")
    func identicalNodesTryNoLine() {
        let duty = "Duty one of the role"
        let expected = Array(repeating: duty, count: 60)
        let lines = [String(repeating: "-", count: 40)] + expected
        #expect(PageBreaks.leftOverCandidates(in: lines, expected: expected).isEmpty)
        let layout = PDFLayout(pages: [a4Page], lines: lines.enumerated().map { Self.line($1, page: 0, y: 760 - Double($0) * 11) })
        #expect(PageBreaks.faults(of: RenderedDocument(html: "", textNodes: expected), printedAs: layout, starts: [], page: .a4).isEmpty)
    }

    @Test("text no node holds, as bullets and separators, a hyphen inside a node, and identical nodes printed as often as held are not duplicated")
    func noFalseDuplicate() {
        let document = RenderedDocument(html: "", textNodes: ["Front-end developer", "Duty one of the role", "Duty one of the role"])
        let layout = PDFLayout(pages: [a4Page], lines: [
            Self.line("\u{2022}", page: 0, y: 700), Self.line("Duty one of the role", page: 0, y: 700),
            Self.line("\u{2022}", page: 0, y: 680), Self.line("Duty one of the role", page: 0, y: 680),
            Self.line("-", page: 0, y: 660), Self.line("|", page: 0, y: 640), Self.line("-", page: 0, y: 620),
            Self.line("Front-end developer", page: 0, y: 600),
        ])
        let faults = PageBreaks.faults(of: document, printedAs: layout, starts: Self.starts, page: .a4)
        #expect(faults.isEmpty)
    }

    @Test("a node beside a longer node that starts with it is not duplicated, whatever line the longer one wraps at or the order of the lines")
    func prefixNodesInAnyOrder() {
        let document = RenderedDocument(html: "", textNodes: ["Experience", "Experience with X"])
        let orders: [[String]] = [["Experience", "Experience with X"], ["Experience with", "X", "Experience"],
                                  ["Experience", "Experience", "with X"], ["Experience with X", "Experience"]]
        for order in orders {
            let lines = order.enumerated().map { Self.line($1, page: 0, y: 700 - Double($0) * 14) }
            let faults = PageBreaks.faults(of: document, printedAs: PDFLayout(pages: [a4Page], lines: lines),
                                           starts: [], page: .a4)
            #expect(faults.isEmpty, "\(order)")
        }
    }
}
