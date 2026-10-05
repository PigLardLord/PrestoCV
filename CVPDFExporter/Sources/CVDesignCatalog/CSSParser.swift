import Foundation

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
