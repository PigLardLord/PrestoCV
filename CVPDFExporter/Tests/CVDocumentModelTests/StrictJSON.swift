import Foundation

/// A check that bytes are JSON as RFC 8259 defines it and that no object repeats a key. `JSONDecoder` keeps the first of
/// two equal keys and accepts a trailing comma and a byte order mark, which other readers do not, so the committed schema
/// is held to this stricter reading before it is parsed.
enum StrictJSON {
    struct Problem: Error, CustomStringConvertible {
        let description: String
    }

    /// Throws a `Problem` that names the first defect of `data`.
    static func check(_ data: Data) throws {
        var scanner = TokenScanner(bytes: Array(data))
        try scanner.scanDocument()
    }
}

private struct TokenScanner {
    let bytes: [UInt8]
    var position = 0

    init(bytes: [UInt8]) { self.bytes = bytes }

    mutating func scanDocument() throws {
        guard !bytes.starts(with: [0xEF, 0xBB, 0xBF]) else { throw problem("the file starts with a byte order mark") }
        guard String(validating: bytes, as: UTF8.self) != nil else { throw problem("the file is not valid UTF-8") }
        skipWhitespace()
        try scanValue()
        skipWhitespace()
        guard position == bytes.count else { throw problem("content after the value") }
    }

    // MARK: Values

    private mutating func scanValue() throws {
        guard let byte = peek() else { throw problem("the value is missing") }
        switch byte {
        case UInt8(ascii: "{"): try scanObject()
        case UInt8(ascii: "["): try scanArray()
        case UInt8(ascii: "\""): _ = try scanString()
        case UInt8(ascii: "t"): try scanWord("true")
        case UInt8(ascii: "f"): try scanWord("false")
        case UInt8(ascii: "n"): try scanWord("null")
        case UInt8(ascii: "-"), UInt8(ascii: "0")...UInt8(ascii: "9"): try scanNumber()
        default: throw problem("unexpected character \(describe(byte))")
        }
    }

    private mutating func scanObject() throws {
        position += 1
        skipWhitespace()
        if peek() == UInt8(ascii: "}") { position += 1; return }
        var keys: Set<[UInt8]> = []
        while true {
            skipWhitespace()
            guard peek() == UInt8(ascii: "\"") else { throw problem("an object member must start with a key") }
            let keyStart = position
            let key = try scanString()
            guard keys.insert(key).inserted else { throw problem("duplicate key \"\(String(decoding: key, as: UTF8.self))\"", at: keyStart) }
            skipWhitespace()
            try expect(UInt8(ascii: ":"), "a colon after the key")
            skipWhitespace()
            try scanValue()
            skipWhitespace()
            if try endOfList(closing: UInt8(ascii: "}")) { return }
        }
    }

    private mutating func scanArray() throws {
        position += 1
        skipWhitespace()
        if peek() == UInt8(ascii: "]") { position += 1; return }
        while true {
            skipWhitespace()
            try scanValue()
            skipWhitespace()
            if try endOfList(closing: UInt8(ascii: "]")) { return }
        }
    }

    /// After a member or an element: true at the closing byte, false after a comma that is followed by another entry.
    private mutating func endOfList(closing: UInt8) throws -> Bool {
        switch peek() {
        case closing:
            position += 1
            return true
        case UInt8(ascii: ","):
            let comma = position
            position += 1
            skipWhitespace()
            if peek() == closing { throw problem("a trailing comma", at: comma) }
            return false
        default:
            throw problem("a comma or the end of the list was expected")
        }
    }

    // MARK: Strings, numbers and words

    /// Reads a string and returns its UTF-8 bytes with the escapes resolved, so that two spellings of one key compare equal.
    private mutating func scanString() throws -> [UInt8] {
        position += 1
        var resolved: [UInt8] = []
        while true {
            guard let byte = peek() else { throw problem("a string is not closed") }
            position += 1
            switch byte {
            case UInt8(ascii: "\""):
                return resolved
            case 0..<0x20:
                throw problem("a control character inside a string", at: position - 1)
            case UInt8(ascii: "\\"):
                resolved += try scanEscape()
            default:
                resolved.append(byte)
            }
        }
    }

