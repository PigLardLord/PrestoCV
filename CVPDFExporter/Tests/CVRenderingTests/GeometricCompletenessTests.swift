import Testing
import Foundation
import CVDocumentModel
import CVDesignCatalog
@testable import CVRendering
import CVRenderingTestSupport

/// An A4 page in PDF points, origin at the lower left.
let a4Page = PDFBox(x: 0, y: 0, width: 595, height: 842)

func textLine(_ text: String, page: Int, _ box: PDFBox, glyphHeight: Double?) -> PDFTextLine {
    PDFTextLine(pageIndex: page, text: text, box: box, glyphHeight: glyphHeight)
}

@Suite("#80 · geometric completeness")
struct GeometricCompletenessTests {
    @Test("the minimum glyph height is 6 pt, below the 7 pt the design grammar allows")
    func minimum() {
        #expect(GeometricCompleteness.minimumGlyphHeight == 6)
    }

    @Test("a line inside the page passes, on the edge and at the minimum glyph height")
    func inside() {
        let layout = PDFLayout(pages: [a4Page], lines: [
            textLine("Middle", page: 0, PDFBox(x: 40, y: 400, width: 200, height: 12), glyphHeight: 10),
            textLine("Bottom left corner", page: 0, PDFBox(x: 0, y: 0, width: 100, height: 12), glyphHeight: 6),
            textLine("Top right corner", page: 0, PDFBox(x: 495, y: 830, width: 100, height: 12), glyphHeight: 6),
            textLine("One point past every edge", page: 0, PDFBox(x: -1, y: -1, width: 597, height: 844), glyphHeight: 6),
        ])
        #expect(GeometricCompleteness.violations(in: layout, minimumGlyphHeight: 6).isEmpty)
    }

    struct Side: Sendable, CustomTestStringConvertible {
        let name: String, box: PDFBox
        var testDescription: String { name }
    }
    /// Each box lies half a point past the tolerance of one side and inside the others.
    static let sides: [Side] = [
        Side(name: "left", box: PDFBox(x: -1.5, y: 400, width: 100, height: 12)),
        Side(name: "right", box: PDFBox(x: 500, y: 400, width: 96.5, height: 12)),
        Side(name: "top", box: PDFBox(x: 40, y: 831.5, width: 100, height: 12)),
        Side(name: "bottom", box: PDFBox(x: 40, y: -1.5, width: 100, height: 12)),
    ]

