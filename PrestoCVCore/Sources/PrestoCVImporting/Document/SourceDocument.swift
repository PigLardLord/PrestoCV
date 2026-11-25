// MARK: - Spans

/// A half-open range of Unicode scalars of `SourceDocument.text`: the same on every platform. Every value of an import
/// points to the spans it was quoted from.
public struct SourceSpan: Hashable, Sendable, Comparable, Codable {
    public let lowerBound: Int
    public let upperBound: Int

    /// The bounds in either order.
    public init(_ a: Int, _ b: Int) {
        lowerBound = Swift.min(a, b)
        upperBound = Swift.max(a, b)
    }

    public var count: Int { upperBound - lowerBound }
    public var isEmpty: Bool { lowerBound == upperBound }

    public func contains(_ other: SourceSpan) -> Bool {
        lowerBound <= other.lowerBound && other.upperBound <= upperBound
    }

    public static func < (lhs: SourceSpan, rhs: SourceSpan) -> Bool {
        (lhs.lowerBound, lhs.upperBound) < (rhs.lowerBound, rhs.upperBound)
    }
}

// MARK: - The document

/// The imported document in reading order, over one canonical text: the blocks joined by line breaks, the cells of a
/// block by tabs (ADR 0027). The canonical text is the source after the closed rules of normalisation, and nothing
/// else.
public struct SourceDocument: Hashable, Sendable {
    public let format: SourceFormat
    public let text: String
    public let blocks: [SourceBlock]
    private let scalars: [Unicode.Scalar]

    package init(format: SourceFormat, text: String, blocks: [SourceBlock]) {
        self.format = format
        self.text = text
        self.blocks = blocks
        self.scalars = Array(text.unicodeScalars)
    }

    /// The text of a span; empty when the span is outside the text.
    public func text(of span: SourceSpan) -> String {
        guard span.lowerBound >= 0, span.upperBound <= scalars.count else { return "" }
        var view = String.UnicodeScalarView()
        view.append(contentsOf: scalars[span.lowerBound..<span.upperBound])
        return String(view)
    }

    /// The texts of the spans, joined.
    public func text(of spans: [SourceSpan], joinedBy separator: String) -> String {
        spans.map { text(of: $0) }.joined(separator: separator)
    }

    /// The text of a block's cell.
    func text(ofCell cell: Int, in block: SourceBlock) -> String {
        guard block.cells.indices.contains(cell) else { return "" }
        return text(of: block.cells[cell])
    }

    var scalarCount: Int { scalars.count }
}

/// A block of the document: a line, a heading, a list item, or a row of cells, with what a PDF says of it.
public struct SourceBlock: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        /// A line of text.
        case line
        /// A heading marked as one by the source (Markdown's `#`), of this level.
        case heading(level: Int)
        /// An item of a list, its marker removed.
        case listItem
        /// The row of labels above a table.
        case tableHeader
    }

    /// The block's place in reading order.
    public let index: Int
    /// The whole block.
    public let span: SourceSpan
    /// Its cells: one for a line, several for a row of a table.
    public let cells: [SourceSpan]
    public let kind: Kind
    /// Bold, or larger than the body text, or a whole line in Markdown bold.
    public let isEmphasized: Bool
    /// A blank line, or a wider gap than between lines, comes before it.
    public let followsGap: Bool
    /// From a PDF: the page (from 1), the box, the column (0 for the main one) and the largest font size.
    public let page: Int?
    public let frame: Rect?
    public let column: Int?
    public let fontSize: Double?
    /// Written between a Markdown table's bars, so it belongs to a table and not to a line laid out in columns.
    public var isTableRow = false
    /// From a PDF: where the main text of the first cell starts and how large it is, which a date or another cell beside
    /// it, an icon before it or a small marker in it does not change. Nil when the PDF's cells are not the block's cells
    /// one by one, when the cell tells neither, or when the cell runs on a line in another size.
    public let firstCellLook: CellLook?

    /// Where the main text of a cell of a PDF starts, and its size: the size that holds most of the cell's letters and
    /// digits.
    public struct CellLook: Hashable, Sendable {
        public let x: Double
        public let fontSize: Double
    }
}
