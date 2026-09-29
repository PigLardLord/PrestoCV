import Foundation

/// Design CSS is parsed into tokens, checked against an allow-list and re-serialised from the tokens
/// (ADR 0011, R8). What is validated is exactly what is emitted: comments, strings and anything the
/// allow-list does not name cannot reach the document.
public struct CSSRejection: Error, Equatable, Sendable, CustomStringConvertible {
    public let reason: String
    public var description: String { reason }
}

enum CSSToken: Equatable, Sendable {
    case ident(String), function(String), atKeyword(String), hash(String), string(String)
    case number(Double), percentage(Double), dimension(Double, String)
    case colon, semicolon, comma, lbrace, rbrace, lparen, rparen, lbracket, rbracket
    case delim(Unicode.Scalar), whitespace
}

// MARK: - Tokenizer (subset of CSS Syntax 3; anything outside it is rejected)

enum CSSTokenizer {
    static func tokenize(_ css: String) throws(CSSRejection) -> [CSSToken] {
        let s = Array(css.unicodeScalars)
        // Checked on the raw text, before anything else: comments and strings included.
        if s.contains("<") { throw CSSRejection(reason: "'<' is not allowed (closes <style>)") }
        if s.contains("\\") { throw CSSRejection(reason: "CSS escapes are not allowed") }
        var tokens: [CSSToken] = []
        var i = 0
        func at(_ k: Int) -> Unicode.Scalar? { k < s.count ? s[k] : nil }
        func isNameStart(_ c: Unicode.Scalar?) -> Bool { guard let c else { return false }; return ("a"..."z").contains(c) || ("A"..."Z").contains(c) || c == "_" }
        func isName(_ c: Unicode.Scalar?) -> Bool { guard let c else { return false }; return isNameStart(c) || ("0"..."9").contains(c) || c == "-" }
        func isDigit(_ c: Unicode.Scalar?) -> Bool { guard let c else { return false }; return ("0"..."9").contains(c) }
        func name() -> String { var n = String.UnicodeScalarView(); while isName(at(i)) { n.append(s[i]); i += 1 }; return String(n) }

        while i < s.count {
            let c = s[i]
            if c == " " || c == "\t" || c == "\n" || c == "\r" || c == "\u{0C}" {
                while let w = at(i), w == " " || w == "\t" || w == "\n" || w == "\r" || w == "\u{0C}" { i += 1 }
                if tokens.last != .whitespace { tokens.append(.whitespace) }
            } else if c == "/", at(i + 1) == "*" {
                i += 2
                while i < s.count, !(s[i] == "*" && at(i + 1) == "/") { i += 1 }
                guard i < s.count else { throw CSSRejection(reason: "unterminated comment") }
                i += 2
            } else if c == "\"" || c == "'" {
                i += 1
                var v = String.UnicodeScalarView()
                while let d = at(i), d != c {
                    if d == "\n" || d == "\r" { throw CSSRejection(reason: "newline in string") }
                    v.append(d); i += 1
                }
                guard at(i) == c else { throw CSSRejection(reason: "unterminated string") }
                i += 1; tokens.append(.string(String(v)))
            } else if c.value > 0x7E || (c.value < 0x20) {
                throw CSSRejection(reason: "non-ASCII or control character outside comments")
            } else if isDigit(c) || (c == "." && isDigit(at(i + 1))) || ((c == "-" || c == "+") && (isDigit(at(i + 1)) || (at(i + 1) == "." && isDigit(at(i + 2))))) {
                var n = String.UnicodeScalarView()
                if c == "-" || c == "+" { n.append(c); i += 1 }
                var integerDigits = 0, seenPoint = false
                while isDigit(at(i)) || (at(i) == "." && isDigit(at(i + 1)) && !seenPoint) {
                    if s[i] == "." { seenPoint = true } else if !seenPoint { integerDigits += 1 }
                    n.append(s[i]); i += 1
                }
                guard integerDigits <= 9, n.count <= 16, let value = Double(String(n)) else { throw CSSRejection(reason: "number out of range") }
                if at(i) == "%" { i += 1; tokens.append(.percentage(value)) }
                else if isNameStart(at(i)) { tokens.append(.dimension(value, name().lowercased())) }
                else { tokens.append(.number(value)) }
            } else if isNameStart(c) || (c == "-" && (isNameStart(at(i + 1)) || at(i + 1) == "-")) {
                let n = name()
                if at(i) == "(" { i += 1; tokens.append(.function(n.lowercased())) } else { tokens.append(.ident(n)) }
            } else if c == "@" {
                i += 1; tokens.append(.atKeyword(name().lowercased()))
            } else if c == "#" {
                i += 1; tokens.append(.hash(name()))
            } else {
                i += 1
                switch c {
                case ":": tokens.append(.colon)
                case ";": tokens.append(.semicolon)
                case ",": tokens.append(.comma)
                case "{": tokens.append(.lbrace)
                case "}": tokens.append(.rbrace)
                case "(": tokens.append(.lparen)
                case ")": tokens.append(.rparen)
                case "[": tokens.append(.lbracket)
                case "]": tokens.append(.rbracket)
                default: tokens.append(.delim(c))
                }
            }
        }
        return tokens
    }
}

