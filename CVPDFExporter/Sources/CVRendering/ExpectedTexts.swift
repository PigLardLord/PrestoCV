import Foundation

/// A text node the PDF must hold: what to look for, and where the PDF text has it.
struct ExpectedText {
    /// Where the node stands among the document's text nodes.
    let index: Int
    let needle: [Unicode.Scalar]
    /// The positions of the needle in the PDF text, best first (see `PDFTextIndex.occurrences`).
    let candidates: [Int]
    private let candidatesByStart: [Int]
    let sortKey: String

    var length: Int { needle.count }

    /// nil for a node with no text to look for.
    init?(index: Int, text: String, in pdf: PDFTextIndex) {
        let needle = Array(DocumentCompleteness.normalize(text).unicodeScalars)
        guard !needle.isEmpty else { return nil }
        self.index = index
        self.needle = needle
        sortKey = String(String.UnicodeScalarView(needle))
        candidates = pdf.occurrences(of: needle)
        candidatesByStart = candidates.sorted()
    }

    func firstFreeSpan(in claims: SpanClaims) -> Int? {
        candidates.first { claims.isFree($0, length: length) }
    }

    /// How many spans of this text, none overlapping another or a claimed span, start after `floor`. The spans of one
    /// text all have the same length, so taking them by increasing start gives the most.
    func disjointSpans(after floor: Int, free claims: SpanClaims) -> Int {
        var count = 0, lastEnd = -1
        for start in candidatesByStart where start > floor && start > lastEnd && claims.isFree(start, length: length) {
            count += 1
            lastEnd = start + length - 1
        }
        return count
    }
}

/// The text nodes of a document that have text, longest first, with identical texts next to each other so that a
/// search can place them in increasing order and never explore the same placement twice.
struct ExpectedTexts {
    let items: [ExpectedText]
    /// The runs of identical texts in `items`.
    let groups: [Range<Int>]

    init(_ textNodes: [String], in pdf: PDFTextIndex) {
        let texts = textNodes.enumerated().compactMap { ExpectedText(index: $0.offset, text: $0.element, in: pdf) }
        items = texts.sorted(by: Self.isOrdered)
        groups = Self.groups(of: items)
    }

    private static func isOrdered(_ first: ExpectedText, _ second: ExpectedText) -> Bool {
        if first.length != second.length { return first.length > second.length }
        if first.needle != second.needle { return first.sortKey < second.sortKey }
        return first.index < second.index
    }

    private static func groups(of texts: [ExpectedText]) -> [Range<Int>] {
        var groups: [Range<Int>] = []
        var start = 0
        while start < texts.count {
            var end = start + 1
            while end < texts.count, texts[end].needle == texts[start].needle { end += 1 }
            groups.append(start..<end)
            start = end
        }
        return groups
    }
}
