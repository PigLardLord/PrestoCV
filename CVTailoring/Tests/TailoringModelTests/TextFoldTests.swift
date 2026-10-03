import Testing
import TailoringModel

/// The expected values are what cv-giovanni's `domain/fold.js` returns at commit 6e28147 for the same input.
@Suite("TextFold · the one normalisation every word-list match uses (#136)")
struct TextFoldTests {
    @Test("case is dropped", arguments: [
        ("Hello World", "hello world"), ("HELLO", "hello"), ("FULL-TIME", "full-time"), ("CI/CD", "ci/cd"), ("m/w/d", "m/w/d"),
        ("Привет", "привет"),
    ])
    func caseIsDropped(text: String, folded: String) {
        #expect(TextFold.fold(text) == folded)
    }

    @Test("diacritics are dropped by decomposition, one rule for every language", arguments: [
        ("Café", "cafe"), ("naïve", "naive"), ("Ñandú", "nandu"), ("Ausgewählte Erfolge", "ausgewahlte erfolge"),
        ("männlich/weiblich/divers", "mannlich/weiblich/divers"), ("Å", "a"),
    ])
    func diacritics(text: String, folded: String) {
        #expect(TextFold.fold(text) == folded)
    }

    @Test("an umlaut and its bare letter fold alike")
    func umlautAndBareLetter() {
        #expect(TextFold.fold("Ausgewählte Erfolge") == TextFold.fold("Ausgewahlte Erfolge"))
    }

    @Test("eszett is ss, the one letter no normalisation form decomposes", arguments: [
        ("Straße", "strasse"), ("STRASSE", "strasse"), ("Strasse", "strasse"), ("ßa", "ssa"), ("ß\u{0308}", "ss"),
    ])
    func eszett(text: String, folded: String) {
        #expect(TextFold.fold(text) == folded)
    }

    @Test("a capital sharp s lowercases to ß and stays one, as it does in the source")
    func capitalSharpS() {
        #expect(TextFold.fold("ẞ") == "ß")
        #expect(TextFold.fold("GROẞ") == "groß")
    }

    @Test("ligatures and compatibility forms are expanded", arguments: [
        ("\u{FB01}nance", "finance"), ("\u{FB02}ow", "flow"), ("\u{FB03}", "ffi"), ("\u{FB06}", "st"), ("\u{0133}", "ij"),
        ("\u{01C6}", "dz"), ("\u{2460}\u{2461}", "12"), ("\u{FF46}\u{FF55}\u{FF4C}\u{FF4C}", "full"), ("\u{338F}", "kg"),
        ("\u{00BD}", "1\u{2044}2"), ("\u{017F}", "s"), ("\u{2128}", "z"),
    ])
    func compatibility(text: String, folded: String) {
        #expect(TextFold.fold(text) == folded)
    }

    @Test("letters that do not decompose stay as they are, lowercased", arguments: [
        ("Œuvre", "œuvre"), ("Æsir", "æsir"), ("Ø", "ø"), ("Łódź", "łodz"), ("\u{0131}", "\u{0131}"), ("한국어", "한국어"),
    ])
    func undecomposable(text: String, folded: String) {
        #expect(TextFold.fold(text) == folded)
    }

    @Test("a dotted capital I is i")
    func dottedCapitalI() {
        #expect(TextFold.fold("\u{0130}stanbul") == "istanbul")
        #expect(TextFold.fold("\u{0130}") == "i")
    }

    @Test("combining marks from U+0300 to U+036F are dropped, however many are stacked", arguments: [
        ("e\u{0301}", "e"), ("e\u{0301}\u{0302}", "e"), ("a\u{0300}\u{0316}", "a"), ("\u{0345}", ""), ("\u{1FB3}", "\u{03B1}"),
    ])
    func combiningMarks(text: String, folded: String) {
        #expect(TextFold.fold(text) == folded)
    }

    @Test("a combining mark outside that range is kept")
    func otherMarksStay() {
        #expect(TextFold.fold("a\u{20D0}") == "a\u{20D0}")
    }

    @Test("a final sigma is lowercased as the source lowercases it", arguments: [
        ("ΑΣ", "ας"), ("ΑΣΑ", "ασα"), ("Σ", "σ"), ("ΣΑΣ", "σας"), ("ΑΣ ΑΣ", "ας ας"), ("ΑΣ.", "ας."), ("ΑΣ\u{0301}", "ας"),
        ("ὈΔΥΣΣΕΎΣ", "οδυσσευς"),
    ])
    func finalSigma(text: String, folded: String) {
        #expect(TextFold.fold(text) == folded)
    }

    @Test("every whitespace character the source reads as white space is one space, and the ends are trimmed", arguments: [
        ("  sprachen  ", "sprachen"), ("a\u{00A0}b", "a b"), ("a\t\n\r b", "a b"), ("\u{3000}a\u{3000}", "a"), ("\u{FEFF}a\u{FEFF}", "a"),
        ("a\u{2028}b\u{2029}c", "a b c"), ("a\u{000B}b\u{000C}c", "a b c"), ("\u{1680}a", "a"), ("a\u{2003}b", "a b"),
        ("a\u{202F}b", "a b"), ("a\u{205F}b", "a b"), ("Via  Slack", "via slack"), ("\u{00A0}x\u{00A0}", "x"), ("", ""), ("   ", ""),
    ])
    func whitespace(text: String, folded: String) {
        #expect(TextFold.fold(text) == folded)
    }

    @Test("a character the source does not read as white space stays", arguments: [
        "a\u{200B}b", "a\u{0085}b", "a\u{180E}b",
    ])
    func notWhitespace(text: String) {
        #expect(TextFold.fold(text) == text)
    }
}