// MARK: - Values

enum Unit { case pt, em, percent, fr }

/// Bounds are what a CV design plausibly needs; anything outside them can hide or displace content.
/// `relativeUnits: false` accepts only pt and px. em and % compound through nesting (60% of 60% of …), and rem
/// depends on the root's size; an absolute unit is the only way a floor holds whatever the rest of the stylesheet does.
struct LengthBounds { let pt: ClosedRange<Double>; let em: ClosedRange<Double>; let percent: ClosedRange<Double>?; var relativeUnits = true }

/// Formats a number that the caller has already bounded. Values outside ±1e9 never reach here: the
/// tokenizer rejects numbers with more than 9 digits before the point (review: Int(Double) overflow trap).
private func fmt(_ d: Double) -> String {
    let r = (d * 1000).rounded() / 1000
    guard r.magnitude < 1e9 else { return "0" }
    return r == r.rounded() ? String(Int(r)) : String(r)
}

enum CSSValue {
    typealias Check = @Sendable ([CSSToken]) throws(CSSRejection) -> String

    static func keyword(_ allowed: Set<String>) -> Check {
        { (t: [CSSToken]) throws(CSSRejection) -> String in
            guard t.count == 1, case .ident(let k) = t[0], allowed.contains(k.lowercased()) else { throw CSSRejection(reason: "value not allowed") }
            return k.lowercased()
        }
    }

    static func variable(_ allowed: Set<String>, orKeywords keywords: Set<String> = []) -> Check {
        { (t: [CSSToken]) throws(CSSRejection) -> String in
            if t.count == 1, case .ident(let k) = t[0], keywords.contains(k.lowercased()) { return k.lowercased() }
            guard t.count == 3, t[0] == .function("var"), case .ident(let v) = t[1], allowed.contains(v), t[2] == .rparen else {
                throw CSSRejection(reason: "only \(allowed.sorted()) are allowed here")
            }
            return "var(\(v))"
        }
    }

    static func length(_ token: CSSToken, _ b: LengthBounds) throws(CSSRejection) -> String {
        switch token {
        case .number(0) where b.pt.contains(0): return "0"      // a bare 0 only where zero is allowed (not font-size)
        case .dimension(let v, "pt") where b.pt.contains(v): return "\(fmt(v))pt"
        case .dimension(let v, "px") where b.pt.contains(v * 0.75): return "\(fmt(v))px"
        case .dimension(let v, let u) where (u == "em" || u == "rem") && b.relativeUnits && b.em.contains(v): return "\(fmt(v))\(u)"
        case .percentage(let v) where b.relativeUnits && b.percent?.contains(v) == true: return "\(fmt(v))%"
        default: throw CSSRejection(reason: "length out of bounds or unit not allowed")
        }
    }

