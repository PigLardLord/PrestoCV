#if canImport(PDFKit)   // Apple platforms only (R11)
import Testing
import Foundation
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

    /// A one-page A4 PDF whose page content `page` draws the form XObject `/Fm0`, which shows `form` in Helvetica
    /// (`/F1`) through its own `matrix`. Written by hand: Core Graphics copies a drawn page's content into the new page
    /// rather than keeping it as a form.
    static func pageShowingAForm(_ form: String, matrix: String, drawnWith page: String) -> Data {
        let objects = [
            "<< /Type /Catalog /Pages 2 0 R >>",
            "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
            "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /XObject << /Fm0 4 0 R >> >> /Contents 5 0 R >>",
            "<< /Type /XObject /Subtype /Form /BBox [0 0 595 842] /Matrix [\(matrix)] /Resources << /Font << /F1 6 0 R >> >> "
                + "/Length \(form.utf8.count) >>\nstream\n\(form)\nendstream",
            "<< /Length \(page.utf8.count) >>\nstream\n\(page)\nendstream",
            "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>",
        ]
        var pdf = "%PDF-1.4\n"
        var offsets: [Int] = []
        for (index, object) in objects.enumerated() {
            offsets.append(pdf.utf8.count)
            pdf += "\(index + 1) 0 obj\n\(object)\nendobj\n"
        }
        let table = pdf.utf8.count
        pdf += "xref\n0 \(objects.count + 1)\n0000000000 65535 f \n"
        for offset in offsets { pdf += String(format: "%010d 00000 n \n", offset) }
        pdf += "trailer\n<< /Size \(objects.count + 1) /Root 1 0 R >>\nstartxref\n\(table)\n%%EOF\n"
        return Data(pdf.utf8)
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

    @Test("no box, no size")
    func noBox() {
        #expect(PDFKitInspector.smallestSizes(of: [ShownText(x: 100, y: 700, size: 12)], in: []).isEmpty)
        #expect(PDFKitInspector.smallestSizes(of: [], in: [Self.upper]) == [nil])
    }
}
#endif
