import DiagnosticLogging
import Foundation

// MARK: - The port

/// Reads the text of a PDF: each page's words with their box and style, in the reader's order (ADR 0027). The core
/// decides the reading order. Cancellation passes, so it throws untyped errors. Three kinds of error pass as they are: a
/// `CancellationError`, an `ImportError` (a PDF that is encrypted, empty or unreadable), and a `LimitReached` when the
/// reader stopped at a bound of `ImportLimits`, which the use case words as `ImportError.tooLarge` or `.tooManyPages` and
/// logs with the bound's name. The use case turns any other error into `ImportError.unreadable`.
public protocol PDFTextExtracting: Sendable {
    func layout(ofPDF data: Data, limits: ImportLimits) async throws -> ExtractedLayout
}

// MARK: - Limits and errors

/// The bounds of an import's input, checked before it is read (R8). A PDF's geometry is bounded too: its words before
/// the page analysis, its lines and cells before the columns are looked for, and the analysis's work as it goes.
public struct ImportLimits: Hashable, Sendable {
    public let maximumPDFBytes: Int
    public let maximumPages: Int
    /// Characters of a pasted text, or of a PDF's text.
    public let maximumCharacters: Int
    /// Words of a PDF, over all its pages.
    public let maximumWords: Int
    /// Lines of a PDF, over all its pages.
    public let maximumLines: Int
    /// Cells of a PDF's lines, over all its pages.
    public let maximumCells: Int
    /// Steps of a PDF's page analysis: each pass over its words, lines or cells counts its steps.
    public let maximumAnalysisSteps: Int

    public init(
        maximumPDFBytes: Int, maximumPages: Int, maximumCharacters: Int,
        maximumWords: Int, maximumLines: Int, maximumCells: Int, maximumAnalysisSteps: Int
    ) {
        self.maximumPDFBytes = maximumPDFBytes
        self.maximumPages = maximumPages
        self.maximumCharacters = maximumCharacters
        self.maximumWords = maximumWords
        self.maximumLines = maximumLines
        self.maximumCells = maximumCells
        self.maximumAnalysisSteps = maximumAnalysisSteps
    }

    /// Ten pages and a hundred thousand characters hold any CV; a PDF of a CV is rarely over a few megabytes. A dense
    /// page holds some 800 words in 80 lines of a few cells each: the bounds on a PDF's geometry are well above ten such
    /// pages, and the analysis of a PDF within them takes a fraction of its budget.
    public static let standard = ImportLimits(
        maximumPDFBytes: 20_000_000, maximumPages: 10, maximumCharacters: 100_000,
        maximumWords: 20_000, maximumLines: 2_000, maximumCells: 4_000, maximumAnalysisSteps: 10_000_000
    )
}

/// Why an import produced nothing. The app words each one (R13).
public enum ImportError: Error, Equatable, Sendable {
    /// No text at all.
    case empty
    /// Over the bytes, characters, words, lines, cells or analysis steps of `ImportLimits`.
    case tooLarge
    case tooManyPages
    /// A PDF that needs a password.
    case encrypted
    /// Bytes that are no PDF, or a PDF that cannot be read.
    case unreadable
    /// A PDF without a text layer: a scan or a photo. The person can paste its text instead.
    case noText
}

// MARK: - The use case

/// Imports a CV someone already has, with rules only, on every device (ADR 0027). It logs what it read and how it
/// failed through the logger it is given, as counts, kinds and times (ADR 0030).
public struct ImportCV: Sendable {
    private let pdfReader: any PDFTextExtracting
    private let limits: ImportLimits
    private let logger: any DiagnosticLogger
    private let clock: any Clock<Duration>

    /// - Parameter clock: measures the time an import takes, for the log.
    public init(pdfReader: any PDFTextExtracting, limits: ImportLimits, logger: any DiagnosticLogger, clock: any Clock<Duration>) {
        self.pdfReader = pdfReader
        self.limits = limits
        self.logger = logger
        self.clock = clock
    }

