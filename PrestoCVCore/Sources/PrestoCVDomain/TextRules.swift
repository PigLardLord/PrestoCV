/// The one rule for the text of a CV (R6), applied wherever text enters one: the initialisers and setters of the value
/// types, and so the store's reader and the draft mapper, which build a CV through them (R8). It removes without a
/// word: a character nobody can see never produces an error the person cannot act on.
///
/// | Character | Single-line field | Multi-line field |
/// |---|---|---|
/// | Control characters (category Cc), NUL and DEL included | removed | removed |
/// | LF, CR, CRLF, NEL (U+0085), U+2028, U+2029 | one space each | LF (CRLF and CR count once) |
/// | Tab | one space | one space |
/// | Embeddings and overrides U+202A to U+202E, isolates U+2066 to U+2069 | removed | removed |
/// | The marks U+200E, U+200F and U+061C, which reverse figures on display | removed | removed |
/// | Tag characters U+E0000 to U+E007F, which hide ASCII text | removed | removed |
/// | ZWJ U+200D and ZWNJ U+200C, variation selectors, every letter, mark and symbol | kept | kept |
/// | U+200B, U+2060, U+FEFF and U+00AD, invisible but not named by the decision | kept | kept |
///
/// A tag-sequence flag emoji (England, Scotland, Wales) loses its tags and reads as a black flag: the accepted loss.
/// There is no trimming and no collapsing of spaces, and the rule is idempotent. The multi-line fields are the summary
/// and the description of an experience, an education and a certification; every other text is single-line.
///
/// It reads no ambient state and uses only `Unicode.Scalar.Properties`, which every platform build has (R2, R18).
public enum TextRules {
    public static func singleLine(_ text: String) -> String { normalised(text, lineBreak: " ") }

    public static func multiLine(_ text: String) -> String { normalised(text, lineBreak: "\n") }

    private static func normalised(_ text: String, lineBreak: Unicode.Scalar) -> String {
        var result = String.UnicodeScalarView()
        var previousWasCarriageReturn = false
        for scalar in text.unicodeScalars {
            defer { previousWasCarriageReturn = scalar == "\r" }
            switch scalar {
            case "\n" where previousWasCarriageReturn: continue          // the LF of a CRLF: the CR already gave the break
            case "\r", "\n", "\u{85}", "\u{2028}", "\u{2029}": result.append(lineBreak)
            case "\t": result.append(" ")
            default: if !isRemoved(scalar) { result.append(scalar) }
            }
        }
        return String(result)
    }

    private static func isRemoved(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x202A...0x202E, 0x2066...0x2069, 0x200E, 0x200F, 0x061C, 0xE0000...0xE007F: return true
        default: return scalar.properties.generalCategory == .control
        }
    }
}
