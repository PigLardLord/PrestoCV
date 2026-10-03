/// The rule on the characters that hide what a text says, in the one place that holds it. Every initialiser of the
/// model refuses a text that breaks it (`TailoringModelError.hiddenCharacter`). A decoder or a request mapper that
/// reads text before it reaches the model calls this same copy: `hiddenCharacter` to check, `removingHidden` to clean,
/// each with the multi-line or one-line classification of a field (`Field.isMultiLine`), so it keeps no second table.
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
/// certifications, the summary, the advert and the letter note are; every other text is one line.
/// - A one-line text holds no line break of any kind (`Character.isNewline`: `\n`, `\r`, vertical tab, form feed, NEL,
///   U+2028, U+2029). The model refuses one as `notOneLine`, before it looks for hidden characters.
/// - A multi-line text keeps `\n`, `\r`, tab and the separators U+2028 and U+2029, which are breaks there and not
///   hidden. NEL, vertical tab and form feed are hidden in it.
/// - A statement is a line of a description, so a tab is allowed in it, and its line breaks are refused as `notOneLine`.
///
public enum TextRules {
    /// Whether `text` holds a hidden character. A multi-line text may hold `\n`, `\r` and tab; a single-line one none.
    public static func hiddenCharacter(in text: String, multiLine: Bool) -> Bool {
        text.unicodeScalars.contains { isHidden($0, multiLine: multiLine) }
    }

    /// Whether `text`, written in `field`, holds a hidden character: the same rule, with the field's own
    /// classification (`Field.isMultiLine`). A line break that is a control character counts as hidden here; U+2028
    /// and U+2029 do not. The model reports every break in a one-line field as `notOneLine`, so a caller that needs the
    /// model's answer also checks `contains(where: \.isNewline)`.
    public static func hiddenCharacter(in text: String, field: TailoringModelError.Field) -> Bool {
        hiddenCharacter(in: text, multiLine: field.isMultiLine)
    }

    /// `text` cleaned of what `hiddenCharacter(in:multiLine:)` refuses, for a caller that cleans what it reads before
    /// it reaches the model. Each refused character is removed, or replaced where removing it would join two words: a
    /// break-like control (vertical tab, form feed, NEL) in a multi-line text becomes a line feed, and a tab in a
    /// one-line text becomes a space. Breaks are normalised, never lost. Everything that is not hidden stays: the
    /// joiners, and in a multi-line text the `\n`, `\r`, tab and separators it keeps. In a one-line text a line break of
    /// any kind is left alone: whether it is an error is for the caller to decide, and the model reports it as
    /// `notOneLine`.
    public static func removingHidden(from text: String, multiLine: Bool) -> String {
        var cleaned = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            if !isHidden(scalar, multiLine: multiLine) {
                cleaned.append(scalar)
            } else if isBreak(scalar) {
                cleaned.append(multiLine ? "\n" : scalar)
            } else if !multiLine && scalar == "\t" {
                cleaned.append(" ")
            }
        }
        return String(cleaned)
    }

    /// `removingHidden(from:multiLine:)` with the classification of `field`.
    public static func removingHidden(from text: String, field: TailoringModelError.Field) -> String {
        removingHidden(from: text, multiLine: field.isMultiLine)
    }

    private static func isHidden(_ scalar: Unicode.Scalar, multiLine: Bool) -> Bool {
        switch scalar.value {
        case 0x202A...0x202E, 0x2066...0x2069, 0x200E, 0x200F, 0x061C, 0xE0000...0xE007F:
            return true
        default:
            guard scalar.properties.generalCategory == .control else { return false }
            return !(multiLine && (scalar == "\n" || scalar == "\r" || scalar == "\t"))
        }
    }

    /// A scalar of the set `Character.isNewline` reads: line feed, vertical tab, form feed, carriage return, NEL, and
    /// the line and paragraph separators.
    private static func isBreak(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x000A...0x000D, 0x0085, 0x2028, 0x2029: true
        default: false
        }
    }
}