    @Test("a line past any of the four sides is reported", arguments: sides)
    func pastASide(side: Side) {
        let layout = PDFLayout(pages: [a4Page], lines: [textLine("Past", page: 0, side.box, glyphHeight: 10)])
        #expect(GeometricCompleteness.violations(in: layout, minimumGlyphHeight: 6) == [.outsidePage(page: 0, text: "Past")],
                "a line half a point past the \(side.name) edge must be outside the page")
    }

    @Test("a page whose media box does not start at zero is measured from its own origin")
    func offsetPage() {
        let page = PDFBox(x: 100, y: 200, width: 595, height: 842)
        let layout = PDFLayout(pages: [page], lines: [
            textLine("Inside", page: 0, PDFBox(x: 140, y: 600, width: 100, height: 12), glyphHeight: 10),
            textLine("Left of the origin", page: 0, PDFBox(x: 40, y: 600, width: 100, height: 12), glyphHeight: 10),
        ])
        #expect(GeometricCompleteness.violations(in: layout, minimumGlyphHeight: 6) == [.outsidePage(page: 0, text: "Left of the origin")])
    }

    @Test("a glyph below the minimum height is reported, with its text and page")
    func tooSmall() {
        let layout = PDFLayout(pages: [a4Page, a4Page], lines: [
            textLine("Readable", page: 0, PDFBox(x: 40, y: 400, width: 100, height: 12), glyphHeight: 10),
            textLine("Tiny", page: 1, PDFBox(x: 40, y: 400, width: 100, height: 7), glyphHeight: 5.9),
        ])
        #expect(GeometricCompleteness.violations(in: layout, minimumGlyphHeight: 6) == [.glyphTooSmall(page: 1, text: "Tiny")])
    }

    @Test("a line whose glyph height is unknown fails closed")
    func unknownHeight() {
        let layout = PDFLayout(pages: [a4Page], lines: [textLine("No font", page: 0, PDFBox(x: 40, y: 400, width: 100, height: 12), glyphHeight: nil)])
        #expect(GeometricCompleteness.violations(in: layout, minimumGlyphHeight: 6) == [.unknownGlyphHeight(page: 0, text: "No font")])
    }

    @Test("a line on a page the document does not have is outside the page")
    func missingPage() {
        let layout = PDFLayout(pages: [a4Page], lines: [textLine("Nowhere", page: 1, PDFBox(x: 40, y: 400, width: 100, height: 12), glyphHeight: 10)])
        #expect(GeometricCompleteness.violations(in: layout, minimumGlyphHeight: 6) == [.outsidePage(page: 1, text: "Nowhere")])
    }

    @Test("a document with no page or no text line is reported, never passed")
    func empty() {
        #expect(GeometricCompleteness.violations(in: PDFLayout(pages: [], lines: []), minimumGlyphHeight: 6) == [.noPage])
        #expect(GeometricCompleteness.violations(in: PDFLayout(pages: [a4Page], lines: []), minimumGlyphHeight: 6) == [.noText])
    }

    @Test("the text of a violation is reported once per line, in page order")
    func order() {
        let layout = PDFLayout(pages: [a4Page, a4Page], lines: [
            textLine("Second page, tiny", page: 1, PDFBox(x: 40, y: 700, width: 100, height: 4), glyphHeight: 3),
            textLine("First page, below and tiny", page: 0, PDFBox(x: 40, y: -30, width: 100, height: 4), glyphHeight: 3),
            textLine("Second page, past the right edge", page: 1, PDFBox(x: 560, y: 400, width: 100, height: 12), glyphHeight: 10),
            textLine("First page, fine", page: 0, PDFBox(x: 40, y: 400, width: 100, height: 12), glyphHeight: 10),
        ])
        #expect(GeometricCompleteness.violations(in: layout, minimumGlyphHeight: 6) == [
            .outsidePage(page: 0, text: "First page, below and tiny"),
            .glyphTooSmall(page: 1, text: "Second page, tiny"),
            .outsidePage(page: 1, text: "Second page, past the right edge"),
        ])
    }
}

/// An inspector that reads the text and pages of a fake PDF but cannot lay it out.
struct NoLayoutInspector: PDFLayoutInspecting {
    func pageCount(of data: Data) -> Int? { MinimalPDFInspector().pageCount(of: data) }
    func text(of data: Data) -> String? { MinimalPDFInspector().text(of: data) }
    func layout(of data: Data) -> PDFLayout? { nil }
}

/// An inspector that reads the complete text of a fake PDF but lays it out as `layout`, whatever the PDF holds.
struct FixedLayoutInspector: PDFLayoutInspecting {
    let layout: PDFLayout
    func pageCount(of data: Data) -> Int? { MinimalPDFInspector().pageCount(of: data) }
    func text(of data: Data) -> String? { MinimalPDFInspector().text(of: data) }
    func layout(of data: Data) -> PDFLayout? { layout }
}

@Suite("#80 · the install gate checks the geometry")
struct GeometryGateTests {
    func gate(_ renderer: any PDFRendering, _ inspector: any PDFLayoutInspecting) throws -> FixtureRenderingGate {
        FixtureRenderingGate(renderer: renderer, inspector: inspector, fixture: fixture,
                             headings: try headingsCatalog.headings(for: "it"), palette: palette)
    }

