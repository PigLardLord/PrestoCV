import DiagnosticLogging
import DiagnosticLoggingTestSupport
import DiagnosticTrace
import Foundation
import Testing
@testable import PrestoCVImporting

/// What an import writes to the diagnostic log (ADR 0030): its decisions and failures, as counts, kinds and times, and
/// never a word of the CV.
@Suite("The log of an import")
struct ImportLoggingTests {

    private let limits = ImportLimits(
        maximumPDFBytes: 1_000, maximumPages: 3, maximumCharacters: 5_000,
        maximumWords: 1_000, maximumLines: 200, maximumCells: 400, maximumAnalysisSteps: 1_000_000
    )

    /// Every reading of the clock moves it on by this step: an import that reads it at its start and at its end takes one.
    private static let step = Duration.milliseconds(7)

    private func importer(
        _ reader: ScriptedPDFReader = ScriptedPDFReader(), limits: ImportLimits? = nil, logger: RecordingLogger
    ) -> ImportCV {
        ImportCV(pdfReader: reader, limits: limits ?? self.limits, logger: logger, clock: TickingClock(step: Self.step), tracer: NoTracer())
    }

    private static let pastedCV = """
    # Giulia Bianchi
    **Infermiera**
    Torino, Italia · giulia.bianchi@example.com

    ## Esperienza
    **Infermiera** | Ospedale Esempio | Torino | 03/2019 – oggi
    - Assistenza ai pazienti

    ## Lingue
    - Inglese: buono

    ## Volontariato
    Croce Rossa, dal 2015

    ## Lieblingsessen
    Pizza
    """

    // MARK: Finished

