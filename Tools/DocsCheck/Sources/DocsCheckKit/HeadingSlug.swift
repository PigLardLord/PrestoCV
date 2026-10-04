/// Turns headings into the anchors GitHub gives them: the heading's text, lower-cased, keeping letters, marks,
/// decimal digits, underscores and hyphens, with each space becoming a hyphen. A heading that repeats an earlier slug gets
/// `-1`, `-2` and so on, in document order, as GitHub does.
struct HeadingSlugger {
    private var occurrences: [String: Int] = [:]

    /// The slug of a heading's inline Markdown, unique among the headings this slugger has seen.
    mutating func slug(forHeading markdown: String) -> String {
        let original = Self.baseSlug(ofHeading: markdown)
        var slug = original
        while occurrences[slug] != nil {
            occurrences[original, default: 0] += 1
            slug = original + "-" + String(occurrences[original, default: 0])
        }
        occurrences[slug] = 0
        return slug
    }

    /// The slug of a heading on its own, before any numbering for repeats.
    static func baseSlug(ofHeading markdown: String) -> String {
        var slug = ""
        for scalar in InlineText.plain(markdown).lowercased().unicodeScalars where keeps(scalar) {
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
