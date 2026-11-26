#if canImport(PDFKit)   // Apple platforms only (R11)
import Testing
import Foundation
import CoreGraphics
import CVRendering
import CVRenderingNativeTestSupport
@testable import CVRenderingPDFKitInspector

/// #562: the inspector sizes a line from the text operators of the page's content, not from the fonts PDFKit resolves
/// for its characters (slow and verbose for the system font). On the drawn PDFs it gives every line the size PDFKit's
/// fonts give, without asking PDFKit for them, forms included.
@Suite("#562 · glyph heights read from the page's content")
struct ShownTextTests {
    typealias Line = DrawnPDF.Line

    static let known = [
        PDFKitLayoutTests.line("Twelve point text", size: 12, x: 100, y: 700),
        PDFKitLayoutTests.line("Three point", size: 3, x: 100, y: 600),
        PDFKitLayoutTests.line("Twelve scaled to three", size: 12, x: 100, y: 500, scale: 0.25),
        PDFKitLayoutTests.line("Three scaled to twelve", size: 3, x: 100, y: 400, scale: 4),
        PDFKitLayoutTests.line("Six point text", size: 6, x: 100, y: 300),
    ]

    /// The drawn PDFs of the layout tests, each by what it shows.
    static func drawn() -> [(name: String, data: Data)] {
        let cropped = DrawnPDF.pages([[
            PDFKitLayoutTests.line("Inside the crop box", size: 12, x: 100, y: 300),
            PDFKitLayoutTests.line("Straddling the crop box edge", size: 12, x: 100, y: 497),
        ]], cropBox: CGRect(x: 50, y: 100, width: 300, height: 400))
        return [
            ("known positions", DrawnPDF.pages([known])),
            ("text past the edges", DrawnPDF.pages([PDFKitLayoutTests.outside])),
            ("a crop box", cropped),
            ("a rotated page", DrawnPDF.rotated(DrawnPDF.pages([known]), by: 90)),
            ("two pages", DrawnPDF.pages([known, PDFKitLayoutTests.outside])),
        ]
    }

    @Test("every line of the drawn PDFs is sized from the content, as PDFKit's fonts size it")
    func drawnPDFs() throws {
        for (name, data) in Self.drawn() {
            let reading = try #require(PDFKitInspector().reading(of: data), "\(name)")
            let expected = try #require(PDFKitFonts.lines(of: data), "\(name)")
            #expect(reading.linesSizedByAttributedText == 0, "\(name): \(reading.linesSizedByAttributedText) lines sized by PDFKit's fonts")
            #expect(reading.layout.lines.map(\.text) == expected.map(\.text), "\(name)")
            #expect(reading.layout.lines.map(\.pageIndex) == expected.map(\.page), "\(name)")
            for (line, oracle) in zip(reading.layout.lines, expected) {
                let height = try #require(line.glyphHeight, "\(name): \(line.text) has no height")
                let size = try #require(oracle.height, "\(name): PDFKit gives \(line.text) no font")
                #expect(abs(height - size) < 0.001, "\(name): \(line.text) is \(height), PDFKit's fonts give \(size)")
            }
        }
    }

    /// A one-page A4 PDF written by hand, for content the drawn PDFs do not hold: the catalog and the page tree, then
    /// `objects` from object 3 on, the page first.
    static func handWritten(_ objects: [String]) -> Data {
        let all = ["<< /Type /Catalog /Pages 2 0 R >>", "<< /Type /Pages /Kids [3 0 R] /Count 1 >>"] + objects
        var pdf = "%PDF-1.4\n"
        var offsets: [Int] = []
        for (index, object) in all.enumerated() {
            offsets.append(pdf.utf8.count)
            pdf += "\(index + 1) 0 obj\n\(object)\nendobj\n"
        }
        let table = pdf.utf8.count
        pdf += "xref\n0 \(all.count + 1)\n0000000000 65535 f \n"
        for offset in offsets { pdf += String(format: "%010d 00000 n \n", offset) }
        pdf += "trailer\n<< /Size \(all.count + 1) /Root 1 0 R >>\nstartxref\n\(table)\n%%EOF\n"
        return Data(pdf.utf8)
    }

    /// A stream object holding `content`, its dictionary's other entries `dictionary`.
    static func stream(_ content: String, _ dictionary: String = "") -> String {
        "<< \(dictionary)/Length \(content.utf8.count) >>\nstream\n\(content)\nendstream"
    }

