/// The one rule for the text of a CV (R6): which characters it removes, which it turns into a space or a line feed, and
/// which it keeps. `CV` applies it wherever text enters, whether the text was typed, drafted or stored. There are two
/// kinds, by the field the text belongs to:
/// - **single line**: a name, a title, a company, a skill, an interest. A line break becomes a space.
/// - **multi line**: a summary or a description. A line break becomes `\n`.
///
/// Both kinds **remove**, without an error, because the user cannot see these characters:
/// - the C0 controls other than the tab and the line breaks, DEL, and the C1 controls other than NEL;
/// - bidirectional embeddings, overrides and isolates (U+202A–U+202E, U+2066–U+2069), which reorder what is printed;
/// - tag characters (U+E0000–U+E007F), which hide ASCII text.
///
/// Both kinds **convert**:
/// - a line break: `\r\n` (one break), `\r`, `\n`, the vertical tab (U+000B), the form feed (U+000C), NEL (U+0085), U+2028
///   and U+2029. Each is a hard break, and removing one would glue the words around it;
/// - a tab: one space.
///
/// Everything else is **kept**, on purpose: the zero-width and joining characters (U+200B, ZWJ U+200D, ZWNJ U+200C,
/// U+2060, U+FEFF), the direction marks (U+200E, U+200F) and the variation selectors, because emoji sequences, Persian
/// and Indic text and mixed-direction text need them. Spaces are neither trimmed nor collapsed. One consequence: a
/// subdivision flag (England, Scotland, Wales) is a black flag followed by tag characters, so it loses them and prints as
/// a plain black flag.
///
/// The rule works on Unicode scalars, and applying it twice gives the same text.
enum TextRule {
    static func singleLine(_ text: String) -> String { normalised(text, lineBreak: " ") }
    static func multiLine(_ text: String) -> String { normalised(text, lineBreak: "\n") }

    private static func normalised(_ text: String, lineBreak: Unicode.Scalar) -> String {
        var kept = String.UnicodeScalarView()
        var afterCarriageReturn = false
        for scalar in text.unicodeScalars {
            let completesCRLF = afterCarriageReturn && scalar == "\n"
            afterCarriageReturn = scalar == "\r"
            if completesCRLF { continue }
            switch scalar.value {
            case 0x0A, 0x0B, 0x0C, 0x0D, 0x85, 0x2028, 0x2029: kept.append(lineBreak)
            case 0x09: kept.append(" ")
            case 0x00..<0x20, 0x7F, 0x80...0x9F, 0x202A...0x202E, 0x2066...0x2069, 0xE0000...0xE007F: continue
            default: kept.append(scalar)
            }
        }
        return String(kept)
    }
}

extension Unicode.Scalar {
    /// A heuristic for "prints something", used to tell a name from a blank. False for white space, for the characters a
    /// renderer leaves out (default ignorable code points, such as the joiners and the direction marks), for control,
    /// format, unassigned and surrogate characters, and for the blank braille pattern (U+2800), which prints an empty
    /// cell. Private-use characters count as visible on purpose: a font can draw them (U+F8FF prints on Apple platforms).
    /// A name made only of invisible characters is no name.
    var isVisible: Bool {
        if properties.isWhitespace || properties.isDefaultIgnorableCodePoint || self == "\u{2800}" { return false }
        switch properties.generalCategory {
        case .control, .format, .unassigned, .surrogate: return false
        default: return true
        }
    }
}
