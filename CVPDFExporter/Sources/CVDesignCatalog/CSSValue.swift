import Foundation

/// The checks a property's value goes through. Each takes the tokens of a value and returns its canonical text, or
/// refuses it.
enum CSSValue {
    typealias Check = @Sendable ([CSSToken]) throws(CSSRejection) -> String

    static let colorVariables: Set<String> = ["--color-text", "--color-primary"]
    static let paletteColor: Check = variable(colorVariables)

    static func keyword(_ allowed: Set<String>) -> Check {
        { (tokens: [CSSToken]) throws(CSSRejection) -> String in
            guard let word = lowercasedKeyword(in: tokens, from: allowed) else { throw CSSRejection(reason: "value not allowed") }
            return word
        }
    }

    static func variable(_ allowed: Set<String>, orKeywords keywords: Set<String> = []) -> Check {
        { (tokens: [CSSToken]) throws(CSSRejection) -> String in
            if let word = lowercasedKeyword(in: tokens, from: keywords) { return word }
            guard tokens.count == 3, tokens[0] == .function("var"), case .ident(let name) = tokens[1], allowed.contains(name), tokens[2] == .rparen else {
                throw CSSRejection(reason: "only \(allowed.sorted()) are allowed here")
            }
            return "var(\(name))"
        }
    }

    static func lengths(_ bounds: LengthBounds, count: ClosedRange<Int>) -> Check {
        { (tokens: [CSSToken]) throws(CSSRejection) -> String in
            guard count.contains(tokens.count) else { throw CSSRejection(reason: "wrong number of values") }
            var lengths: [String] = []
            for token in tokens { lengths.append(try bounds.canonicalLength(of: token)) }
            return lengths.joined(separator: " ")
        }
    }

    static func number(_ range: ClosedRange<Double>, keywords: Set<String> = []) -> Check {
        { (tokens: [CSSToken]) throws(CSSRejection) -> String in
            if let word = lowercasedKeyword(in: tokens, from: keywords) { return word }
            guard tokens.count == 1, case .number(let value) = tokens[0], range.contains(value) else { throw CSSRejection(reason: "number out of bounds") }
            return canonicalNumber(value)
        }
    }

    /// `gap: <row> <column>` or `gap: <both>`: the column component is bounded like `column-gap`.
    static let gap: Check = { (tokens: [CSSToken]) throws(CSSRejection) -> String in
        switch tokens.count {
        case 1: return try LengthBounds.columnGap.canonicalLength(of: tokens[0])
        case 2: return try LengthBounds.spacing.canonicalLength(of: tokens[0]) + " " + LengthBounds.columnGap.canonicalLength(of: tokens[1])
        default: throw CSSRejection(reason: "gap takes 1 or 2 lengths")
        }
    }

    static func border(styles: Set<String>) -> Check {
        BorderValue(styles: styles).canonical
    }

    static let gridColumns: Check = { (tokens: [CSSToken]) throws(CSSRejection) -> String in
        guard (1...4).contains(tokens.count) else { throw CSSRejection(reason: "1 to 4 grid tracks") }
        var tracks: [String] = []
        for token in tokens { tracks.append(try gridTrack(token)) }
        return tracks.joined(separator: " ")
    }

    private static func gridTrack(_ token: CSSToken) throws(CSSRejection) -> String {
        if case .dimension(let value, "fr") = token, (0.1...10).contains(value) { return canonicalNumber(value) + "fr" }
        return try LengthBounds.extent.canonicalLength(of: token)
    }

    /// The lower-cased keyword that `tokens` consist of, when it is one of `allowed`.
    static func lowercasedKeyword(in tokens: [CSSToken], from allowed: Set<String>) -> String? {
        guard tokens.count == 1, case .ident(let word) = tokens[0], allowed.contains(word.lowercased()) else { return nil }
        return word.lowercased()
    }
}

/// The value of `border` and its sides: a width, a style keyword and a palette colour, in any order.
struct BorderValue: Sendable {
    let styles: Set<String>

    private struct Parts {
        var width: String?, style: String?, color: String?
    }

    func canonical(_ tokens: [CSSToken]) throws(CSSRejection) -> String {
        var parts = Parts()
        for part in Self.split(tokens) { try add(part, to: &parts) }
        return [parts.width, parts.style, parts.color].compactMap { $0 }.joined(separator: " ")
    }

    /// A `var(--name)` call is one part of three tokens; any other token is a part of its own.
    private static func split(_ tokens: [CSSToken]) -> [[CSSToken]] {
        var parts: [[CSSToken]] = []
        var start = tokens.startIndex
        while start < tokens.endIndex {
            let callsVariable = tokens[start] == .function("var") && start + 2 < tokens.endIndex
            let end = start + (callsVariable ? 3 : 1)
            parts.append(Array(tokens[start..<end]))
            start = end
        }
        return parts
    }

    private func add(_ part: [CSSToken], to parts: inout Parts) throws(CSSRejection) {
        if parts.style == nil, let style = CSSValue.lowercasedKeyword(in: part, from: styles) {
            parts.style = style
        } else if part.count == 3 {
            parts.color = try CSSValue.paletteColor(part)
        } else if parts.width == nil {
            parts.width = try LengthBounds.borderWidth.canonicalLength(of: part[0])
        } else {
            throw CSSRejection(reason: "border value not allowed")
        }
    }
}