    static let helvetica = "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>"

    /// A one-page A4 PDF whose page content `page` draws the form XObject `/Fm0`, which shows `form` in Helvetica
    /// (`/F1`) through its own `matrix`. Written by hand: Core Graphics copies a drawn page's content into the new page
    /// rather than keeping it as a form.
    static func pageShowingAForm(_ form: String, matrix: String, drawnWith page: String) -> Data {
        handWritten([
            "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /XObject << /Fm0 4 0 R >> >> /Contents 5 0 R >>",
            stream(form, "/Type /XObject /Subtype /Form /BBox [0 0 595 842] /Matrix [\(matrix)] /Resources << /Font << /F1 6 0 R >> >> "),
            stream(page),
            helvetica,
        ])
    }

    /// A one-page A4 PDF whose content is `content`, with the fonts `/F1` (Helvetica), `/F2` (a Type 0 font whose
    /// predefined CMap writes vertically), `/F3` (a Type 0 font whose embedded CMap writes vertically) and `/F4` (a
    /// Type 0 font that writes across), and Type 0 fonts whose embedded CMap writes vertically by its program only
    /// (`/F5`), is built on a predefined vertical CMap (`/F6`) or on an embedded one (`/F7`), or writes across (`/F8`).
    static func pageShowing(_ content: String) -> Data {
        let cid = "/CIDSystemInfo << /Registry (Adobe) /Ordering (Identity) /Supplement 0 >>"
        let cmap = "/CIDInit /ProcSet findresource begin 12 dict begin begincmap /CMapName /Custom def /WMode 1 def "
            + "1 begincodespacerange <0000> <FFFF> endcodespacerange 1 begincidrange <0000> <FFFF> 0 endcidrange "
            + "endcmap CMapName currentdict /CMap defineresource pop end end"
        let across = "/CIDInit /ProcSet findresource begin 12 dict begin begincmap /CMapName /Across def /WMode 0 def "
            + "1 begincodespacerange <0000> <FFFF> endcodespacerange 1 begincidrange <0000> <FFFF> 0 endcidrange "
            + "endcmap CMapName currentdict /CMap defineresource pop end end"
        let font = { (cmap: Int) in "<< /Type /Font /Subtype /Type0 /BaseFont /Mincho /Encoding \(cmap) 0 R /DescendantFonts [7 0 R] >>" }
        return handWritten([
            "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 5 0 R /F2 6 0 R /F3 9 0 R "
                + "/F4 11 0 R /F5 12 0 R /F6 14 0 R /F7 16 0 R /F8 18 0 R >> >> /Contents 4 0 R >>",
            stream(content),
            helvetica,
            "<< /Type /Font /Subtype /Type0 /BaseFont /Mincho /Encoding /Identity-V /DescendantFonts [7 0 R] >>",
            "<< /Type /Font /Subtype /CIDFontType0 /BaseFont /Mincho \(cid) /FontDescriptor 8 0 R >>",
            "<< /Type /FontDescriptor /FontName /Mincho /Flags 4 /FontBBox [0 -120 1000 880] /ItalicAngle 0 /Ascent 880 "
                + "/Descent -120 /CapHeight 700 /StemV 80 >>",
            "<< /Type /Font /Subtype /Type0 /BaseFont /Mincho /Encoding 10 0 R /DescendantFonts [7 0 R] >>",
            stream(cmap, "/Type /CMap /CMapName /Custom \(cid) /WMode 1 "),
            "<< /Type /Font /Subtype /Type0 /BaseFont /Mincho /Encoding /Identity-H /DescendantFonts [7 0 R] >>",
            font(13), stream(cmap, "/Type /CMap /CMapName /Custom \(cid) "),
            font(15), stream(across, "/Type /CMap /CMapName /Across \(cid) /UseCMap /UniJIS-UCS2-V "),
            font(17), stream(across, "/Type /CMap /CMapName /Across \(cid) /UseCMap 13 0 R "),
            font(19), stream(across, "/Type /CMap /CMapName /Across \(cid) "),
        ])
    }

    /// The runs the scan finds on the first page of `data`.
    static func runs(of data: Data) throws -> [ShownText] {
        let provider = try #require(CGDataProvider(data: data as CFData))
        let page = try #require(CGPDFDocument(provider)?.page(at: 1))
        return ShownTextScanner.reading(of: page).runs
    }

