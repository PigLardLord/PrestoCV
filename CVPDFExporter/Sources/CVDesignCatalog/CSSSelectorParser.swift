import Foundation

/// A selector made of what the markup contract names: its elements, its classes, `[data-section=…]`,
/// `[data-rating=…]` and a few structural pseudo-classes, joined by a descendant combinator, `>`, `+` or `~`. There
/// are no ids, pseudo-elements or functions.
struct CSSSelectorParser {
    private static let danglingCombinator = CSSRejection(reason: "dangling combinator")

    private var tokens: CSSTokenStream
    private var selector = ""
    private var expectsCompound = true

    /// The canonical text of comma-separated selectors.
    static func canonicalList(_ prelude: [CSSToken]) throws(CSSRejection) -> String {
        var selectors: [String] = []
        for part in prelude.split(separator: .comma, omittingEmptySubsequences: false) {
            selectors.append(try canonical(Array(part)))
        }
        return selectors.joined(separator: ",")
    }

    private static func canonical(_ raw: [CSSToken]) throws(CSSRejection) -> String {
        var parser = CSSSelectorParser(tokens: CSSTokenStream(trimmed(raw)))
        return try parser.readSelector()
    }

    private static func trimmed(_ tokens: [CSSToken]) -> [CSSToken] {
        let isContent = { (token: CSSToken) in token != .whitespace }
        guard let first = tokens.firstIndex(where: isContent), let last = tokens.lastIndex(where: isContent) else { return [] }
        return Array(tokens[first...last])
    }

    private static func isCombinator(_ token: CSSToken) -> Bool {
        [.whitespace, .delim(">"), .delim("+"), .delim("~")].contains(token)
    }

    // MARK: Reading

    private mutating func readSelector() throws(CSSRejection) -> String {
        guard !tokens.isAtEnd else { throw CSSRejection(reason: "empty selector") }
        while let token = tokens.current { try read(startingWith: token) }
        guard !expectsCompound else { throw Self.danglingCombinator }
        return selector
    }

    private mutating func read(startingWith token: CSSToken) throws(CSSRejection) {
        if Self.isCombinator(token) {
            try readCombinator()
        } else {
            selector += try readSimpleSelector(startingWith: token)
            expectsCompound = false
        }
    }

    /// A run of white space and combinator signs: a descendant combinator, or the one sign it holds.
    private mutating func readCombinator() throws(CSSRejection) {
        var combinator = " "
        while let token = tokens.current, Self.isCombinator(token) {
            if case .delim(let sign) = token {
                guard combinator == " " else { throw CSSRejection(reason: "double combinator") }
                combinator = String(sign)
            }
            tokens.advance()
        }
        guard !expectsCompound else { throw Self.danglingCombinator }
        selector += combinator
        expectsCompound = true
    }

    private mutating func readSimpleSelector(startingWith token: CSSToken) throws(CSSRejection) -> String {
        switch token {
        case .ident(let element): return try readElement(element)
        case .delim("."): return try readClass()
        case .lbracket: return try readAttribute()
        case .colon: return try readPseudoClass()
        // Not in the markup contract: it also selects the document root, which sets what rem means.
        case .delim("*"): throw CSSRejection(reason: "the universal selector is not allowed")
        default: throw CSSRejection(reason: "selector token not allowed")
        }
    }

    private mutating func readElement(_ name: String) throws(CSSRejection) -> String {
        guard MarkupContract.elements.contains(name.lowercased()) else {
            throw CSSRejection(reason: "element \(name) is not in the markup contract")
        }
        tokens.advance()
        return name.lowercased()
    }

    private mutating func readClass() throws(CSSRejection) -> String {
        guard case .ident(let name)? = tokens.peek(1), MarkupContract.classes.contains(name) else {
            throw CSSRejection(reason: "class is not in the markup contract")
        }
        tokens.advance(2)
        return ".\(name)"
    }

    private mutating func readAttribute() throws(CSSRejection) -> String {
        guard case .ident(let name)? = tokens.peek(1), tokens.peek(2) == .delim("="), tokens.peek(4) == .rbracket else {
            throw CSSRejection(reason: "attribute selector not allowed")
        }
        let value = try Self.attributeValue(tokens.peek(3))
        guard MarkupContract.allowsAttribute(name, value: value) else {
            throw CSSRejection(reason: "attribute selector not in the markup contract")
        }
        tokens.advance(5)
        return "[\(name)=\"\(value)\"]"
    }

    private static func attributeValue(_ token: CSSToken?) throws(CSSRejection) -> String {
        switch token {
        case .string(let value)?, .ident(let value)?: return value
        case .number(let number)?: return canonicalNumber(number)
        default: throw CSSRejection(reason: "attribute value not allowed")
        }
    }

    private mutating func readPseudoClass() throws(CSSRejection) -> String {
        guard case .ident(let name)? = tokens.peek(1), MarkupContract.pseudoClasses.contains(name.lowercased()) else {
            throw CSSRejection(reason: "pseudo-class or pseudo-element not allowed")
        }
        tokens.advance(2)
        return ":\(name.lowercased())"
    }
}