    static func lengths(_ b: LengthBounds, count: ClosedRange<Int>) -> Check {
        { (t: [CSSToken]) throws(CSSRejection) -> String in
            guard count.contains(t.count) else { throw CSSRejection(reason: "wrong number of values") }
            var out: [String] = []
            for token in t { out.append(try length(token, b)) }
            return out.joined(separator: " ")
        }
    }

    static func number(_ range: ClosedRange<Double>, keywords: Set<String> = []) -> Check {
        { (t: [CSSToken]) throws(CSSRejection) -> String in
            if t.count == 1, case .ident(let k) = t[0], keywords.contains(k.lowercased()) { return k.lowercased() }
            guard t.count == 1, case .number(let v) = t[0], range.contains(v) else { throw CSSRejection(reason: "number out of bounds") }
            return fmt(v)
        }
    }

    static let colorVars: Set<String> = ["--color-text", "--color-primary"]
    static let fontSize = LengthBounds(pt: 7...48, em: 0.6...4, percent: nil, relativeUnits: false)
    static let spacing = LengthBounds(pt: 0...48, em: 0...4, percent: nil)
    static let borderWidth = LengthBounds(pt: 0...4, em: 0...0.3, percent: nil)
    /// Flex and grid drop the space between inline entries, so their column gap must replace it.
    static let columnGap = LengthBounds(pt: 3...48, em: 0.25...4, percent: nil)

    /// `gap: <row> <column>` or `gap: <both>`: the column component is bounded like `column-gap`.
    static let gap: Check = { (t: [CSSToken]) throws(CSSRejection) -> String in
        switch t.count {
        case 1: return try length(t[0], columnGap)
        case 2: return try length(t[0], spacing) + " " + length(t[1], columnGap)
        default: throw CSSRejection(reason: "gap takes 1 or 2 lengths")
        }
    }

    static func border(styles: Set<String>) -> Check {
        { (t: [CSSToken]) throws(CSSRejection) -> String in
            var width: String?, style: String?, color: String?
            var i = 0
            while i < t.count {
                if case .ident(let k) = t[i], styles.contains(k.lowercased()), style == nil { style = k.lowercased(); i += 1; continue }
                if t[i] == .function("var"), i + 2 < t.count { color = try variable(colorVars)(Array(t[i...(i + 2)])); i += 3; continue }
                if width == nil { width = try length(t[i], borderWidth); i += 1; continue }
                throw CSSRejection(reason: "border value not allowed")
            }
            return [width, style, color].compactMap { $0 }.joined(separator: " ")
        }
    }

    static let gridColumns: Check = { (t: [CSSToken]) throws(CSSRejection) -> String in
        guard (1...4).contains(t.count) else { throw CSSRejection(reason: "1 to 4 grid tracks") }
        var out: [String] = []
        for token in t {
            if case .dimension(let v, "fr") = token, (0.1...10).contains(v) { out.append("\(fmt(v))fr") }
            else { out.append(try length(token, LengthBounds(pt: 36...600, em: 3...40, percent: 10...100))) }
        }
        return out.joined(separator: " ")
    }
}

/// The keywords each property accepts, in one place. markup-contract.md lists the same sets and a test compares
/// them (#83), so the policy cannot accept a keyword the page does not document.
let propertyKeywords: [String: Set<String>] = {
    let borderStyles: Set<String> = ["solid", "dashed", "dotted", "none"]
    return [
        "background-color": ["transparent"],
        "font-weight": ["normal", "bold"],
        "font-style": ["normal", "italic"],
        "line-height": ["normal"],
        "text-transform": ["none", "uppercase", "lowercase", "capitalize"],
        "text-align": ["left", "right", "center", "justify", "start", "end"],
        "text-decoration": ["none", "underline"],
        "border": borderStyles, "border-top": borderStyles, "border-bottom": borderStyles, "border-left": borderStyles, "border-right": borderStyles,
        "display": ["block", "inline", "inline-block", "flex", "inline-flex", "grid"],
        "flex-direction": ["row", "column"],
        "flex-wrap": ["wrap", "nowrap"],
        "justify-content": ["flex-start", "flex-end", "center", "space-between", "space-around", "start", "end"],
        "align-items": ["flex-start", "flex-end", "center", "baseline", "stretch", "start", "end"],
        "break-inside": ["auto", "avoid"], "page-break-inside": ["auto", "avoid"],
        "break-before": ["auto", "page", "avoid"], "break-after": ["auto", "page", "avoid"],
    ]
}()