    @Test("a design whose fixture text lies outside the page is not stored")
    func outside() async throws {
        let store = InMemoryDesignStore()
        let pastTheRightEdge = FakePDFRenderer(placement: FakePDFRenderer.TextPlacement(fontSize: 10, leading: 12, x: 600, y: 800))
        let error = await #expect(throws: FixtureRenderingGate.Rejection.self) {
            _ = try await InstallDesign(gate: try gate(pastTheRightEdge, MinimalPDFInspector()), store: store)(designData(cleanCSS, id: "clean"))
        }
        guard case .outsidePage(let texts)? = error else { Issue.record("expected outsidePage, got \(String(describing: error))"); return }
        #expect(texts.contains("Mathematics"), "every line of the fixture lies past the right edge")
        #expect(try await store.design(id: "clean") == nil)
    }

    @Test("a design whose fixture text is below the minimum is not stored")
    func tiny() async throws {
        let store = InMemoryDesignStore()
        let threePoints = FakePDFRenderer(placement: FakePDFRenderer.TextPlacement(fontSize: 3, leading: 4, x: 40, y: 800))
        let error = await #expect(throws: FixtureRenderingGate.Rejection.self) {
            _ = try await InstallDesign(gate: try gate(threePoints, MinimalPDFInspector()), store: store)(designData(cleanCSS, id: "clean"))
        }
        guard case .glyphTooSmall(let texts)? = error else { Issue.record("expected glyphTooSmall, got \(String(describing: error))"); return }
        #expect(texts.contains("Mathematics"), "every line of the fixture is 3 pt high")
        #expect(try await store.design(id: "clean") == nil)
    }

    @Test("a PDF the inspector cannot lay out is a rejection")
    func noLayout() async throws {
        let store = InMemoryDesignStore()
        let error = await #expect(throws: FixtureRenderingGate.Rejection.self) {
            _ = try await InstallDesign(gate: try gate(FakePDFRenderer(), NoLayoutInspector()), store: store)(designData(cleanCSS, id: "clean"))
        }
        #expect(error == .unreadablePDF)
        #expect(try await store.design(id: "clean") == nil)
    }

    /// The gate's rejection for a layout the geometry check cannot work with, the text being complete.
    func rejection(of layout: PDFLayout) async throws -> FixtureRenderingGate.Rejection? {
        let store = InMemoryDesignStore()
        let error = await #expect(throws: FixtureRenderingGate.Rejection.self) {
            _ = try await InstallDesign(gate: try gate(FakePDFRenderer(), FixedLayoutInspector(layout: layout)), store: store)(designData(cleanCSS, id: "clean"))
        }
        #expect(try await store.design(id: "clean") == nil)
        return error
    }

    @Test("a layout with no pages is an unreadable PDF and the design is not stored")
    func noPages() async throws {
        #expect(try await rejection(of: PDFLayout(pages: [], lines: [])) == .unreadablePDF)
    }

    @Test("a layout with pages and no text lines is an unreadable PDF and the design is not stored")
    func noLines() async throws {
        #expect(try await rejection(of: PDFLayout(pages: [a4Page], lines: [])) == .unreadablePDF)
    }

    @Test("a line of unknown glyph height is too small, the text being complete, and the design is not stored")
    func unknownGlyphHeight() async throws {
        let line = textLine("Mathematics", page: 0, PDFBox(x: 40, y: 400, width: 100, height: 12), glyphHeight: nil)
        #expect(try await rejection(of: PDFLayout(pages: [a4Page], lines: [line])) == .glyphTooSmall(["Mathematics"]))
    }

    @Test("a design that renders inside the page at a readable size is stored")
    func clean() async throws {
        let store = InMemoryDesignStore()
        _ = try await InstallDesign(gate: try gate(FakePDFRenderer(), MinimalPDFInspector()), store: store)(designData(cleanCSS, id: "clean"))
        #expect(try await store.design(id: "clean") != nil)
    }
}

@Suite("#78 · completeness reports its work")
struct CompletenessReportTests {
    @Test("the step budget is 100 000 steps")
    func budget() {
        #expect(DocumentCompleteness.stepBudget == 100_000)
    }

    @Test("the search reports how many steps it used")
    func steps() {
        let report = DocumentCompleteness.report(in: "Greg\nOfficer\nSkills", expected: ["Greg", "Officer", "Skills"])
        #expect(report == CompletenessReport(missing: [], steps: 3, budgetExhausted: false))
    }

    @Test("a missing value is reported with the steps the search took")
    func missing() {
        let report = DocumentCompleteness.report(in: "Greg\nOfficer\nSkills", expected: ["Greg", "Officer", "Skills", "Go"])
        #expect(report.missing == ["Go"])
        #expect(!report.budgetExhausted)
    }

