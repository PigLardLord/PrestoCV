/// The one rule for what the text of a published document may not hold (R6, R8), shared by `CVDocumentValidator` and
/// `LetterDocumentValidator`, and by the page's own words. It refuses control characters, and the explicit bidirectional
/// embeddings, overrides and isolates, which reorder what is printed. It lets the rest through, because Authoring keeps the rest:
/// a letter or a CV that it saves must never fail to render for its characters.
package enum DocumentText {
    /// Whether `scalar` may not appear in a text. A line break is a control character: a text that holds one line refuses it,
    /// and a text that may hold several allows `"\n"`.
    package static func refuses(_ scalar: Unicode.Scalar, allowingLineBreak: Bool) -> Bool {
        (scalar.properties.generalCategory == .control && !(allowingLineBreak && scalar == "\n")) || reordersText(scalar)
    }

    private static func reordersText(_ scalar: Unicode.Scalar) -> Bool {
        (0x202A...0x202E).contains(scalar.value) || (0x2066...0x2069).contains(scalar.value)
    }
}
