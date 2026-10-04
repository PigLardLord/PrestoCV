import CVDesignCatalog

/// The cover letter's one built-in stylesheet (ADR 0019). It is not a design: it is not in the catalog, nobody installs it, and
/// the builder takes no design, so no choice can select it. It passes the same tokenizer and property allow-list as a design's,
/// checked against the letter structure's selectors. Its colours and fonts are its own fixed values, from no design and no palette.
enum LetterStyle {
    static let primary = "#1F3A5F", text = "#111111", background = "#FFFFFF"
    /// Helvetica and Arial have the same metrics, as does the free family that stands in for them where neither is installed,
    /// so a letter fits on its page alike wherever it is rendered.
    static let fonts = "Helvetica,Arial,sans-serif"
    static let customProperties =
        ":root{--color-primary:\(primary);--color-text:\(text);--color-background:\(background);--font-body:\(fonts);--font-heading:\(fonts)}"

    /// The rules, in the CSS a design may write: absolute sizes, lengths within the policy's bounds, colours and fonts only
    /// through the variables above.
    static let source = """
        .letter{font-family:var(--font-body);font-size:10.5pt;line-height:1.35;color:var(--color-text);background-color:var(--color-background);padding:12pt 48pt 0}
        p,h1,h2{margin:0}
        .letter-sender{margin-bottom:20pt}
        .letter-sender-name{font-size:15pt;font-weight:700;color:var(--color-primary);margin-bottom:3pt}
        .letter-sender-title{font-weight:600}
        .letter-sender-title,.letter-sender-email,.letter-sender-phone,.letter-sender-location,.letter-sender-website{font-size:9.5pt;line-height:1.3}
        .letter-sender-website{display:block;color:var(--color-primary);text-decoration:none}
        .letter-recipient{margin-bottom:16pt}
        .letter-dateline{text-align:right;margin-bottom:16pt}
        .letter-reference{font-size:9.5pt;margin-bottom:4pt}
        .letter-reference-label{font-weight:700}
        .letter-subject{font-size:12pt;font-weight:700;margin-bottom:12pt}
        .letter-salutation{margin-bottom:9pt}
        .letter-paragraph{margin-bottom:8pt}
        .letter-closing{margin-bottom:8pt}
        .letter-valediction{margin-bottom:24pt}
        .letter-signature{font-weight:700}
        .letter-attachments{margin-top:18pt;font-size:9.5pt}
        .letter-attachments-title{font-weight:700}
        """

    static func stylesheet() throws(LetterBuildFailure) -> ValidatedStylesheet {
        do { return try ValidatedStylesheet.validating(source, against: LetterMarkup.vocabulary) } catch { throw .stylesheet(error.reason) }
    }
}
