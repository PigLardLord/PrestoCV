/// The rule on the characters that hide what a text says, in the one place that holds it. Every initialiser of the
/// model refuses a text that breaks it (`TailoringModelError.hiddenCharacter`), and a decoder or a request mapper that
/// reads text before it reaches the model calls this same copy.
///
/// A character is hidden when it is:
/// - a control character (general category Cc), except, in a multi-line text, `\n`, `\r` (so `\r\n` too) and tab;
/// - a bidirectional embedding or override (U+202A to U+202E), or an isolate (U+2066 to U+2069): they make a text read
///   in another order than it was written, so "12" can read as "21";
/// - a bidirectional mark: the left-to-right and right-to-left marks (U+200E, U+200F) and the Arabic letter mark
///   (U+061C). Before figures they reverse how the figures display: "1040 → 5308" reads as "5308 → 1040", and "-5%" as
///   "5%-";
/// - a tag character (U+E0000 to U+E007F), which has no visible form.
///
/// The joiners (U+200D, U+200C), the zero-width space, the byte order mark and the word joiner are not hidden: scripts
/// and emoji need them.
///
/// Whether a field is multi-line is the model's to say: an experience's description, the descriptions of education and
/// certifications, the summary, the advert and the letter note are; every other text is one line. A statement is a line of a
/// description, so a tab is allowed in it, and its line breaks are refused as `notOneLine`.
public enum TextRules {
    /// Whether `text` holds a hidden character. A multi-line text may hold `\n`, `\r` and tab; a single-line one none.
    public static func hiddenCharacter(in text: String, multiLine: Bool) -> Bool {
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0x202A...0x202E, 0x2066...0x2069, 0x200E, 0x200F, 0x061C, 0xE0000...0xE007F:
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
