import Foundation

/// Typed HTML (ADR 0011): tag and attribute names are closed enums, text and attribute values are
/// always escaped, raw HTML is not representable.
enum Tag: String { case html, head, meta, title, body, main, header, section, article, h1, h2, h3, p, span, a }
enum Attr: String { case lang, charset, `class`, href, dataSection = "data-section", dataRating = "data-rating", dataSchema = "data-schema" }

indirect enum HTML: Sendable {
    case element(Tag, attributes: [(Attr, String)] = [], children: [HTML] = [])
    case text(String)
    /// One space between inline siblings, so their text never runs together whatever the design does.
    /// It is not a text node: completeness does not count it.
    case separator
    /// Only built by the builder from a ValidatedStylesheet, a Palette or a FontScheme.
    case trustedStyle(String)

    var rendered: String {
        switch self {
        case .text(let text): return Self.escape(text)
        case .separator: return " "
        case .trustedStyle(let css):
            // Defence in depth: validated CSS cannot contain "<"; if it ever did, emit nothing.
            return css.unicodeScalars.contains("<") ? "<style></style>" : "<style>" + css + "</style>"
        case let .element(tag, attributes, children):
            let attributeText = attributes.map { " \($0.0.rawValue)=\"\(Self.escape($0.1))\"" }.joined()
            if tag == .meta { return "<\(tag.rawValue)\(attributeText)>" }            // void element: no end tag
            return "<\(tag.rawValue)\(attributeText)>" + children.map(\.rendered).joined() + "</\(tag.rawValue)>"
        }
    }

    /// The text a reader sees, one entry per text node, in document order.
    var textNodes: [String] {
        switch self {
        case .text(let text): return [text]
        case .separator, .trustedStyle: return []
        case let .element(_, _, children): return children.flatMap(\.textNodes)
        }
    }

    /// Escapes per Unicode scalar, never per Character: a quote followed by a combining mark is one
    /// grapheme cluster, and a Character-level switch would let it through unescaped.
    static func escape(_ text: String) -> String {
        var escaped = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            switch scalar {
            case "&": escaped.append(contentsOf: "&amp;".unicodeScalars)
            case "<": escaped.append(contentsOf: "&lt;".unicodeScalars)
            case ">": escaped.append(contentsOf: "&gt;".unicodeScalars)
            case "\"": escaped.append(contentsOf: "&quot;".unicodeScalars)
            case "'": escaped.append(contentsOf: "&#39;".unicodeScalars)
            default: escaped.append(scalar)
            }
        }
        return String(escaped)
    }
}

// MARK: - Elements of the markup contract

extension HTML {
    static func element(_ tag: Tag, class cls: String, children: [HTML]) -> HTML {
        .element(tag, attributes: [(.class, cls)], children: children)
    }

    static func element(_ tag: Tag, class cls: String, text: String) -> HTML {
        .element(tag, class: cls, children: [.text(text)])
    }

    /// A paragraph holding `text`, or nothing when there is no text to print.
    static func optionalParagraph(class cls: String, text: String?) -> [HTML] {
        guard let text, !text.isEmpty else { return [] }
        return [.element(.p, class: cls, text: text)]
    }

    /// An anchor to `link`, which prints its destination as its text.
    static func anchor(class cls: String, to link: WebLink) -> HTML {
        anchor(class: cls, to: link, children: [.text(link.url)])
    }

    static func anchor(class cls: String, to link: WebLink, children: [HTML]) -> HTML {
        .element(.a, attributes: [(.class, cls), (.href, link.url)], children: children)
    }

    /// An anchor to the link in `raw`, or nothing when `raw` is absent or is not a safe link.
    static func optionalAnchor(class cls: String, to raw: String?) -> [HTML] {
        guard let raw, let link = WebLink(raw) else { return [] }
        return [.anchor(class: cls, to: link)]
    }
}