private func keywordsOf(_ property: String) -> Set<String> { propertyKeywords[property, default: []] }

/// The allow-list. Properties not listed here are rejected, which excludes by construction everything
/// that can load resources, hide, move, reorder or inject content (position, transform, zoom, filter,
/// mask, clip, overflow, visibility, opacity, content, list-style, quotes, counters, direction, order…).
let allowedProperties: [String: CSSValue.Check] = [
    "color": CSSValue.variable(CSSValue.colorVars),
    "background-color": CSSValue.variable(["--color-background"], orKeywords: keywordsOf("background-color")),
    "border-color": CSSValue.variable(CSSValue.colorVars),
    "font-family": CSSValue.variable(["--font-body", "--font-heading"]),
    "font-size": CSSValue.lengths(CSSValue.fontSize, count: 1...1),
    "font-weight": CSSValue.number(100...900, keywords: keywordsOf("font-weight")),
    "font-style": CSSValue.keyword(keywordsOf("font-style")),
    "line-height": CSSValue.number(1...3, keywords: keywordsOf("line-height")),
    "letter-spacing": CSSValue.lengths(LengthBounds(pt: 0...3, em: 0...0.3, percent: nil), count: 1...1),
    "text-transform": CSSValue.keyword(keywordsOf("text-transform")),
    "text-align": CSSValue.keyword(keywordsOf("text-align")),
    "text-decoration": CSSValue.keyword(keywordsOf("text-decoration")),
    "margin": CSSValue.lengths(CSSValue.spacing, count: 1...4),
    "margin-top": CSSValue.lengths(CSSValue.spacing, count: 1...1),
    "margin-bottom": CSSValue.lengths(CSSValue.spacing, count: 1...1),
    "margin-left": CSSValue.lengths(CSSValue.spacing, count: 1...1),
    "margin-right": CSSValue.lengths(CSSValue.spacing, count: 1...1),
    "padding": CSSValue.lengths(CSSValue.spacing, count: 1...4),
    "padding-top": CSSValue.lengths(CSSValue.spacing, count: 1...1),
    "padding-bottom": CSSValue.lengths(CSSValue.spacing, count: 1...1),
    "padding-left": CSSValue.lengths(CSSValue.spacing, count: 1...1),
    "padding-right": CSSValue.lengths(CSSValue.spacing, count: 1...1),
    "border": CSSValue.border(styles: keywordsOf("border")), "border-top": CSSValue.border(styles: keywordsOf("border-top")),
    "border-bottom": CSSValue.border(styles: keywordsOf("border-bottom")), "border-left": CSSValue.border(styles: keywordsOf("border-left")),
    "border-right": CSSValue.border(styles: keywordsOf("border-right")),
    "border-radius": CSSValue.lengths(LengthBounds(pt: 0...16, em: 0...1, percent: nil), count: 1...1),
    "display": CSSValue.keyword(keywordsOf("display")),
    "flex-direction": CSSValue.keyword(keywordsOf("flex-direction")),
    "flex-wrap": CSSValue.keyword(keywordsOf("flex-wrap")),
    "flex": CSSValue.number(0...10),
    "justify-content": CSSValue.keyword(keywordsOf("justify-content")),
    "align-items": CSSValue.keyword(keywordsOf("align-items")),
    "gap": CSSValue.gap,
    "row-gap": CSSValue.lengths(CSSValue.spacing, count: 1...1),
    "column-gap": CSSValue.lengths(CSSValue.columnGap, count: 1...1),
    "grid-template-columns": CSSValue.gridColumns,
    "width": CSSValue.lengths(LengthBounds(pt: 36...600, em: 3...40, percent: 10...100), count: 1...1),
    "max-width": CSSValue.lengths(LengthBounds(pt: 36...600, em: 3...40, percent: 10...100), count: 1...1),
    "break-inside": CSSValue.keyword(keywordsOf("break-inside")),
    "page-break-inside": CSSValue.keyword(keywordsOf("page-break-inside")),
    "break-before": CSSValue.keyword(keywordsOf("break-before")),
    "break-after": CSSValue.keyword(keywordsOf("break-after")),
]

