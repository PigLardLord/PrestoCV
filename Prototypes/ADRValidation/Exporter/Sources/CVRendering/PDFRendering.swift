import Foundation
import CVDocumentModel

public struct PageSetup: Sendable, Equatable {
    public var widthPoints: Double, heightPoints: Double, maxPages: Int
    public static let a4 = PageSetup(widthPoints: 595, heightPoints: 842, maxPages: 4)
    public init(widthPoints: Double, heightPoints: Double, maxPages: Int) {
        self.widthPoints = widthPoints; self.heightPoints = heightPoints; self.maxPages = maxPages
    }
}

/// `pageCount` is the number of pages in `data`; `requiredPages` is how many the content needed.
/// Truncation is derived, never self-declared.
public struct RenderedPDF: Sendable, Equatable {
    public var data: Data, pageCount: Int, requiredPages: Int
    public var truncated: Bool { requiredPages > pageCount }
    public init(data: Data, pageCount: Int, requiredPages: Int) {
        self.data = data; self.pageCount = pageCount; self.requiredPages = requiredPages
    }
}

/// Outbound port: one adapter per platform (ADR 0003). Sendable, async, not actor-constrained (R3).
public protocol PDFRendering: Sendable {
    func render(html: String, page: PageSetup) async throws -> RenderedPDF
}

/// Reads what a PDF really contains (PDFKit on Apple platforms). Used by the export workflow to check
/// every export, and by the renderer contract suite.
public protocol PDFInspecting: Sendable {
    func pageCount(of data: Data) -> Int?
    func text(of data: Data) -> String?
}

/// Completeness (R8, ADR 0011): every text node the builder produced must appear in the PDF, counted
/// occurrence by occurrence. A value that also occurs elsewhere (a skill named in the summary, two
/// identical entries, a date) is required as many times as the document contains it, so removing one
/// occurrence is detected. Case and whitespace are ignored: designs may use text-transform, and PDF text
/// extraction does not preserve spacing.
public enum DocumentCompleteness {
    static func normalize(_ s: String) -> String {
        String(String.UnicodeScalarView(s.lowercased().unicodeScalars.filter { !$0.properties.isWhitespace }))
    }

    static func occurrences(of needle: String, in haystack: String) -> Int {
        guard !needle.isEmpty else { return 0 }
        var count = 0, range = haystack.startIndex..<haystack.endIndex
        while let r = haystack.range(of: needle, range: range) { count += 1; range = r.upperBound..<haystack.endIndex }
        return count
    }

    /// The text nodes whose occurrences in the PDF text are fewer than in the document itself.
    public static func missing(in pdfText: String, expected textNodes: [String]) -> [String] {
        let document = normalize(textNodes.joined(separator: "\u{1F}"))
        let pdf = normalize(pdfText)
        var seen = Set<String>(), missing: [String] = []
        for node in textNodes {
            let n = normalize(node)
            guard !n.isEmpty, seen.insert(n).inserted else { continue }
            if occurrences(of: n, in: pdf) < occurrences(of: n, in: document) { missing.append(node) }
        }
        return missing
    }
}
