import Foundation

/// The declarations of a rule: `property: value` pairs separated by semicolons, each property on the allow-list and
/// each value through the check of its property.
enum CSSDeclarationParser {
    private struct Declaration {
        let name: String, value: String

        var text: String { "\(name):\(value)" }
        var makesFlexOrGridContainer: Bool { name == "display" && ["flex", "inline-flex", "grid"].contains(value) }
        var setsColumnGap: Bool { name == "gap" || name == "column-gap" }
    }

    static func canonical(_ body: [CSSToken]) throws(CSSRejection) -> String {
        var declarations: [Declaration] = []
        for tokens in body.split(separator: .semicolon, omittingEmptySubsequences: false) {
            if let declaration = try declaration(from: tokens) { declarations.append(declaration) }
        }
        try requireColumnGap(in: declarations)
        return declarations.map(\.text).joined(separator: ";")
    }

    private static func declaration(from tokens: ArraySlice<CSSToken>) throws(CSSRejection) -> Declaration? {
        let parts = tokens.filter { $0 != .whitespace }
        if parts.isEmpty { return nil }
        let name = try propertyName(in: parts)
        if parts.contains(.delim("!")) { throw CSSRejection(reason: "!important is not allowed") }
        return Declaration(name: name, value: try canonicalValue(Array(parts.dropFirst(2)), ofProperty: name))
    }

    /// The lower-cased property of a declaration that is written `property : value`.
    private static func propertyName(in parts: [CSSToken]) throws(CSSRejection) -> String {
        guard parts.count >= 3, case .ident(let name) = parts[0], parts[1] == .colon else { throw CSSRejection(reason: "malformed declaration") }
        return name.lowercased()
    }

    private static func canonicalValue(_ value: [CSSToken], ofProperty name: String) throws(CSSRejection) -> String {
        guard let check = allowedProperties[name] else { throw CSSRejection(reason: "property \(name) is not allowed") }
        return try check(value)
    }

    /// Inline entries are separated by a space in the markup, which flex and grid do not render: a rule that makes a
    /// flex or grid container must also set the column gap that keeps the entries apart.
    private static func requireColumnGap(in declarations: [Declaration]) throws(CSSRejection) {
        let makesContainer = declarations.contains(where: \.makesFlexOrGridContainer)
        if makesContainer, !declarations.contains(where: \.setsColumnGap) {
            throw CSSRejection(reason: "a flex or grid container must set gap or column-gap (at least 3pt)")
        }
    }
}
