/// The one rule for the text of a CV: which characters it keeps (R6). `CV` applies it wherever text enters, so a text it
/// holds never carries a character that can hide, reorder or break what is printed, whether it was typed, drafted or
/// stored. There are two kinds, by the field the text belongs to:
/// - **single line**: a name, a title, a company, a skill, an interest. A line break or a tab becomes a space.
/// - **multi line**: a summary or a description. A line break becomes `\n`, and a tab becomes a space.
///
/// Both kinds remove, without an error, because the user cannot see these characters:
/// - the C0 controls other than the tab and the line breaks, DEL, and the C1 controls other than NEL;
/// - bidirectional embeddings, overrides and isolates (U+202A–U+202E, U+2066–U+2069);
/// - tag characters (U+E0000–U+E007F), which hide ASCII text.
///
/// Line breaks are `\r\n` (one break), `\r`, `\n`, the vertical tab (U+000B), the form feed (U+000C), NEL (U+0085), U+2028
/// and U+2029: each is a hard break, and removing one would glue the words around it. Everything else is kept, the joiners
/// ZWJ (U+200D) and ZWNJ (U+200C) included, since emoji sequences and Persian or Indic text need them. Spaces are
/// neither trimmed nor collapsed. The rule works on Unicode scalars, and applying it twice gives the same text.
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
