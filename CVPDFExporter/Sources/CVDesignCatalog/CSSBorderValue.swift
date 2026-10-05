import Foundation

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
