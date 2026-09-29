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
        case .text(let t): return Self.escape(t)
        case .separator: return " "
        case .trustedStyle(let css):
            // Defence in depth: validated CSS cannot contain "<"; if it ever did, emit nothing.
            return css.unicodeScalars.contains("<") ? "<style></style>" : "<style>" + css + "</style>"
        case let .element(tag, attributes, children):
            let attrs = attributes.map { " \($0.0.rawValue)=\"\(Self.escape($0.1))\"" }.joined()
            if tag == .meta { return "<\(tag.rawValue)\(attrs)>" }            // void element: no end tag
            return "<\(tag.rawValue)\(attrs)>" + children.map(\.rendered).joined() + "</\(tag.rawValue)>"
        }
    }

    /// The text a reader sees, one entry per text node, in document order.
    var textNodes: [String] {
        switch self {
        case .text(let t): return [t]
        case .separator, .trustedStyle: return []
        case let .element(_, _, children): return children.flatMap(\.textNodes)
        }
    }

    /// Escapes per Unicode scalar, never per Character: a quote followed by a combining mark is one
    /// grapheme cluster, and a Character-level switch would let it through unescaped.
    static func escape(_ s: String) -> String {
        var out = String.UnicodeScalarView()
        for scalar in s.unicodeScalars {
            switch scalar {
            case "&": out.append(contentsOf: "&amp;".unicodeScalars)
            case "<": out.append(contentsOf: "&lt;".unicodeScalars)
            case ">": out.append(contentsOf: "&gt;".unicodeScalars)
            case "\"": out.append(contentsOf: "&quot;".unicodeScalars)
            case "'": out.append(contentsOf: "&#39;".unicodeScalars)
            default: out.append(scalar)
            }
        }
        return String(out)
    }
}

func el(_ tag: Tag, _ cls: String? = nil, _ attrs: [(Attr, String)] = [], _ children: [HTML] = []) -> HTML {
    .element(tag, attributes: (cls.map { [(.class, $0)] } ?? []) + attrs, children: children)
}
