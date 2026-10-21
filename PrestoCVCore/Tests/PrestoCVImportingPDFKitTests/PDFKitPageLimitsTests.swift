#if canImport(PDFKit)
import CoreText
import Foundation
import PDFKit
import Testing
import PrestoCVImporting
import PrestoCVImportingPDFKit

/// A PDF's page is untrusted input (R8): a few kilobytes of compressed stream can hold a million characters. The reader
/// refuses a page by the length of its text before it reads the glyphs, counts the words as it reads them, and stops
/// in the middle of a page once its task is cancelled.
@Suite("Reading a hostile PDF page with PDFKit")
struct PDFKitPageLimitsTests {

    /// A one-page PDF drawn when the test runs: `rows` lines of `line`, in Helvetica of `size` points.
    private func drawnPDF(rows: Int, line: String, size: CGFloat, width: CGFloat) throws -> Data {
        let data = NSMutableData()
        var box = CGRect(x: 0, y: 0, width: width, height: CGFloat(rows + 2) * size * 1.2)
        let consumer = try #require(CGDataConsumer(data: data as CFMutableData))
        let context = try #require(CGContext(consumer: consumer, mediaBox: &box, nil))
        context.beginPDFPage(nil)
        let font = CTFontCreateWithName("Helvetica" as CFString, size, nil)
        let drawn = CTLineCreateWithAttributedString(NSAttributedString(string: line, attributes: [.font: font]))
        for row in 0..<rows {
            context.textPosition = CGPoint(x: 2, y: box.height - CGFloat(row + 1) * size * 1.2)
            CTLineDraw(drawn, context)
        }
        context.endPDFPage()
        context.closePDF()
        return data as Data
    }

    private func limits(characters: Int, words: Int) -> ImportLimits {
        ImportLimits(
            maximumPDFBytes: 20_000_000, maximumPages: 10, maximumCharacters: characters,
            maximumWords: words, maximumLines: 2_000, maximumCells: 4_000, maximumAnalysisSteps: 10_000_000
        )
    }

    /// Reads `data` in a task that is cancelled while it reads: well after the reading starts, long before it ends.
    private func readCancelled(_ data: Data, limits: ImportLimits) async throws -> Result<ExtractedLayout, any Error> {
        let reading = Task { try await PDFKitTextExtractor().layout(ofPDF: data, limits: limits) }
        try await Task.sleep(for: .milliseconds(300))
        reading.cancel()
        return await reading.result
    }

    @Test("A page whose text is over the characters left is refused by its length, before its glyphs are read")
    func oversizedPage() async throws {
        // Ten lines of 200 words of four letters: 8,000 letters, and some 10,000 characters with the spaces
        let page = try drawnPDF(rows: 10, line: String(repeating: "abcd ", count: 200), size: 4, width: 2_400)
        await #expect(throws: ImportError.tooLarge) {
            try await PDFKitTextExtractor().layout(ofPDF: page, limits: limits(characters: 9_000, words: 20_000))
        }
        // A million characters in less than 200 kilobytes
        let million = try drawnPDF(rows: 1_000, line: String(repeating: "abcdefghi ", count: 100), size: 4, width: 2_400)
        #expect(million.count < 200_000)
        await #expect(throws: ImportError.tooLarge) { try await PDFKitTextExtractor().layout(ofPDF: million, limits: .standard) }
    }

    @Test("The words are counted as they are read: a page with more words than are left is refused")
    func wordsCountedWhileRead() async throws {
        let page = try drawnPDF(rows: 10, line: String(repeating: "abcd ", count: 200), size: 4, width: 2_400)
        await #expect(throws: ImportError.tooLarge) {
            try await PDFKitTextExtractor().layout(ofPDF: page, limits: limits(characters: 100_000, words: 1_000))
        }
    }

    @Test("One huge word over the characters left is refused; within them, its reading stops in its middle when cancelled")
    func hugeWord() async throws {
        let word = try drawnPDF(rows: 1, line: String(repeating: "a", count: 500_000), size: 0.05, width: 14_400)
        await #expect(throws: ImportError.tooLarge) { try await PDFKitTextExtractor().layout(ofPDF: word, limits: .standard) }

        let read = try await readCancelled(word, limits: limits(characters: 1_000_000, words: 20_000))
        #expect(throws: CancellationError.self) { try read.get() }
    }

    @Test("A page's reading stops in its middle once its task is cancelled")
    func cancelledInThePage() async throws {
        let million = try drawnPDF(rows: 1_000, line: String(repeating: "abcdefghi ", count: 100), size: 4, width: 2_400)
        let read = try await readCancelled(million, limits: limits(characters: 2_000_000, words: 200_000))
        #expect(throws: CancellationError.self) { try read.get() }
    }
}
#endif