    @Test("text a page shows through a form is sized through the form's matrix and the page's transform")
    func form() throws {
        // The form doubles and the page quarters: the text is shown at half its size, where PDFKit's fonts put it.
        let data = Self.pageShowingAForm("BT /F1 12 Tf 100 700 Td (Twelve point text) Tj ET BT /F1 6 Tf 100 300 Td (Six point text) Tj ET",
                                         matrix: "2 0 0 2 0 0", drawnWith: "q 0.25 0 0 0.25 20 30 cm /Fm0 Do Q")
        let reading = try #require(PDFKitInspector().reading(of: data))
        #expect(reading.formsRead == 1, "the page's content drew no form")
        #expect(reading.linesSizedByAttributedText == 0)
        #expect(reading.layout.lines.map(\.text) == ["Twelve point text", "Six point text"])
        #expect(reading.layout.lines.map(\.glyphHeight) == [6, 3], "\(reading.layout.lines)")
        #expect(PDFKitFonts.lines(of: data)?.map(\.height) == [6, 3])
    }

    // MARK: Where a run starts

    @Test("text shown right after other text starts somewhere on the text line, the first run where the position was set")
    func showAfterShow() throws {
        let runs = try Self.runs(of: Self.pageShowing("BT /F1 12 Tf 100 700 Td (First) Tj /F1 3 Tf (Second) Tj [-60000 (Right)] TJ ET"))
        #expect(runs == [ShownText(start: .at(x: 100, y: 700), size: 12),
                         ShownText(start: .onTheLine(x: 100, y: 700, dx: 1, dy: 0), size: 3),
                         ShownText(start: .onTheLine(x: 100, y: 700, dx: 1, dy: 0), size: 3)])
    }

    @Test("a TJ that shows no glyph moves the position along the text line by its adjustments, scaled as the text is")
    func moveOnly() throws {
        #expect(try Self.runs(of: Self.pageShowing("BT /F1 10 Tf 100 600 Td [-1000] TJ (Moved) Tj ET"))
                == [ShownText(start: .at(x: 110, y: 600), size: 10)])
        #expect(try Self.runs(of: Self.pageShowing("BT /F1 10 Tf 50 Tz 100 600 Td [-500 -500] TJ [-1000 (Moved)] TJ ET"))
                == [ShownText(start: .at(x: 110, y: 600), size: 10)], "the moves add up, at half the horizontal scale")
    }

    @Test("every operator that sets the text position makes the next run's start known again")
    func positioning() throws {
        let content = "BT /F1 12 Tf 14 TL 100 700 Td (a) Tj (b) Tj 0 -14 Td (c) Tj (d) Tj T* (e) Tj (f) Tj (g) ' (h) Tj "
            + "1 0 (i) \" (j) Tj 0 -14 TD (k) Tj (l) Tj 1 0 0 1 300 500 Tm (m) Tj ET BT (n) Tj ET"
        let starts = try Self.runs(of: Self.pageShowing(content)).map(\.start)
        let after = { (y: Double) in ShownText.Start.onTheLine(x: 100, y: y, dx: 1, dy: 0) }
        #expect(starts == [.at(x: 100, y: 700), after(700), .at(x: 100, y: 686), after(686), .at(x: 100, y: 672), after(672),
                           .at(x: 100, y: 658), after(658), .at(x: 100, y: 644), after(644), .at(x: 100, y: 630), after(630),
                           .at(x: 300, y: 500), .at(x: 0, y: 0)])
    }

    @Test("text in a font that may write vertically, or after it with no positioning between them, may start anywhere")
    func vertical() throws {
        let runs = try Self.runs(of: Self.pageShowing("BT /F2 12 Tf 100 700 Td <0001> Tj /F1 12 Tf (a) Tj 0 -20 Td (b) Tj ET "
            + "BT /F3 9 Tf 100 600 Td <0001> Tj ET BT /F9 9 Tf 100 500 Td (c) Tj ET BT /F1 9 Tf 100 400 Td (d) Tj ET "
            + "BT /F4 9 Tf 100 300 Td <0001> Tj (e) Tj ET BT /F2 9 Tf 100 200 Td [-500] TJ /F1 9 Tf (f) Tj ET"))
        #expect(runs == [ShownText(start: .anywhere, size: 12), ShownText(start: .anywhere, size: 12),
                         ShownText(start: .at(x: 100, y: 680), size: 12),
                         ShownText(start: .anywhere, size: 9), ShownText(start: .anywhere, size: nil),
                         ShownText(start: .at(x: 100, y: 400), size: 9),
                         ShownText(start: .at(x: 100, y: 300), size: 9), ShownText(start: .onTheLine(x: 100, y: 300, dx: 1, dy: 0), size: 9),
                         ShownText(start: .anywhere, size: 9)],
                "a predefined vertical CMap, an embedded one, a missing font, then a font that writes across, and a move in a vertical font")
    }

    @Test("an embedded CMap may write vertically by its program or by the CMap it is built on, whatever its dictionary says")
    func embeddedCMaps() throws {
        let runs = try Self.runs(of: Self.pageShowing("BT /F5 9 Tf 100 700 Td <0001> Tj ET BT /F6 9 Tf 100 600 Td <0001> Tj ET "
            + "BT /F7 9 Tf 100 500 Td <0001> Tj ET BT /F8 9 Tf 100 400 Td <0001> Tj (a) Tj ET BT /F5 9 Tf 100 300 Td <0001> Tj ET"))
        #expect(runs == [ShownText(start: .anywhere, size: 9), ShownText(start: .anywhere, size: 9), ShownText(start: .anywhere, size: 9),
                         ShownText(start: .at(x: 100, y: 400), size: 9), ShownText(start: .onTheLine(x: 100, y: 400, dx: 1, dy: 0), size: 9),
                         ShownText(start: .anywhere, size: 9)],
                "writing mode 1 in the program only, a base named -V, an embedded vertical base, a CMap that writes across, and the first again")
    }

    @Test("a CMap program may write vertically when a /WMode it holds is followed by anything but 0, or it uses a CMap named -V")
    func cmapPrograms() {
        let vertical = ["/WMode 1 def", "/WMode\n1 def", "<</WMode 1>>", "/WMode 0.0 def", "/WMode", "/WMode 0 def /WMode 1 def",
                        "/UniJIS-UCS2-V usecmap", "% a comment: /WMode 1"]
        let across = ["/WMode 0 def", "<</WMode 0>>", "/UniJIS-UCS2-H usecmap", "/CMapName /Custom-V def", "/WMode0 1", ""]
        for program in vertical { #expect(CMapProgram(Data(program.utf8)).mayWriteVertically, "\(program)") }
        for program in across { #expect(!CMapProgram(Data(program.utf8)).mayWriteVertically, "\(program)") }
    }

    @Test("lines on the text line of text shown after other text are sized by PDFKit's fonts, the others from the content")
    func linesAfterAShow() throws {
        let data = Self.pageShowing("BT /F1 12 Tf 100 700 Td (First) Tj /F1 3 Tf (Second) Tj /F1 12 Tf [-30000 (Far right)] TJ ET "
            + "BT /F1 6 Tf 100 600 Td (Six point text) Tj ET")
        let reading = try #require(PDFKitInspector().reading(of: data))
        let expected = try #require(PDFKitFonts.lines(of: data))
        let onTheLine = reading.layout.lines.filter { $0.box.y - 1 <= 700 && 700 <= $0.box.maxY + 1 }
        #expect(!onTheLine.isEmpty, "\(reading.layout.lines)")
        #expect(reading.linesSizedByAttributedText == onTheLine.count, "\(reading.layout.lines)")
        #expect(reading.layout.lines.map(\.text) == expected.map(\.text))
        for (line, oracle) in zip(reading.layout.lines, expected) {
            let height = try #require(line.glyphHeight, "\(line.text) has no height")
            let size = try #require(oracle.height, "PDFKit gives \(line.text) no font")
            #expect(abs(height - size) < 0.001, "\(line.text) is \(height), PDFKit's fonts give \(size)")
        }
        #expect(reading.layout.lines.first { $0.text == "Six point text" }?.glyphHeight == 6)
    }

    // MARK: Runs and boxes

    static let upper = CGRect(x: 100, y: 697, width: 90, height: 12)
    static let lower = CGRect(x: 100, y: 597, width: 90, height: 12)

    @Test("a box takes the smallest size of the runs that start in it, and a box with none takes none")
    func smallest() {
        let runs = [ShownText(x: 100, y: 700, size: 12), ShownText(x: 150, y: 700, size: 9)]
        #expect(PDFKitInspector.smallestSizes(of: runs, in: [Self.upper, Self.lower]) == [9, nil])
    }

    @Test("a box holding a run of unknown size has none, whatever the other runs in it")
    func unknownSize() {
        let runs = [ShownText(x: 100, y: 600, size: 12), ShownText(x: 120, y: 600, size: nil), ShownText(x: 100, y: 700, size: 12)]
        #expect(PDFKitInspector.smallestSizes(of: runs, in: [Self.upper, Self.lower]) == [12, nil])
    }

    @Test("a run that starts more than an em beside every box, or above or below them all, sizes none")
    func besideEveryBox() {
        let runs = [ShownText(x: 100, y: 700, size: 12), ShownText(x: 210, y: 700, size: 3), ShownText(x: 130, y: 650, size: 3),
                    ShownText(x: 86, y: 600, size: 3)]
        #expect(PDFKitInspector.smallestSizes(of: runs, in: [Self.upper, Self.lower]) == [12, nil])
        #expect(PDFKitInspector.smallestSizes(of: [ShownText(x: 196, y: 700, size: 8)], in: [Self.upper]) == [8],
                "a run that starts within an em past the box's end is in it")
    }

    @Test("of two boxes a run lies in, the one whose bottom edge is nearest its baseline holds it")
    func nearestBottomEdge() {
        let tall = CGRect(x: 100, y: 690, width: 90, height: 20)
        #expect(PDFKitInspector.smallestSizes(of: [ShownText(x: 100, y: 700, size: 10)], in: [tall, Self.upper]) == [nil, 10])
        #expect(PDFKitInspector.smallestSizes(of: [ShownText(x: 100, y: 691, size: 10)], in: [tall, Self.upper]) == [10, nil])
    }

    @Test("a run known only to start on a text line leaves every box the line meets, with the same slack, to PDFKit's fonts")
    func onTheLine() {
        let far = CGRect(x: 300, y: 597, width: 90, height: 12)
        let across = ShownText(start: .onTheLine(x: 100, y: 700, dx: 1, dy: 0), size: 3)
        #expect(PDFKitInspector.smallestSizes(of: [ShownText(x: 100, y: 700, size: 12), across, ShownText(x: 100, y: 600, size: 9)],
                                              in: [Self.upper, Self.lower]) == [nil, 9])
        let slanted = ShownText(start: .onTheLine(x: 100, y: 700, dx: 1, dy: -1), size: 3)
        #expect(PDFKitInspector.smallestSizes(of: [ShownText(x: 100, y: 700, size: 12), ShownText(x: 100, y: 600, size: 9),
                                                   ShownText(x: 300, y: 600, size: 9), slanted],
                                              in: [Self.upper, Self.lower, far]) == [nil, nil, 9], "a line down to the right")
        let sized = ShownText(x: 100, y: 600, size: 9)
        #expect(PDFKitInspector.smallestSizes(of: [sized, ShownText(start: .onTheLine(x: 500, y: 610, dx: 1, dy: 0), size: 3)],
                                              in: [Self.lower]) == [nil], "a point of slack above the box")
        #expect(PDFKitInspector.smallestSizes(of: [sized, ShownText(start: .onTheLine(x: 500, y: 611.5, dx: 1, dy: 0), size: 3)],
                                              in: [Self.lower]) == [9], "more than a point above the box")
        #expect(PDFKitInspector.smallestSizes(of: [sized, ShownText(start: .onTheLine(x: 0, y: 0, dx: 0, dy: 0), size: 3)],
                                              in: [Self.lower]) == [nil], "a line with no direction")
    }

    @Test("a run that may start anywhere leaves every box to PDFKit's fonts")
    func anywhere() {
        let runs = [ShownText(x: 100, y: 700, size: 12), ShownText(x: 100, y: 600, size: 9), ShownText(start: .anywhere, size: 3)]
        #expect(PDFKitInspector.smallestSizes(of: runs, in: [Self.upper, Self.lower]) == [nil, nil])
        #expect(PDFKitInspector.smallestSizes(of: [ShownText(start: .anywhere, size: nil)], in: []).isEmpty)
    }

    @Test("no box, no size")
    func noBox() {
        #expect(PDFKitInspector.smallestSizes(of: [ShownText(x: 100, y: 700, size: 12)], in: []).isEmpty)
        #expect(PDFKitInspector.smallestSizes(of: [], in: [Self.upper]) == [nil])
    }
}

private extension ShownText {
    /// A run whose start is known exactly.
    init(x: Double, y: Double, size: Double?) { self.init(start: .at(x: x, y: y), size: size) }
}
#endif
