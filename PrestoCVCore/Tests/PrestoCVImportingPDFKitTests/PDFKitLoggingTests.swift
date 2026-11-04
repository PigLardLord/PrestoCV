#if canImport(PDFKit)
import CoreText
import DiagnosticLogging
import DiagnosticLoggingTestSupport
import DiagnosticTrace
import Foundation
import Testing
import PrestoCVImporting
import PrestoCVImportingPDFKit

/// What the PDFKit reader writes to the diagnostic log (ADR 0030): the pages and the words it read, and the limit that
/// stopped it, and never a word of the PDF.
@Suite("The log of the PDFKit reader")
struct PDFKitLoggingTests {

    /// A PDF drawn when the test runs: one page per entry of `pages`, each with its lines in Helvetica of 12 points.
    private func drawnPDF(_ pages: [[String]]) throws -> Data {
        let data = NSMutableData()
        var box = CGRect(x: 0, y: 0, width: 595, height: 842)
        let consumer = try #require(CGDataConsumer(data: data as CFMutableData))
        let context = try #require(CGContext(consumer: consumer, mediaBox: &box, nil))
        let font = CTFontCreateWithName("Helvetica" as CFString, 12, nil)
        for lines in pages {
            context.beginPDFPage(nil)
            for (row, line) in lines.enumerated() {
                context.textPosition = CGPoint(x: 50, y: 790 - CGFloat(row) * 16)
                CTLineDraw(CTLineCreateWithAttributedString(NSAttributedString(string: line, attributes: [.font: font])), context)
            }
            context.endPDFPage()
        }
        context.closePDF()
        return data as Data
    }

    private func limits(pages: Int = 10, characters: Int = 100_000, words: Int = 20_000) -> ImportLimits {
        ImportLimits(
            maximumPDFBytes: 20_000_000, maximumPages: pages, maximumCharacters: characters,
            maximumWords: words, maximumLines: 2_000, maximumCells: 4_000, maximumAnalysisSteps: 10_000_000
        )
    }

    @Test("A PDF read logs its pages and its words")
    func read() async throws {
        let logger = RecordingLogger()
        let pdf = try drawnPDF([["Lena Hartmann", "Elektrikerin in Leipzig"], ["Berufserfahrung"]])

        _ = try await PDFKitTextExtractor(logger: logger).layout(ofPDF: pdf, limits: limits())

        let read = try #require(logger.entry("pdf.read"))
        #expect(read.level == .info)
        #expect(read.category == LogCategory("import"))
        #expect(read.fields == [.count("pages", 2), .count("words", 6)])
    }

    @Test("A limit that stops the reading is logged by its name, as a notice, and thrown as that limit", arguments: [
        (10, 5, 20_000, "characters", LimitReached(.characters)), (10, 100_000, 3, "words", LimitReached(.words)),
        (1, 100_000, 20_000, "pages", LimitReached(.pages)),
    ])
    func limit(pages: Int, characters: Int, words: Int, name: String, reached: LimitReached) async throws {
        let logger = RecordingLogger()
        let pdf = try drawnPDF([["Lena Hartmann", "Elektrikerin in Leipzig"], ["Berufserfahrung"]])

        await #expect(throws: reached) {
            try await PDFKitTextExtractor(logger: logger).layout(ofPDF: pdf, limits: limits(pages: pages, characters: characters, words: words))
        }

        let reached = try #require(logger.entry("pdf.limit"))
        #expect(reached.level == .notice)
        #expect(reached.line == "pdf.limit limit=\(name)")
        #expect(!logger.events.contains("pdf.read"))
    }

    @Test("Bytes over the limit are logged as that limit")
    func bytes() async throws {
        let logger = RecordingLogger()
        let tight = ImportLimits(
            maximumPDFBytes: 10, maximumPages: 10, maximumCharacters: 100_000,
            maximumWords: 20_000, maximumLines: 2_000, maximumCells: 4_000, maximumAnalysisSteps: 10_000_000
        )

        await #expect(throws: LimitReached(.bytes)) {
            try await PDFKitTextExtractor(logger: logger).layout(ofPDF: try drawnPDF([["Lena"]]), limits: tight)
        }

        #expect(logger.entry("pdf.limit")?.line == "pdf.limit limit=bytes")
    }

    @Test("Through the import, a limit the reader stops at fails it as that limit, and the failure names it", arguments: [
        (10, 5, 20_000, "characters", ImportError.tooLarge), (10, 100_000, 3, "words", .tooLarge), (1, 100_000, 20_000, "pages", .tooManyPages),
    ])
    func limitThroughTheImport(pages: Int, characters: Int, words: Int, name: String, error: ImportError) async throws {
        let logger = RecordingLogger()
        let pdf = try drawnPDF([["Lena Hartmann", "Elektrikerin in Leipzig"], ["Berufserfahrung"]])
        let importer = ImportCV(
            pdfReader: PDFKitTextExtractor(logger: logger), limits: limits(pages: pages, characters: characters, words: words),
            logger: logger, clock: ContinuousClock(), tracer: NoTracer()
        )

        await #expect(throws: error) { try await importer.importPDF(pdf) }

        #expect(logger.events == ["pdf.limit", "import.failed"])
        let failed = try #require(logger.entry("import.failed"))
        #expect(failed.level == .error)
        #expect(failed.value("limit") == .token(name))
        #expect(failed.value("error") == .error(type: "ImportError", code: String(describing: error)))
    }

    @Test("No word of the PDF reaches the log, through the reader or the import")
    func noCVContent() async throws {
        let marker = "Quorvex"
        let logger = RecordingLogger()
        let pdf = try drawnPDF([["Lena \(marker)", "\(marker) GmbH, Leipzig", "Berufserfahrung", "03/2019 – heute \(marker)"]])
        let importer = ImportCV(pdfReader: PDFKitTextExtractor(logger: logger), limits: .standard, logger: logger, clock: ContinuousClock(), tracer: NoTracer())

        _ = try await importer.importPDF(pdf)
        _ = try? await PDFKitTextExtractor(logger: logger).layout(ofPDF: pdf, limits: limits(characters: 5))

        #expect(logger.events.contains("pdf.read"))
        #expect(logger.events.contains("import.finished"))
        #expect(logger.events.contains("pdf.limit"))
        for entry in logger.entries {
            #expect(!entry.line.localizedCaseInsensitiveContains(marker), "\(entry.line)")
        }
    }
}
#endif