    @Test("A pasted text logs its kind, the characters read, the sections by kind and the time taken")
    func pastedText() throws {
        let logger = RecordingLogger()
        let result = try importer(logger: logger).importText(Self.pastedCV)

        #expect(logger.events == ["import.sections", "import.unrecognised", "import.finished"])
        let finished = try #require(logger.entry("import.finished"))
        #expect(finished.level == .info)
        #expect(finished.category == LogCategory("import"))
        #expect(finished.fields == [
            .token("kind", "text"), .count("characters", result.document.text.unicodeScalars.count),
            .count("sections", 5), .duration("elapsed", Self.step),
        ])
        #expect(logger.entry("import.sections")?.fields == [
            .count("header", 1), .count("experience", 1), .count("languages", 1), .count("volunteering", 1), .count("unknown", 1),
        ])
    }

    @Test("A heading the vocabulary does not know and the text left unplaced are counted, as a notice")
    func unrecognised() throws {
        let logger = RecordingLogger()
        let result = try importer(logger: logger).importText(Self.pastedCV)

        let unrecognised = try #require(logger.entry("import.unrecognised"))
        #expect(unrecognised.level == .notice)
        #expect(unrecognised.fields == [.count("headings", 1), .count("unplaced", result.unplaced.count)])
        #expect(result.unplaced.count == 2)
    }

    @Test("A text that every rule places logs no notice")
    func nothingUnrecognised() throws {
        let logger = RecordingLogger()
        _ = try importer(logger: logger).importText("Giulia Bianchi\nInfermiera\n\n## Esperienza\nInfermiera | Ospedale Esempio | 2019 – oggi")

        #expect(!logger.events.contains("import.unrecognised"))
    }

    @Test("A PDF logs its kind, its pages, the characters read and the time taken")
    func pdf() async throws {
        var sketch = PageSketch()
        sketch.put("Lena Hartmann", x: 50, y: 50, size: 20, bold: true)
        sketch.put("Elektrikerin", x: 50, y: 80)
        sketch.put("Berufserfahrung", x: 50, y: 120, size: 13, bold: true)
        sketch.put("03/2019 – heute", x: 50, y: 140)
        sketch.put("Elektrikerin, Beispiel GmbH, Leipzig", x: 200, y: 140)
        let blank = ExtractedPage(width: 595, height: 842, words: [])
        let logger = RecordingLogger()

        let result = try await importer(ScriptedPDFReader(layout: .pages([sketch.page, blank])), logger: logger).importPDF(Data([1]))

        let finished = try #require(logger.entry("import.finished"))
        #expect(finished.fields == [
            .token("kind", "pdf"), .count("pages", 2), .count("characters", result.document.text.unicodeScalars.count),
            .count("sections", 2), .duration("elapsed", Self.step),
        ])
        #expect(logger.entry("import.sections")?.fields == [.count("header", 1), .count("experience", 1)])
    }

    // MARK: Failures

    @Test("A failure of the PDF reader is logged by its kind, as an error", arguments: [
        (ImportError.encrypted, "encrypted"), (.unreadable, "unreadable"), (.empty, "empty"), (.noText, "noText"),
    ])
    func readerFailure(error: ImportError, code: String) async throws {
        let logger = RecordingLogger()
        await #expect(throws: error) { try await importer(ScriptedPDFReader(error: error), logger: logger).importPDF(Data([1])) }

        let failed = try #require(logger.entry("import.failed"))
        #expect(failed.level == .error)
        #expect(failed.fields == [.token("kind", "pdf"), .error(error), .duration("elapsed", Self.step)])
        #expect(failed.line.contains("error=ImportError.\(code)"))
    }

    @Test("A reader's own error is logged as the unreadable PDF it becomes")
    func readerOwnError() async throws {
        struct Broken: Error {}
        let logger = RecordingLogger()
        await #expect(throws: ImportError.unreadable) { try await importer(ScriptedPDFReader(error: Broken()), logger: logger).importPDF(Data([1])) }

        #expect(logger.entry("import.failed")?.fields.dropFirst().first == .error(ImportError.unreadable))
    }

    @Test("A limit that the PDF reader names fails the import as the core's own limits do, and is logged with its name", arguments: [
        (LimitReached.Limit.bytes, ImportError.tooLarge, "bytes"), (.pages, .tooManyPages, "pages"), (.characters, .tooLarge, "characters"),
        (.words, .tooLarge, "words"), (.lines, .tooLarge, "lines"), (.cells, .tooLarge, "cells"), (.steps, .tooLarge, "steps"),
    ])
    func readerLimit(limit: LimitReached.Limit, error: ImportError, name: String) async throws {
        let logger = RecordingLogger()
        await #expect(throws: error) {
            try await importer(ScriptedPDFReader(error: LimitReached(limit)), logger: logger).importPDF(Data([1]))
        }

        let failed = try #require(logger.entry("import.failed"))
        #expect(failed.level == .error)
        #expect(failed.fields.map(\.key) == ["kind", "error", "limit", "elapsed"])
        #expect(failed.value("error") == .error(type: "ImportError", code: String(describing: error)))
        #expect(failed.value("limit") == .token(name))
    }

    @Test("A scan without a text layer is logged as one")
    func scan() async throws {
        let logger = RecordingLogger()
        let scan = ExtractedPage(width: 595, height: 842, words: [])
        await #expect(throws: ImportError.noText) { try await importer(ScriptedPDFReader(layout: .pages([scan])), logger: logger).importPDF(Data([1])) }

        #expect(logger.entry("import.failed")?.line.hasPrefix("import.failed kind=pdf error=ImportError.noText") == true)
    }

    @Test("A limit of the bounded reading says which one it is")
    func limits() async throws {
        let logger = RecordingLogger()
        var sketch = PageSketch()
        sketch.put("Lena Hartmann", x: 50, y: 50, size: 20, bold: true)
        sketch.put("Elektrikerin bei der Beispiel GmbH in Leipzig", x: 50, y: 80)

        #expect(throws: ImportError.tooLarge) { try importer(logger: logger).importText(String(repeating: "a", count: 5_001)) }
        await #expect(throws: ImportError.tooLarge) { try await importer(logger: logger).importPDF(Data(count: 1_001)) }
        let fourPages = Array(repeating: sketch.page, count: 4)
        await #expect(throws: ImportError.tooManyPages) {
            try await importer(ScriptedPDFReader(layout: .pages(fourPages)), logger: logger).importPDF(Data([1]))
        }
        let tight = ImportLimits(
            maximumPDFBytes: 1_000, maximumPages: 3, maximumCharacters: 5_000,
            maximumWords: 1_000, maximumLines: 200, maximumCells: 400, maximumAnalysisSteps: 10
        )
        await #expect(throws: ImportError.tooLarge) {
            try await importer(ScriptedPDFReader(layout: .pages([sketch.page])), limits: tight, logger: logger).importPDF(Data([1]))
        }

        let failures = logger.entries("import.failed")
        #expect(failures.map { $0.value("limit") } == [.token("characters"), .token("bytes"), .token("pages"), .token("steps")])
        #expect(failures.map { $0.value("error") } == [
            .error(type: "ImportError", code: "tooLarge"), .error(type: "ImportError", code: "tooLarge"),
            .error(type: "ImportError", code: "tooManyPages"), .error(type: "ImportError", code: "tooLarge"),
        ])
        #expect(failures.allSatisfy { $0.level == .error })
    }

    @Test("A cancelled import logs its kind and the time it ran, and lets the cancellation through")
    func cancelled() async throws {
        let logger = RecordingLogger()
        await #expect(throws: CancellationError.self) {
            try await importer(ScriptedPDFReader(error: CancellationError()), logger: logger).importPDF(Data([1]))
        }

        let cancelled = try #require(logger.entry("import.cancelled"))
        #expect(cancelled.level == .info)
        #expect(cancelled.fields == [.token("kind", "pdf"), .duration("elapsed", Self.step)])
    }

    // MARK: Names

    @Test("Every kind of section, every failure and every limit is logged by its name")
    func names() {
        for kind in SectionKind.allCases { #expect(kind.logKey.description == kind.rawValue) }
        for error in [ImportError.empty, .tooLarge, .tooManyPages, .encrypted, .unreadable, .noText] {
            #expect(error.logCode.description == String(describing: error))
        }
        let limits: [LimitReached.Limit] = [.bytes, .pages, .characters, .words, .lines, .cells, .steps]
        #expect(limits.map { LimitReached($0).logName.description } == limits.map { String(describing: $0) })
        #expect(limits.map { LimitReached($0).importError } == [.tooLarge, .tooManyPages, .tooLarge, .tooLarge, .tooLarge, .tooLarge, .tooLarge])
    }

    // MARK: No CV content

    @Test("No word of the CV reaches the log, whatever the import does with it")
    func noCVContent() async throws {
        let marker = "Quorvex"
        let cv = """
        # Giulia \(marker)
        **\(marker) Infermiera**
        Torino \(marker), Italia · \(marker.lowercased())@example.com

        ## Esperienza
        **Infermiera** | Ospedale \(marker) | Torino | 03/2019 – oggi
        - \(marker) ai pazienti

        ## \(marker) Lieblingsessen
        \(marker) Pizza
        """
        let logger = RecordingLogger()
        _ = try importer(logger: logger).importText(cv)
        _ = try? importer(logger: logger).importText(cv + String(repeating: " \(marker)", count: 1_000))
        var sketch = PageSketch()
        sketch.put("Lena \(marker)", x: 50, y: 50, size: 20, bold: true)
        sketch.put("\(marker) GmbH, Leipzig", x: 50, y: 80)
        _ = try await importer(ScriptedPDFReader(layout: .pages([sketch.page])), logger: logger).importPDF(Data(marker.utf8))

        #expect(logger.events.contains("import.finished"))
        #expect(logger.events.contains("import.failed"))
        for entry in logger.entries {
            #expect(!entry.line.localizedCaseInsensitiveContains(marker), "\(entry.line)")
        }
    }
}
