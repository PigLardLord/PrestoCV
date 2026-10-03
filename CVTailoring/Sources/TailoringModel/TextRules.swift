/// The rule on the characters that hide what a text says, in the one place that holds it. Every initialiser of the
/// model refuses a text that breaks it (`TailoringModelError.hiddenCharacter`), and a decoder or a request mapper that
/// reads text before it reaches the model calls this same copy.
///
/// A character is hidden when it is:
/// - a control character (general category Cc), except, in a multi-line text, `\n`, `\r` (so `\r\n` too) and tab;
/// - a bidirectional embedding or override (U+202A to U+202E), or an isolate (U+2066 to U+2069): they make a text read
///   in another order than it was written, so "12" can read as "21";
/// - a tag character (U+E0000 to U+E007F), which has no visible form.
///
/// The joiners (U+200D, U+200C), the zero-width space, the byte order mark, the word joiner and the left-to-right and
/// right-to-left marks are not hidden: scripts and emoji need them.
///
/// Whether a field is multi-line is the model's to say: an experience's description, the descriptions of education and
/// certifications, the summary and the advert are; every other text is one line. A statement is a line of a
/// description, so a tab is allowed in it, and its line breaks are refused as `notOneLine`.
public enum TextRules {
    /// Whether `text` holds a hidden character. A multi-line text may hold `\n`, `\r` and tab; a single-line one none.
    public static func hiddenCharacter(in text: String, multiLine: Bool) -> Bool {
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0x202A...0x202E, 0x2066...0x2069, 0xE0000...0xE007F:
                return true
            default:
                guard scalar.properties.generalCategory == .control else { continue }
                if multiLine && (scalar == "\n" || scalar == "\r" || scalar == "\t") { continue }
                return true
            }
        }
        return false
    }
}
