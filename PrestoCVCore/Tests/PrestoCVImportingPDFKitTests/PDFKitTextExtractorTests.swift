#if canImport(PDFKit)
import Foundation
import PDFKit
import Testing
import PrestoCVImporting
import PrestoCVImportingPDFKit

/// The PDFKit reader's contract (ADR 0027): it reads from the fixture PDFs the words, boxes and styles that the Linux
/// tests read from the recorded layouts, so a PDF imports through PDFKit as its recorded layout does.
@Suite("Reading PDFs with PDFKit")
struct PDFKitTextExtractorTests {

    private struct Entry: Decodable {
        let id: String
        let source: String
        let pdf: String?
    }

    private struct Layout: Decodable {
        struct Page: Decodable { let width: Double; let height: Double; let words: [Word] }
        struct Word: Decodable { let t: String; let x: Double; let y: Double; let w: Double; let h: Double; let s: Double; let b: Bool }
        let pages: [Page]
    }

    /// A reader that hands over a recorded layout.
    private struct Recorded: PDFTextExtracting {
        let layout: ExtractedLayout
        func layout(ofPDF data: Data, limits: ImportLimits) async throws -> ExtractedLayout { layout }
    }

    private func directory() throws -> URL {
        try #require(Bundle.module.url(forResource: "ImportFixtures", withExtension: nil))
    }

    private func pdfEntries() throws -> [Entry] {
        let entries = try JSONDecoder().decode([Entry].self, from: Data(contentsOf: directory().appendingPathComponent("index.json")))
        return entries.filter { $0.pdf != nil }
    }

    private func recorded(_ entry: Entry) throws -> [ExtractedPage] {
        let layout = try JSONDecoder().decode(Layout.self, from: Data(contentsOf: directory().appendingPathComponent(entry.source)))
        return layout.pages.map { page in
            ExtractedPage(width: page.width, height: page.height, words: page.words.map {
                ExtractedWord(text: $0.t, frame: Rect(x: $0.x, y: $0.y, width: $0.w, height: $0.h), fontSize: $0.s, isBold: $0.b)
            })
        }
    }

    private func pdf(_ path: String) throws -> Data {
        try Data(contentsOf: directory().appendingPathComponent(path))
    }

    @Test("PDFKit reads every word of the fixture PDFs, with its box, size and weight, where the recording has it")
    func words() async throws {
        for entry in try pdfEntries() {
            let expected = try recorded(entry)
            guard case .pages(let pages) = try await PDFKitTextExtractor().layout(ofPDF: pdf(try #require(entry.pdf)), limits: .standard) else {
                Issue.record("\(entry.id): no pages")
                continue
            }
            try #require(pages.count == expected.count, "\(entry.id): \(pages.count) pages read, \(expected.count) recorded")
            for (page, want) in zip(pages, expected) {
                #expect(abs(page.width - want.width) < 1 && abs(page.height - want.height) < 1, "\(entry.id): page size")
                var unmatched = page.words
                for word in want.words {
                    guard let index = unmatched.firstIndex(where: {
                        $0.text == word.text && abs($0.frame.x - word.frame.x) < 1 + 0.1 * word.fontSize
                            && abs($0.frame.midY - word.frame.midY) < 0.25 * word.fontSize + 1
                    }) else {
                        Issue.record("\(entry.id): \"\(word.text)\" at \(Int(word.frame.x)), \(Int(word.frame.y)) not read")
                        continue
                    }
                    let found = unmatched.remove(at: index)
                    // PDFKit's boxes are the glyphs' ink, the recording's their advance: they differ by the side bearings
                    #expect(abs(found.frame.width - word.frame.width) < 1 + 0.35 * word.fontSize, "\(entry.id): width of \(word.text)")
                    #expect(abs(found.fontSize - word.fontSize) < 0.5, "\(entry.id): size of \(word.text)")
                    #expect(found.isBold == word.isBold, "\(entry.id): weight of \(word.text)")
                }
                #expect(unmatched.isEmpty, "\(entry.id): words read that the recording does not have: \(unmatched.map(\.text))")
            }
        }
    }

    @Test("A fixture PDF imports through PDFKit exactly as its recorded layout does")
    func importsAsRecorded() async throws {
        for entry in try pdfEntries() {
            let data = try pdf(try #require(entry.pdf))
            let throughPDFKit = try await ImportCV(pdfReader: PDFKitTextExtractor(), limits: .standard).importPDF(data)
            let recorded = try await ImportCV(pdfReader: Recorded(layout: .pages(try recorded(entry))), limits: .standard).importPDF(data)
            #expect(throughPDFKit.document.text == recorded.document.text, "\(entry.id): another text")
            #expect(throughPDFKit.cv == recorded.cv, "\(entry.id): another CV")
        }
    }

    @Test("A scan has no text; bytes that are no PDF are unreadable; a PDF that needs a password is encrypted")
    func failures() async throws {
        let importer = ImportCV(pdfReader: PDFKitTextExtractor(), limits: .standard)
        await #expect(throws: ImportError.noText) { try await importer.importPDF(try pdf("scan/scan.pdf")) }
        await #expect(throws: ImportError.unreadable) { try await importer.importPDF(Data("not a PDF".utf8)) }

        let document = try #require(PDFDocument(data: try pdf("it-marco/wordpdf.pdf")))
        let locked = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
        defer { try? FileManager.default.removeItem(at: locked) }
        #expect(document.write(to: locked, withOptions: [.userPasswordOption: "secret", .ownerPasswordOption: "owner"]))
        await #expect(throws: ImportError.encrypted) { try await importer.importPDF(try Data(contentsOf: locked)) }
    }

    @Test("A PDF over the page limit is refused before its text is read, and one over the word limit as its words are")
    func limits() async throws {
        func limits(pages: Int, words: Int) -> ImportLimits {
            ImportLimits(
                maximumPDFBytes: 1_000_000, maximumPages: pages, maximumCharacters: 100_000,
                maximumWords: words, maximumLines: 2_000, maximumCells: 4_000, maximumAnalysisSteps: 10_000_000
            )
        }
        let linkedIn = try pdf("en-emily/linkedin.pdf")
        await #expect(throws: ImportError.tooManyPages) {
            try await PDFKitTextExtractor().layout(ofPDF: linkedIn, limits: limits(pages: 1, words: 20_000))
        }
        await #expect(throws: ImportError.tooLarge) {
            try await PDFKitTextExtractor().layout(ofPDF: linkedIn, limits: limits(pages: 10, words: 10))
        }
    }
}
#endif