    private mutating func scanEscape() throws -> [UInt8] {
        guard let byte = peek() else { throw problem("an escape is not finished") }
        position += 1
        switch byte {
        case UInt8(ascii: "\""): return [0x22]
        case UInt8(ascii: "\\"): return [0x5C]
        case UInt8(ascii: "/"): return [0x2F]
        case UInt8(ascii: "b"): return [0x08]
        case UInt8(ascii: "f"): return [0x0C]
        case UInt8(ascii: "n"): return [0x0A]
        case UInt8(ascii: "r"): return [0x0D]
        case UInt8(ascii: "t"): return [0x09]
        case UInt8(ascii: "u"): return try scanUnicodeEscape()
        default: throw problem("an unknown escape", at: position - 1)
        }
    }

    private mutating func scanUnicodeEscape() throws -> [UInt8] {
        let first = try scanHexUnit()
        var scalarValue = first
        if (0xD800...0xDBFF).contains(first) {
            guard peek() == UInt8(ascii: "\\"), peek(1) == UInt8(ascii: "u") else { throw problem("a lone surrogate") }
            position += 2
            let second = try scanHexUnit()
            guard (0xDC00...0xDFFF).contains(second) else { throw problem("a lone surrogate") }
            scalarValue = 0x10000 + ((first - 0xD800) << 10) + (second - 0xDC00)
        } else if (0xDC00...0xDFFF).contains(first) {
            throw problem("a lone surrogate")
        }
        guard let scalar = Unicode.Scalar(scalarValue) else { throw problem("an escape that is not a character") }
        return Array(String(Character(scalar)).utf8)
    }

    private mutating func scanHexUnit() throws -> UInt32 {
        var unit: UInt32 = 0
        for _ in 0..<4 {
            guard let byte = peek(), let digit = Character(UnicodeScalar(byte)).hexDigitValue else { throw problem("an escape needs four hexadecimal digits") }
            unit = unit << 4 + UInt32(digit)
            position += 1
        }
        return unit
    }

    private mutating func scanNumber() throws {
        if peek() == UInt8(ascii: "-") { position += 1 }
        guard let first = peek(), isDigit(first) else { throw problem("a number needs digits") }
        if first == UInt8(ascii: "0") { position += 1 } else { skipDigits() }
        if peek() == UInt8(ascii: ".") {
            position += 1
            guard isDigit(peek()) else { throw problem("a number needs digits after the point") }
            skipDigits()
        }
        if peek() == UInt8(ascii: "e") || peek() == UInt8(ascii: "E") {
            position += 1
            if peek() == UInt8(ascii: "+") || peek() == UInt8(ascii: "-") { position += 1 }
            guard isDigit(peek()) else { throw problem("a number needs digits in its exponent") }
            skipDigits()
        }
    }

    private mutating func scanWord(_ word: String) throws {
        guard bytes[position...].starts(with: Array(word.utf8)) else { throw problem("expected \(word)") }
        position += word.utf8.count
    }

    // MARK: Reading

    private func peek(_ offset: Int = 0) -> UInt8? { position + offset < bytes.count ? bytes[position + offset] : nil }

    private func isDigit(_ byte: UInt8?) -> Bool { byte.map { (UInt8(ascii: "0")...UInt8(ascii: "9")).contains($0) } ?? false }

    private mutating func skipDigits() {
        while isDigit(peek()) { position += 1 }
    }

    private mutating func skipWhitespace() {
        while let byte = peek(), byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D { position += 1 }
    }

    private mutating func expect(_ byte: UInt8, _ what: String) throws {
        guard peek() == byte else { throw problem(what + " was expected") }
        position += 1
    }

    private func describe(_ byte: UInt8) -> String { byte < 0x20 || byte > 0x7E ? "0x" + String(byte, radix: 16) : "'\(Character(UnicodeScalar(byte)))'" }

    private func problem(_ message: String, at offset: Int? = nil) -> StrictJSON.Problem {
        StrictJSON.Problem(description: "\(message) at byte \(offset ?? position)")
    }
}
