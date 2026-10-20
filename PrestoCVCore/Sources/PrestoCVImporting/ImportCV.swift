import Foundation

// MARK: - The port

/// Reads the text of a PDF: each page's words with their box and style, in the reader's order (ADR 0027). The core
/// decides the reading order. Cancellation passes, so it throws untyped errors; the use case turns any other error
/// into an `ImportError`.
public protocol PDFTextExtracting: Sendable {
    func layout(ofPDF data: Data, limits: ImportLimits) async throws -> ExtractedLayout
}

// MARK: - Limits and errors

/// The bounds of an import's input, checked before it is read (R8).
public struct ImportLimits: Hashable, Sendable {
    public let maximumPDFBytes: Int
    public let maximumPages: Int
    /// Characters of a pasted text, or of a PDF's text.
    public let maximumCharacters: Int

    public init(maximumPDFBytes: Int, maximumPages: Int, maximumCharacters: Int) {
        self.maximumPDFBytes = maximumPDFBytes
        self.maximumPages = maximumPages
        self.maximumCharacters = maximumCharacters
    }

    /// Ten pages and a hundred thousand characters hold any CV; a PDF of a CV is rarely over a few megabytes.
    public static let standard = ImportLimits(maximumPDFBytes: 20_000_000, maximumPages: 10, maximumCharacters: 100_000)
}

/// Why an import produced nothing. The app words each one (R13).
public enum ImportError: Error, Equatable, Sendable {
    /// No text at all.
    case empty
    /// Over the bytes or characters of `ImportLimits`.
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

/// Imports a CV someone already has, with rules only, on every device (ADR 0027).
public struct ImportCV: Sendable {
    private let pdfReader: any PDFTextExtracting
    private let limits: ImportLimits

    public init(pdfReader: any PDFTextExtracting, limits: ImportLimits) {
        self.pdfReader = pdfReader
        self.limits = limits
    }

    /// Imports a pasted text.
    public func importText(_ text: String) throws(ImportError) -> ImportResult {
        guard text.unicodeScalars.count <= limits.maximumCharacters else { throw .tooLarge }
        guard text.contains(where: { $0.isLetter }) else { throw .empty }
        let lines = PlainTextReader.lines(of: text).map { RawLine(text: $0) }
        let (document, leftOut) = DocumentBuilder.build(lines: lines, format: .pastedText)
        guard !document.blocks.isEmpty else { throw .empty }
        return CVReader.read(document, leftOut: leftOut)
    }

    /// Imports a PDF's text. Lets `CancellationError` through; every other failure is an `ImportError`.
    public func importPDF(_ data: Data) async throws -> ImportResult {
        guard !data.isEmpty else { throw ImportError.empty }
        guard data.count <= limits.maximumPDFBytes else { throw ImportError.tooLarge }
        let layout: ExtractedLayout
        do {
            layout = try await pdfReader.layout(ofPDF: data, limits: limits)
        } catch let error as ImportError {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw ImportError.unreadable
        }
        return try read(layout)
    }

    /// Reads what a PDF reader saw.
    func read(_ layout: ExtractedLayout) throws(ImportError) -> ImportResult {
        guard case .pages(let pages) = layout else {
            if case .text(let lines) = layout { return try importText(lines.joined(separator: "\n")) }
            throw .unreadable
        }
        guard pages.count <= limits.maximumPages else { throw .tooManyPages }
        let characters = pages.reduce(0) { $0 + $1.words.reduce(0) { $0 + $1.text.unicodeScalars.count } }
        guard characters <= limits.maximumCharacters else { throw .tooLarge }
        // A scan has no text layer, or only a few stray characters
        let letters = pages.reduce(0) { $0 + $1.words.reduce(0) { $0 + $1.text.filter(\.isLetter).count } }
        guard letters >= 20 else { throw .noText }
        let analysis = LayoutAnalyzer.analyze(pages)
        let (document, leftOut) = DocumentBuilder.build(lines: analysis.lines, format: .pdf)
        guard !document.blocks.isEmpty else { throw .noText }
        return CVReader.read(document, leftOut: analysis.leftOut + leftOut)
    }
}