    /// Imports a pasted text. Reading it is bounded by the same steps as a PDF's (`ImportLimits`). Lets
    /// `CancellationError` through; every other failure is an `ImportError`.
    public func importText(_ text: String) throws -> ImportResult {
        let stopwatch = Stopwatch(started: self.clock)
        let log = ImportLog(logger: logger, source: .text)
        do {
            let reading = try readText(text)
            log.finished(reading, pages: nil, elapsed: stopwatch.elapsed)
            return reading.result
        } catch {
            throw log.failed(error, elapsed: stopwatch.elapsed)
        }
    }

    /// Imports a PDF's text. Lets `CancellationError` through; every other failure is an `ImportError`.
    public func importPDF(_ data: Data) async throws -> ImportResult {
        let stopwatch = Stopwatch(started: self.clock)
        let log = ImportLog(logger: logger, source: .pdf)
        do {
            let (reading, pages) = try await readPDF(data)
            log.finished(reading, pages: pages, elapsed: stopwatch.elapsed)
            return reading.result
        } catch {
            throw log.failed(error, elapsed: stopwatch.elapsed)
        }
    }

    // MARK: Reading

    private func readText(_ text: String) throws -> CVReader.Reading {
        guard text.unicodeScalars.count <= limits.maximumCharacters else { throw LimitReached(.characters) }
        guard text.contains(where: { $0.isLetter }) else { throw ImportError.empty }
        let lines = PlainTextReader.lines(of: text).map { RawLine(text: $0) }
        let (document, leftOut) = DocumentBuilder.build(lines: lines, format: .pastedText)
        guard !document.blocks.isEmpty else { throw ImportError.empty }
        return try CVReader.read(document, leftOut: leftOut, work: AnalysisWork(budget: limits.maximumAnalysisSteps))
    }

    /// The reading of a PDF, and its pages when the reader saw any.
    private func readPDF(_ data: Data) async throws -> (reading: CVReader.Reading, pages: Int?) {
        guard !data.isEmpty else { throw ImportError.empty }
        guard data.count <= limits.maximumPDFBytes else { throw LimitReached(.bytes) }
        let layout: ExtractedLayout
        do {
            layout = try await pdfReader.layout(ofPDF: data, limits: limits)
        } catch let error as ImportError {
            throw error
        } catch let reached as LimitReached {
            throw reached
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw ImportError.unreadable
        }
        return try reading(layout)
    }

    private func reading(_ layout: ExtractedLayout) throws -> (reading: CVReader.Reading, pages: Int?) {
        guard case .pages(let pages) = layout else {
            if case .text(let lines) = layout { return (try readText(lines.joined(separator: "\n")), nil) }
            throw ImportError.unreadable
        }
        guard pages.count <= limits.maximumPages else { throw LimitReached(.pages) }
        guard pages.reduce(0, { $0 + $1.words.count }) <= limits.maximumWords else { throw LimitReached(.words) }
        let characters = pages.reduce(0) { $0 + $1.words.reduce(0) { $0 + $1.text.unicodeScalars.count } }
        guard characters <= limits.maximumCharacters else { throw LimitReached(.characters) }
        // A scan has no text layer, or only a few stray characters
        let letters = pages.reduce(0) { $0 + $1.words.reduce(0) { $0 + $1.text.filter(\.isLetter).count } }
        guard letters >= 20 else { throw ImportError.noText }
        var work = AnalysisWork(budget: limits.maximumAnalysisSteps)
        let analysis = try LayoutAnalyzer.analyze(pages, limits: limits, work: &work)
        let (document, leftOut) = DocumentBuilder.build(lines: analysis.lines, format: .pdf)
        guard !document.blocks.isEmpty else { throw ImportError.noText }
        try Task.checkCancellation()
        return (try CVReader.read(document, leftOut: analysis.leftOut + leftOut, work: work), pages.count)
    }
}
