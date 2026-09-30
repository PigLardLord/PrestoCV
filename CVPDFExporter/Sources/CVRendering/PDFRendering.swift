import Foundation
import CVDocumentModel

/// The page the renderers print on. Every page keeps `verticalMarginPoints` free at its top and bottom, which a design's
/// padding cannot do past the first page; the left and right margins are the design's (markup-contract.md, "Pages").
public struct PageSetup: Sendable, Equatable {
    public var widthPoints: Double, heightPoints: Double, maxPages: Int, verticalMarginPoints: Double
    public static let a4 = PageSetup(widthPoints: 595, heightPoints: 842, maxPages: 4)
    public init(widthPoints: Double, heightPoints: Double, maxPages: Int, verticalMarginPoints: Double = 36) {
        self.widthPoints = widthPoints; self.heightPoints = heightPoints; self.maxPages = maxPages
        self.verticalMarginPoints = verticalMarginPoints
    }
}

extension PageSetup {
    /// Whether a renderer can print on it: finite, positive page dimensions, a finite margin that is not negative and
    /// leaves a printable height, and at least one page. Renderers refuse anything else before it reaches the platform.
    public var isPrintable: Bool {
        widthPoints.isFinite && heightPoints.isFinite && verticalMarginPoints.isFinite
            && widthPoints > 0 && verticalMarginPoints >= 0 && heightPoints - 2 * verticalMarginPoints > 0 && maxPages >= 1
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

    /// The text nodes the PDF text does not contain. Every node, each occurrence counted, needs its own span of the
    /// PDF text that no other node uses, so a value made of the end of one field and the start of the next ("Greg" +
    /// "Officer" contains "go") cannot stand in for a missing field.
    ///
    /// Spans that start and end where the PDF text breaks (whitespace or a line end) are tried first, and the search
    /// backtracks when a choice leaves another node without a span ("Ann" + "Anna"). A search that exceeds its step
    /// budget counts as incomplete: the check fails closed.
    public static func missing(in pdfText: String, expected textNodes: [String]) -> [String] {
        // The PDF text without whitespace, and for each position whether a break precedes or follows it.
        var pdf: [Unicode.Scalar] = [], startsAfterBreak: [Bool] = [], endsBeforeBreak: [Bool] = []
        var sawBreak = true
        for scalar in pdfText.lowercased().unicodeScalars {
            if scalar.properties.isWhitespace {
                sawBreak = true
                if !endsBeforeBreak.isEmpty { endsBeforeBreak[endsBeforeBreak.count - 1] = true }
                continue
            }
            pdf.append(scalar); startsAfterBreak.append(sawBreak); endsBeforeBreak.append(false); sawBreak = false
        }
        if !endsBeforeBreak.isEmpty { endsBeforeBreak[endsBeforeBreak.count - 1] = true }

        struct Node { let index: Int; let needle: [Unicode.Scalar]; let candidates: [Int]; var length: Int { needle.count } }
        let nodes: [Node] = textNodes.enumerated().compactMap { index, text in
            let needle = Array(normalize(text).unicodeScalars)
            guard !needle.isEmpty else { return nil }
            var starts: [(start: Int, rank: Int)] = []
            if needle.count <= pdf.count {
                for start in 0...(pdf.count - needle.count) where pdf[start] == needle[0] && Array(pdf[start..<start + needle.count]) == needle {
                    let rank = (startsAfterBreak[start] ? 0 : 1) + (endsBeforeBreak[start + needle.count - 1] ? 0 : 1)
                    starts.append((start, rank))
                }
            }
            return Node(index: index, needle: needle,
                        candidates: starts.sorted { $0.rank != $1.rank ? $0.rank < $1.rank : $0.start < $1.start }.map(\.start))
        }.sorted {   // longest first; identical values next to each other, for symmetry breaking
            if $0.length != $1.length { return $0.length > $1.length }
            if $0.needle != $1.needle { return String(String.UnicodeScalarView($0.needle)) < String(String.UnicodeScalarView($1.needle)) }
            return $0.index < $1.index
        }

        var claimed = [Bool](repeating: false, count: pdf.count)
        func free(_ start: Int, _ length: Int) -> Bool { !claimed[start..<start + length].contains(true) }
        func mark(_ start: Int, _ length: Int, _ value: Bool) { for i in start..<start + length { claimed[i] = value } }

        // Depth-first search for a complete assignment, within a step budget. Identical values take increasing
        // positions, so their permutations are never explored twice; a choice that leaves a later node without
        // any free candidate is undone at once.
        var steps = 0, exhausted = false
        var chosen = [Int](repeating: -1, count: nodes.count)
        /// A necessary condition: every group of identical later values still has at least as many disjoint free spans
        /// as it has members left to place. Spans of one value all have the same length, so taking them by increasing
        /// start gives the maximum number of disjoint ones.
        func everyLaterNodeCanStillBePlaced(after k: Int) -> Bool {
            var j = k + 1
            while j < nodes.count {
                var end = j
                while end + 1 < nodes.count && nodes[end + 1].needle == nodes[j].needle { end += 1 }
                let floor = j > 0 && nodes[j - 1].needle == nodes[j].needle ? chosen[j - 1] : -1
                var disjoint = 0, lastEnd = -1
                for start in nodes[j].candidates.sorted() where start > floor && start > lastEnd && free(start, nodes[j].length) {
                    disjoint += 1; lastEnd = start + nodes[j].length - 1
                }
                if disjoint < end - j + 1 { return false }
                j = end + 1
            }
            return true
        }
        func place(_ k: Int) -> Bool {
            if k == nodes.count { return true }
            steps += 1
            if steps > 100_000 { exhausted = true; return false }
            let floor = k > 0 && nodes[k].needle == nodes[k - 1].needle ? chosen[k - 1] : -1
            for start in nodes[k].candidates where start > floor && free(start, nodes[k].length) {
                mark(start, nodes[k].length, true)
                chosen[k] = start
                if everyLaterNodeCanStillBePlaced(after: k), place(k + 1) { return true }
                mark(start, nodes[k].length, false)
                if exhausted { return false }
            }
            return false
        }
        if everyLaterNodeCanStillBePlaced(after: -1), place(0) { return [] }

        // No complete assignment. First name the values that are short on their own: fewer disjoint occurrences in
        // the PDF text than in the document, whatever the other fields do. Only when every value has enough on its own
        // does the conflict lie between fields, and a greedy pass names what it cannot place.
        var missingIndices = Set<Int>()
        var g = 0
        while g < nodes.count {
            var end = g
            while end + 1 < nodes.count && nodes[end + 1].needle == nodes[g].needle { end += 1 }
            var disjoint = 0, lastEnd = -1
            for start in nodes[g].candidates.sorted() where start > lastEnd { disjoint += 1; lastEnd = start + nodes[g].length - 1 }
            if disjoint < end - g + 1 { for m in g...end { missingIndices.insert(nodes[m].index) } }
            g = end + 1
        }
        if missingIndices.isEmpty {
            claimed = [Bool](repeating: false, count: pdf.count)
            for node in nodes {
                if let start = node.candidates.first(where: { free($0, node.length) }) { mark(start, node.length, true) }
                else { missingIndices.insert(node.index) }
            }
        }
        if missingIndices.isEmpty, let last = nodes.last { missingIndices.insert(last.index) }   // budget exceeded: fail closed
        var seen = Set<String>(), missing: [String] = []
        for (index, text) in textNodes.enumerated() where missingIndices.contains(index) && seen.insert(text).inserted { missing.append(text) }
        return missing
    }
}
