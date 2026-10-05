import Foundation

/// Names the texts to report when no placement of all of them exists.
struct ShortfallDiagnosis {
    private let texts: [ExpectedText]
    private let groups: [Range<Int>]
    private let unclaimed: SpanClaims

    init(_ expected: ExpectedTexts, pdfLength: Int) {
        texts = expected.items
        groups = expected.groups
        unclaimed = SpanClaims(count: pdfLength)
    }

    /// The document positions of the texts that have no span. First the texts that are short on their own: fewer
    /// disjoint occurrences in the PDF text than in the document, whatever the other fields do. Only when every text
    /// has enough on its own does the conflict lie between fields, and a greedy pass names what it cannot place. When
    /// that finds nothing either, the search ran out of budget: the last text is named, so the check fails closed.
    func unplacedIndices() -> Set<Int> {
        var indices = shortOnTheirOwn()
        if indices.isEmpty { indices = unplacedByGreedyPass() }
        if indices.isEmpty, let last = texts.last { indices.insert(last.index) }
        return indices
    }

    private func shortOnTheirOwn() -> Set<Int> {
        var indices = Set<Int>()
        for group in groups where isShort(group) { indices.formUnion(group.map { texts[$0].index }) }
        return indices
    }

    private func isShort(_ group: Range<Int>) -> Bool {
        texts[group.lowerBound].disjointSpans(after: -1, free: unclaimed) < group.count
    }

    private func unplacedByGreedyPass() -> Set<Int> {
        var claims = unclaimed
        var indices = Set<Int>()
        for text in texts {
            guard let start = text.firstFreeSpan(in: claims) else { indices.insert(text.index); continue }
            claims.claim(start, length: text.length)
        }
        return indices
    }
}