// MARK: - Parser + serializer

struct CSSParser {
    var t: [CSSToken]
    var i = 0

    mutating func skipWS() { while i < t.count, t[i] == .whitespace { i += 1 } }

    /// stylesheet := (rule | @media ident { rule* })*
    mutating func stylesheet() throws(CSSRejection) -> String {
        var out: [String] = []
        skipWS()
        while i < t.count {
            if case .atKeyword(let k) = t[i] {
                guard k == "media" else { throw CSSRejection(reason: "@\(k) is not allowed") }
                i += 1; skipWS()
                guard i < t.count, case .ident(let q) = t[i], ["print", "screen", "all"].contains(q.lowercased()) else {
                    throw CSSRejection(reason: "only @media print, screen or all")
                }
                i += 1; skipWS()
                guard i < t.count, t[i] == .lbrace else { throw CSSRejection(reason: "expected {") }
                i += 1; skipWS()
                var inner: [String] = []
                while i < t.count, t[i] != .rbrace { inner.append(try rule()); skipWS() }
                guard i < t.count else { throw CSSRejection(reason: "unterminated @media") }
                i += 1
                out.append("@media \(q.lowercased()){\(inner.joined())}")
            } else {
                out.append(try rule())
            }
            skipWS()
        }
        return out.joined()
    }

    mutating func rule() throws(CSSRejection) -> String {
        var prelude: [CSSToken] = []
        while i < t.count, t[i] != .lbrace {
            if t[i] == .rbrace || t[i] == .semicolon { throw CSSRejection(reason: "unexpected token in selector") }
            prelude.append(t[i]); i += 1
        }
        guard i < t.count else { throw CSSRejection(reason: "expected {") }
        i += 1
        var body: [CSSToken] = []
        while i < t.count, t[i] != .rbrace {
            if t[i] == .lbrace { throw CSSRejection(reason: "nested rules are not allowed") }
            body.append(t[i]); i += 1
        }
        guard i < t.count else { throw CSSRejection(reason: "unterminated rule") }
        i += 1
        return "\(try Self.selectorList(prelude)){\(try Self.declarations(body))}"
    }

    static func selectorList(_ tokens: [CSSToken]) throws(CSSRejection) -> String {
        var parts: [[CSSToken]] = [[]]
        for token in tokens { if token == .comma { parts.append([]) } else { parts[parts.count - 1].append(token) } }
        var out: [String] = []
        for p in parts { out.append(try selector(p)) }
        return out.joined(separator: ",")
    }