    @Test("a search that exhausts its budget is incomplete")
    func exhausted() {
        // A complete document whose search needs three steps, given two.
        let report = DocumentCompleteness.report(in: "Greg\nOfficer\nSkills", expected: ["Greg", "Officer", "Skills"], stepBudget: 2)
        #expect(report.budgetExhausted)
        #expect(!report.missing.isEmpty, "a search stopped by its budget must never read as complete")
    }

    @Test("missing(in:expected:) answers what the report at the full budget says")
    func sameAnswer() {
        #expect(DocumentCompleteness.missing(in: "Dev A", expected: ["Dev", "A", "Dev"])
                == DocumentCompleteness.report(in: "Dev A", expected: ["Dev", "A", "Dev"]).missing)
    }
}

@Suite("#80 · MinimalPDFInspector")
struct MinimalLayoutTests {
    @Test("reads the boxes and sizes of the lines FakePDFRenderer wrote")
    func readsTheFake() async throws {
        let lines = (1...41).map { "<p>Line \($0)</p>" }.joined()
        let placement = FakePDFRenderer.TextPlacement(fontSize: 9, leading: 11, x: 50, y: 780)
        let pdf = try await FakePDFRenderer(placement: placement).render(html: lines, page: .a4)
        let layout = try #require(MinimalPDFInspector().layout(of: pdf.data))
        #expect(layout.pages == [a4Page, a4Page])
        #expect(layout.lines.count == 41)
        // A line's box starts at its origin and is as high as its font size; the fake writes no glyph widths.
        #expect(layout.lines.first == textLine("Line 1", page: 0, PDFBox(x: 50, y: 780, width: 0, height: 9), glyphHeight: 9))
        #expect(layout.lines.dropFirst().first == textLine("Line 2", page: 0, PDFBox(x: 50, y: 769, width: 0, height: 9), glyphHeight: 9))
        #expect(layout.lines.last == textLine("Line 41", page: 1, PDFBox(x: 50, y: 780, width: 0, height: 9), glyphHeight: 9))
    }

    @Test("FakePDFRenderer() writes 10 pt lines 12 pt apart from 40, 800")
    func regularPlacement() async throws {
        #expect(FakePDFRenderer.TextPlacement.regular == FakePDFRenderer.TextPlacement(fontSize: 10, leading: 12, x: 40, y: 800))
        let pdf = try await FakePDFRenderer().render(html: "<p>One</p><p>Two</p>", page: .a4)
        let layout = try #require(MinimalPDFInspector().layout(of: pdf.data))
        #expect(layout.lines == [textLine("One", page: 0, PDFBox(x: 40, y: 800, width: 0, height: 10), glyphHeight: 10),
                                 textLine("Two", page: 0, PDFBox(x: 40, y: 788, width: 0, height: 10), glyphHeight: 10)])
    }

    @Test("reads lines placed at negative and fractional positions")
    func negative() async throws {
        let placement = FakePDFRenderer.TextPlacement(fontSize: 2.5, leading: 3.5, x: -20.25, y: -4)
        let pdf = try await FakePDFRenderer(placement: placement).render(html: "<p>Below</p>", page: .a4)
        let layout = try #require(MinimalPDFInspector().layout(of: pdf.data))
        #expect(layout.lines == [textLine("Below", page: 0, PDFBox(x: -20.25, y: -4, width: 0, height: 2.5), glyphHeight: 2.5)])
    }

    @Test("reads each page's own media box")
    func mediaBox() async throws {
        let pdf = try await FakePDFRenderer().render(html: "<p>One</p>", page: .a4)
        let other = String(decoding: pdf.data, as: UTF8.self)
            .replacingOccurrences(of: "/MediaBox [0 0 595 842]", with: "/MediaBox [10 -20 300.5 400]")
        let layout = try #require(MinimalPDFInspector().layout(of: Data(other.utf8)))
        #expect(layout.pages == [PDFBox(x: 10, y: -20, width: 290.5, height: 420)])
    }

    @Test("what is not a PDF has no layout")
    func notAPDF() {
        #expect(MinimalPDFInspector().layout(of: Data("not a PDF".utf8)) == nil)
    }
}
