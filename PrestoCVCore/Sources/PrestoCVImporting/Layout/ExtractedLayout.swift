// MARK: - What a reader saw

/// What a reader of one form of document saw, before the core decides the reading order (ADR 0027). It is the only
/// input of the page analysis, and untrusted (R8): `ImportCV` bounds it before it is read.
public enum ExtractedLayout: Hashable, Sendable, Codable {
    /// The lines of a text without geometry: pasted text, or a plain-text file.
    case text(lines: [String])
    /// The pages of a document with geometry, such as a PDF's.
    case pages([ExtractedPage])
}

/// One page as a reader saw it: its words, in the reader's order, each with its box and style.
public struct ExtractedPage: Hashable, Sendable, Codable {
    /// Width and height in points.
    public let width: Double
    public let height: Double
    public let words: [ExtractedWord]

    public init(width: Double, height: Double, words: [ExtractedWord]) {
        self.width = width
        self.height = height
        self.words = words
    }
}

/// A word, or a run of characters without white space, with its box in page space (origin at the top left, y growing
/// downwards) and its style.
public struct ExtractedWord: Hashable, Sendable, Codable {
    public let text: String
    public let frame: Rect
    public let fontSize: Double
    public let isBold: Bool

    public init(text: String, frame: Rect, fontSize: Double, isBold: Bool) {
        self.text = text
        self.frame = frame
        self.fontSize = fontSize
        self.isBold = isBold
    }
}

/// A rectangle in page space, origin at the top left.
public struct Rect: Hashable, Sendable, Codable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var maxX: Double { x + width }
    public var maxY: Double { y + height }
    public var midY: Double { y + height / 2 }

    /// The smallest rectangle that holds both.
    func union(_ other: Rect) -> Rect {
        let minX = Swift.min(x, other.x), minY = Swift.min(y, other.y)
        return Rect(x: minX, y: minY, width: Swift.max(maxX, other.maxX) - minX, height: Swift.max(maxY, other.maxY) - minY)
    }
}

/// The form a document came in.
public enum SourceFormat: String, Hashable, Sendable, Codable {
    case pastedText
    case pdf
}