    /// Compound selectors of contract elements, classes, [data-section=…], [data-rating=…] and a few
    /// structural pseudo-classes, joined by descendant, >, + or ~. No ids, no pseudo-elements, no functions.
    static func selector(_ raw: [CSSToken]) throws(CSSRejection) -> String {
        var tokens = raw
        while tokens.first == .whitespace { tokens.removeFirst() }
        while tokens.last == .whitespace { tokens.removeLast() }
        guard !tokens.isEmpty else { throw CSSRejection(reason: "empty selector") }
        var out = "", i = 0, needsCompound = true
        while i < tokens.count {
            switch tokens[i] {
            case .whitespace, .delim(">"), .delim("+"), .delim("~"):
                var combinator = " "
                while i < tokens.count, [.whitespace, .delim(">"), .delim("+"), .delim("~")].contains(tokens[i]) {
                    if case .delim(let d) = tokens[i] {
                        guard combinator == " " else { throw CSSRejection(reason: "double combinator") }
                        combinator = String(d)
                    }
                    i += 1
                }
                guard !needsCompound else { throw CSSRejection(reason: "dangling combinator") }
                out += combinator == " " ? " " : combinator
                needsCompound = true
            case .ident(let e):
                guard MarkupContract.elements.contains(e.lowercased()) else { throw CSSRejection(reason: "element \(e) is not in the markup contract") }
                out += e.lowercased(); i += 1; needsCompound = false
            case .delim("*"):
                // Not in the markup contract: it also selects the document root, which sets what rem means.
                throw CSSRejection(reason: "the universal selector is not allowed")
            case .delim("."):
                guard i + 1 < tokens.count, case .ident(let c) = tokens[i + 1], MarkupContract.classes.contains(c) else {
                    throw CSSRejection(reason: "class is not in the markup contract")
                }
                out += ".\(c)"; i += 2; needsCompound = false
            case .lbracket:
                guard i + 4 < tokens.count, case .ident(let a) = tokens[i + 1], tokens[i + 2] == .delim("="), tokens[i + 4] == .rbracket else {
                    throw CSSRejection(reason: "attribute selector not allowed")
                }
                let value: String
                switch tokens[i + 3] {
                case .string(let v), .ident(let v): value = v
                case .number(let n): value = fmt(n)
                default: throw CSSRejection(reason: "attribute value not allowed")
                }
                let ok = (a == "data-section" && MarkupContract.sectionKinds.contains(value)) || (a == "data-rating" && MarkupContract.ratings.contains(value))
                guard ok else { throw CSSRejection(reason: "attribute selector not in the markup contract") }
                out += "[\(a)=\"\(value)\"]"; i += 5; needsCompound = false
            case .colon:
                guard i + 1 < tokens.count, case .ident(let p) = tokens[i + 1], MarkupContract.pseudoClasses.contains(p.lowercased()) else {
                    throw CSSRejection(reason: "pseudo-class or pseudo-element not allowed")
                }
                out += ":\(p.lowercased())"; i += 2; needsCompound = false
            default:
                throw CSSRejection(reason: "selector token not allowed")
            }
        }
        guard !needsCompound else { throw CSSRejection(reason: "dangling combinator") }
        return out
    }

    static func declarations(_ tokens: [CSSToken]) throws(CSSRejection) -> String {
        var decls: [[CSSToken]] = [[]]
        for token in tokens { if token == .semicolon { decls.append([]) } else { decls[decls.count - 1].append(token) } }
        var out: [String] = []
        for d in decls {
            let parts = d.filter { $0 != .whitespace }
            if parts.isEmpty { continue }
            guard parts.count >= 3, case .ident(let rawName) = parts[0], parts[1] == .colon else { throw CSSRejection(reason: "malformed declaration") }
            let name = rawName.lowercased()
            if parts.contains(.delim("!")) { throw CSSRejection(reason: "!important is not allowed") }
            guard let check = allowedProperties[name] else { throw CSSRejection(reason: "property \(name) is not allowed") }
            out.append("\(name):\(try check(Array(parts.dropFirst(2))))")
        }
        // Inline entries are separated by a space in the markup, which flex and grid do not render: a rule that
        // makes a flex or grid container must also set the column gap that keeps the entries apart.
        if out.contains(where: { ["display:flex", "display:inline-flex", "display:grid"].contains($0) }),
           !out.contains(where: { $0.hasPrefix("gap:") || $0.hasPrefix("column-gap:") }) {
            throw CSSRejection(reason: "a flex or grid container must set gap or column-gap (at least 3pt)")
        }
        return out.joined(separator: ";")
    }
}

enum CSSPolicy {
    /// Returns the canonical re-serialisation of an allowed stylesheet, or the first reason to reject it.
    static func canonical(_ css: String) throws(CSSRejection) -> String {
        var parser = CSSParser(t: try CSSTokenizer.tokenize(css))
        return try parser.stylesheet()
    }
}
