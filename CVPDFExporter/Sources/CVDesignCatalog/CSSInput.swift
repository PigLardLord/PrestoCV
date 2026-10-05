import Foundation

/// The scalars of a stylesheet, read one at a time from a position that only moves forward.
struct CSSInput {
    private let scalars: [Unicode.Scalar]
    private var position = 0

    init(_ css: String) { scalars = Array(css.unicodeScalars) }

    var isAtEnd: Bool { position >= scalars.count }

    func peek(_ offset: Int = 0) -> Unicode.Scalar? {
        let index = position + offset
        return index < scalars.count ? scalars[index] : nil
    }

    func satisfies(_ condition: (Unicode.Scalar) -> Bool, at offset: Int = 0) -> Bool {
        peek(offset).map(condition) ?? false
    }

    func matches(_ text: String, at offset: Int = 0) -> Bool {
        text.unicodeScalars.enumerated().allSatisfy { peek(offset + $0.offset) == $0.element }
    }

    mutating func skip(_ count: Int = 1) { position += count }

    mutating func take(_ count: Int) -> String {
        let taken = String(String.UnicodeScalarView(scalars[position..<min(position + count, scalars.count)]))
        skip(count)
        return taken
    }

    mutating func take(while condition: (Unicode.Scalar) -> Bool) -> String {
        var taken = String.UnicodeScalarView()
        while let scalar = peek(), condition(scalar) {
            taken.append(scalar)
            skip()
        }
        return String(taken)
    }

    mutating func takeName() -> String { take(while: \.isCSSNameCharacter) }
}

extension Unicode.Scalar {
    var isCSSWhitespace: Bool { self == " " || self == "\t" || self == "\n" || self == "\r" || self == "\u{0C}" }
    var isCSSNewline: Bool { self == "\n" || self == "\r" }
    var isCSSDigit: Bool { ("0"..."9").contains(self) }
    var isCSSSign: Bool { self == "-" || self == "+" }
    var isCSSNameStart: Bool { ("a"..."z").contains(self) || ("A"..."Z").contains(self) || self == "_" }
    var isCSSNameCharacter: Bool { isCSSNameStart || isCSSDigit || self == "-" }
}
