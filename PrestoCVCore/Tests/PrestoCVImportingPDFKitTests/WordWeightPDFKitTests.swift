#if canImport(PDFKit)
import CoreText
import Foundation
import PDFKit
import Testing
import PrestoCVImporting
import PrestoCVImportingPDFKit

/// Whether a word is bold is the one thing of its style that a heading needs and that PDFKit cannot always tell: it
/// names the fonts of a PDF from their embedded names, and gives back Times, with no weight, for a font it cannot
/// find (#287). The reader measures the strokes of the page as it is drawn, so the words of a PDF are as bold as they
/// look. Every PDF here is drawn when the test runs, from invented text.
@Suite("Reading the weight of the words of a PDF with PDFKit")
struct WordWeightPDFKitTests {

    /// A line of the page.
    private struct Line {
        let text: String
        var size: CGFloat = 10
        var bold = false
        var face: DrawnFace = .helvetica
        var x: CGFloat = 40
    }

    private static let paragraph = [
        "Built the billing service for retail customers",
        "Moved the checkout to a new payment provider",
        "Taught two colleagues how to review code",
        "Wrote the runbook for the night shift",
        "Reduced the time of a release to ten minutes",
    ]

    private func drawnPDF(_ lines: [Line]) throws -> Data {
        let data = NSMutableData()
        var box = CGRect(x: 0, y: 0, width: 595, height: 842)
        let consumer = try #require(CGDataConsumer(data: data as CFMutableData))
        let context = try #require(CGContext(consumer: consumer, mediaBox: &box, nil))
        context.beginPDFPage(nil)
        var top = CGFloat(40)
        for line in lines {
            top += line.size * 1.5
            context.textPosition = CGPoint(x: line.x, y: box.height - top)
            let drawn = NSAttributedString(string: line.text, attributes: [.font: line.face.font(line.size, bold: line.bold)])
            CTLineDraw(CTLineCreateWithAttributedString(drawn), context)
        }
        context.endPDFPage()
        context.closePDF()
        return data as Data
    }

    private func words(of data: Data) async throws -> [ExtractedWord] {
        guard case .pages(let pages) = try await PDFKitTextExtractor().layout(ofPDF: data, limits: .standard) else { return [] }
        return pages.flatMap(\.words)
    }

    private func body(_ face: DrawnFace) -> [Line] {
        Self.paragraph.map { Line(text: $0, face: face) }
    }

    @Test("A bold heading is bold, and the regular text under it is not, in any font", arguments: DrawnFace.allCases)
    func headingAgainstBody(face: DrawnFace) async throws {
        let page = try drawnPDF([Line(text: "Work Experience", size: 12, bold: true, face: face)] + body(face))
        let read = try await words(of: page)
        let heading = read.filter { ["Work", "Experience"].contains($0.text) }
        try #require(heading.count == 2)
        #expect(heading.allSatisfy { $0.isBold }, "\(face.testDescription): \(heading.map { $0.isBold })")
        let text = read.filter { !["Work", "Experience"].contains($0.text) }
        #expect(text.count > 20)
        #expect(!text.contains { $0.isBold }, "\(face.testDescription): bold words in the text: \(text.filter { $0.isBold }.map { $0.text })")
    }

    @Test("A bold label above regular lines is bold alone, at any size", arguments: DrawnFace.allCases, [8.0, 10.0, 14.0, 22.0])
    func labelAboveText(face: DrawnFace, size: Double) async throws {
        let lines = [Line(text: "Languages", size: size, bold: true, face: face)] + Self.paragraph.map { Line(text: $0, size: size, face: face) }
        let read = try await words(of: drawnPDF(lines))
        let bold = read.filter(\.isBold).map(\.text)
        #expect(bold == ["Languages"], "\(face.testDescription) at \(size): \(bold)")
    }

    @Test("A page with no bold word has none, whatever the families of its fonts: thin serifs, wide sans, a larger size")
    func noBoldWord() async throws {
        let lines = [
            Line(text: "Alex Example", size: 22, face: .helvetica),
            Line(text: "Software Engineer", size: 12, face: .system),
        ]
        let serif = Self.paragraph.map { Line(text: $0, face: .times) }
        let sans = Self.paragraph.map { Line(text: $0, face: .system) }
        let read = try await words(of: drawnPDF(lines + serif + sans))
        #expect(read.count > 40)
        #expect(!read.contains { $0.isBold }, "bold words: \(read.filter { $0.isBold }.map { $0.text })")
    }

    @Test("A page of a few words keeps the weight its fonts give")
    func fewWords() async throws {
        let page = try drawnPDF([Line(text: "Skills", bold: true), Line(text: "Swift Kotlin")])
        let read = try await words(of: page)
        #expect(read.first { $0.text == "Skills" }?.isBold == true)
        #expect(read.first { $0.text == "Swift" }?.isBold == false)
    }
}
#endif
