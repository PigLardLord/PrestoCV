import Testing
import CVRendering
import CVRenderingTestSupport

@Suite("#558 · a layout compared with its reference")
struct LayoutComparisonTests {
    static let page = PDFBox(x: 0, y: 0, width: 595, height: 842)

    static func line(_ text: String, page: Int = 0, x: Double = 36, y: Double, width: Double = 200, height: Double = 12) -> PDFTextLine {
        PDFTextLine(pageIndex: page, text: text, box: PDFBox(x: x, y: y, width: width, height: height), glyphHeight: 10)
    }

    static let reference = PDFLayout(pages: [page, page], lines: [
        line("Ada Lovelace", y: 780), line("Profile", y: 740), line("Line one", y: 720), line("Line two", y: 700),
        line("Experience", page: 1, y: 780),
    ])

    static func changing(_ change: (inout [PDFTextLine]) -> Void) -> PDFLayout {
        var lines = reference.lines
        change(&lines)
        return PDFLayout(pages: reference.pages, lines: lines)
    }

    @Test("the same layout has no difference")
    func same() {
        #expect(LayoutComparison.differences(Self.reference, from: Self.reference).isEmpty)
    }

    @Test("a line moved or resized by at most the tolerance has no difference")
    func withinTolerance() {
        let found = Self.changing {
            $0[1].box.x += 0.5; $0[1].box.y -= 0.5; $0[2].box.width += 0.5; $0[3].box.height -= 0.5
        }
        #expect(LayoutComparison.differences(found, from: Self.reference).isEmpty)
    }

    @Test("a line moved by more than the tolerance is reported with its page, its text and how far it moved")
    func moved() {
        let found = Self.changing { $0[1].box.y -= 0.75; $0[4].box.x += 2 }
        #expect(LayoutComparison.differences(found, from: Self.reference) == [
            .moved(page: 0, text: "Profile", dx: 0, dy: -0.75, dwidth: 0, dheight: 0),
            .moved(page: 1, text: "Experience", dx: 2, dy: 0, dwidth: 0, dheight: 0),
        ])
    }

    @Test("a line that grew or shrank by more than the tolerance is reported")
    func resized() {
        let found = Self.changing { $0[2].box.width += 1.25; $0[3].box.height -= 0.75 }
        #expect(LayoutComparison.differences(found, from: Self.reference) == [
            .moved(page: 0, text: "Line one", dx: 0, dy: 0, dwidth: 1.25, dheight: 0),
            .moved(page: 0, text: "Line two", dx: 0, dy: 0, dwidth: 0, dheight: -0.75),
        ])
    }

    @Test("a wider tolerance lets a larger move pass")
    func tolerance() {
        let found = Self.changing { $0[1].box.y -= 0.75 }
        #expect(LayoutComparison.differences(found, from: Self.reference, tolerance: 1).isEmpty)
    }

    @Test("a line on another page is reported with both pages, and not as moved")
    func otherPage() {
        let found = Self.changing { $0[3].pageIndex = 1; $0[3].box.y = 790 }
        #expect(LayoutComparison.differences(found, from: Self.reference) == [.otherPage(text: "Line two", reference: 0, found: 1)])
    }

    @Test("another page count is reported first")
    func pageCount() {
        let found = PDFLayout(pages: [Self.page, Self.page, Self.page], lines: Self.reference.lines)
        #expect(LayoutComparison.differences(found, from: Self.reference) == [.pageCount(reference: 2, found: 3)])
    }

    @Test("a missing line is reported, and the lines after it are still compared with their own reference")
    func missing() {
        let found = Self.changing { $0.remove(at: 2); $0[2].box.x += 1 }
        #expect(LayoutComparison.differences(found, from: Self.reference) == [
            .missing(page: 0, text: "Line one"),
            .moved(page: 0, text: "Line two", dx: 1, dy: 0, dwidth: 0, dheight: 0),
        ])
    }

    @Test("an extra line is reported, and the lines after it are still compared with their own reference")
    func extra() {
        let found = Self.changing { $0.insert(Self.line("Line one and a half", y: 710), at: 3) }
        #expect(LayoutComparison.differences(found, from: Self.reference) == [.extra(page: 0, text: "Line one and a half")])
    }

    @Test("a line whose text changed is missing in its old text and extra in its new one")
    func changedText() {
        let found = Self.changing { $0[2].text = "Line 1" }
        #expect(LayoutComparison.differences(found, from: Self.reference) == [
            .missing(page: 0, text: "Line one"), .extra(page: 0, text: "Line 1"),
        ])
    }

    @Test("lines with the same text are matched in order")
    func repeatedText() {
        let reference = PDFLayout(pages: [Self.page], lines: [Self.line("Berlin", y: 700), Self.line("Berlin", y: 600)])
        let found = PDFLayout(pages: [Self.page], lines: [Self.line("Berlin", y: 700), Self.line("Berlin", y: 601)])
        #expect(LayoutComparison.differences(found, from: reference) == [
            .moved(page: 0, text: "Berlin", dx: 0, dy: 1, dwidth: 0, dheight: 0),
        ])
    }

    @Test("each difference reads as a sentence, its pages counted from 1")
    func descriptions() {
        #expect(LayoutDifference.pageCount(reference: 2, found: 3).description == "2 pages in the reference, 3 found")
        #expect(LayoutDifference.missing(page: 0, text: "Profile").description == "page 1: \"Profile\" is missing")
        #expect(LayoutDifference.extra(page: 1, text: "Profile").description == "page 2: \"Profile\" is extra")
        #expect(LayoutDifference.otherPage(text: "Profile", reference: 0, found: 1).description
            == "\"Profile\" is on page 2, on page 1 in the reference")
        #expect(LayoutDifference.moved(page: 0, text: "Profile", dx: 0, dy: -0.75, dwidth: 1.25, dheight: 0.004).description
            == "page 1: \"Profile\" moved by x +0.00, y -0.75, width +1.25, height +0.00")
    }
}
