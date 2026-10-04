/// Turns headings into the anchors GitHub gives them: the heading's text, lower-cased, keeping letters, marks,
/// decimal digits, underscores and hyphens, with each space becoming a hyphen. A heading that repeats an earlier slug gets
/// `-1`, `-2` and so on, in document order, as GitHub does.
struct HeadingSlugger {
    /// Keyed by scalars, because GitHub's ids are strings of code points: `é` in one scalar and in two are different
    /// anchors, though Swift's `String` treats them as equal.
    private var occurrences: [Anchor: Int] = [:]

    /// The slug of a heading's inline Markdown, unique among the headings this slugger has seen. Nil if the heading
    /// nests link labels too deeply to be read.
    mutating func slug(forHeading markdown: String) -> String? {
        guard let original = Self.baseSlug(ofHeading: markdown) else { return nil }
        var slug = original
        while occurrences[Anchor(slug)] != nil {
            occurrences[Anchor(original), default: 0] += 1
            slug = original + "-" + String(occurrences[Anchor(original), default: 0])
        }
        occurrences[Anchor(slug)] = 0
        return slug
    }

    /// The slug of a heading on its own, before any numbering for repeats.
    /// Nil if the heading nests link labels deeper than `InlineText.maximumNesting`.
    static func baseSlug(ofHeading markdown: String) -> String? {
        guard let text = InlineText.plain(markdown) else { return nil }
        var slug = ""
        for scalar in text.lowercased().unicodeScalars where keeps(scalar) {
            slug.unicodeScalars.append(scalar == " " ? "-" : scalar)
        }
        return slug
    }

    /// What github-slugger keeps: alphabetic characters (letters, and also letter numbers and circled letters),
    /// combining marks, decimal digits and connector punctuation, plus `-` and space. Other numbers (`²`, `½`, `①`)
    /// and every symbol are dropped.
    private static func keeps(_ scalar: Unicode.Scalar) -> Bool {
        if scalar == " " || scalar == "-" || scalar.properties.isAlphabetic { return true }
        switch scalar.properties.generalCategory {
        case .nonspacingMark, .spacingMark, .enclosingMark, .decimalNumber, .connectorPunctuation:
            return true
        default:
            return false
        }
    }
}

/// An anchor compared scalar by scalar, as GitHub compares ids.
struct Anchor: Hashable {
    private let scalars: [Unicode.Scalar]

    init(_ name: String) {
        scalars = Array(name.unicodeScalars)
    }
}
