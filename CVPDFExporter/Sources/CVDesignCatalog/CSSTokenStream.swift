import Foundation

/// The tokens of a stylesheet, read from a position that only moves forward.
struct CSSTokenStream {
    private let tokens: [CSSToken]
    private var position = 0

    init(_ tokens: [CSSToken]) { self.tokens = tokens }

    var isAtEnd: Bool { position >= tokens.count }

    var current: CSSToken? { peek() }

    func peek(_ offset: Int = 0) -> CSSToken? {
        let index = position + offset
        return index < tokens.count ? tokens[index] : nil
    }

    mutating func advance(_ count: Int = 1) { position += count }

    mutating func skipWhitespace() {
        while current == .whitespace { advance() }
    }
}
