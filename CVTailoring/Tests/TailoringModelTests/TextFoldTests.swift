import Testing
import TailoringModel

/// A text and what the source's `fold` returns for it. The long lists are built step by step, because the type checker
/// of Swift 6.4 is slow on a long literal of tuples.
struct FoldCase: Sendable, CustomTestStringConvertible {
    let text: String
    let folded: String
    init(_ text: String, _ folded: String) { self.text = text; self.folded = folded }
    var testDescription: String { "\(text.unicodeScalars.map { "U+\(String($0.value, radix: 16, uppercase: true))" }) → \(folded)" }
}

/// The expected values are what cv-giovanni's `domain/fold.js` returns at commit 6e28147 for the same input.
@Suite("TextFold · the one normalisation every word-list match uses (#136)")
struct TextFoldTests {
    static let caseIsDroppedCases: [FoldCase] = {
        var cases: [FoldCase] = []
        cases.append(FoldCase("Hello World", "hello world"))
        cases.append(FoldCase("HELLO", "hello"))
        cases.append(FoldCase("FULL-TIME", "full-time"))
        cases.append(FoldCase("CI/CD", "ci/cd"))
        cases.append(FoldCase("m/w/d", "m/w/d"))
        cases.append(FoldCase("Привет", "привет"))
        return cases
    }()

    @Test("case is dropped", arguments: caseIsDroppedCases)
    func caseIsDropped(example: FoldCase) {
        #expect(TextFold.fold(example.text) == example.folded)
    }

    static let diacriticsCases: [FoldCase] = {
        var cases: [FoldCase] = []
        cases.append(FoldCase("Café", "cafe"))
        cases.append(FoldCase("naïve", "naive"))
        cases.append(FoldCase("Ñandú", "nandu"))
        cases.append(FoldCase("Ausgewählte Erfolge", "ausgewahlte erfolge"))
        cases.append(FoldCase("männlich/weiblich/divers", "mannlich/weiblich/divers"))
        cases.append(FoldCase("Å", "a"))
        return cases
    }()

    @Test("diacritics are dropped by decomposition, one rule for every language", arguments: diacriticsCases)
    func diacritics(example: FoldCase) {
        #expect(TextFold.fold(example.text) == example.folded)
    }

    @Test("an umlaut and its bare letter fold alike")
    func umlautAndBareLetter() {
        #expect(TextFold.fold("Ausgewählte Erfolge") == TextFold.fold("Ausgewahlte Erfolge"))
    }

    static let eszettCases: [FoldCase] = {
        var cases: [FoldCase] = []
        cases.append(FoldCase("Straße", "strasse"))
        cases.append(FoldCase("STRASSE", "strasse"))
        cases.append(FoldCase("Strasse", "strasse"))
        cases.append(FoldCase("ßa", "ssa"))
        cases.append(FoldCase("ß\u{0308}", "ss"))
        return cases
    }()

    @Test("eszett is ss, the one letter no normalisation form decomposes", arguments: eszettCases)
    func eszett(example: FoldCase) {
        #expect(TextFold.fold(example.text) == example.folded)
    }

    @Test("a capital sharp s lowercases to ß and stays one, as it does in the source")
    func capitalSharpS() {
        #expect(TextFold.fold("ẞ") == "ß")
        #expect(TextFold.fold("GROẞ") == "groß")
    }

    static let compatibilityCases: [FoldCase] = {
        var cases: [FoldCase] = []
        cases.append(FoldCase("\u{FB01}nance", "finance"))
        cases.append(FoldCase("\u{FB02}ow", "flow"))
        cases.append(FoldCase("\u{FB03}", "ffi"))
        cases.append(FoldCase("\u{FB06}", "st"))
        cases.append(FoldCase("\u{0133}", "ij"))
        cases.append(FoldCase("\u{01C6}", "dz"))
        cases.append(FoldCase("\u{2460}\u{2461}", "12"))
        cases.append(FoldCase("\u{FF46}\u{FF55}\u{FF4C}\u{FF4C}", "full"))
        cases.append(FoldCase("\u{338F}", "kg"))
        cases.append(FoldCase("\u{00BD}", "1\u{2044}2"))
        cases.append(FoldCase("\u{017F}", "s"))
        cases.append(FoldCase("\u{2128}", "z"))
        return cases
    }()

    @Test("ligatures and compatibility forms are expanded", arguments: compatibilityCases)
    func compatibility(example: FoldCase) {
        #expect(TextFold.fold(example.text) == example.folded)
    }

    static let undecomposableCases: [FoldCase] = {
        var cases: [FoldCase] = []
        cases.append(FoldCase("Œuvre", "œuvre"))
        cases.append(FoldCase("Æsir", "æsir"))
        cases.append(FoldCase("Ø", "ø"))
        cases.append(FoldCase("Łódź", "łodz"))
        cases.append(FoldCase("\u{0131}", "\u{0131}"))
        cases.append(FoldCase("한국어", "한국어"))
        return cases
    }()

    @Test("letters that do not decompose stay as they are, lowercased", arguments: undecomposableCases)
    func undecomposable(example: FoldCase) {
        #expect(TextFold.fold(example.text) == example.folded)
    }

    @Test("a dotted capital I is i")
    func dottedCapitalI() {
        #expect(TextFold.fold("\u{0130}stanbul") == "istanbul")
        #expect(TextFold.fold("\u{0130}") == "i")
    }

    static let combiningMarksCases: [FoldCase] = {
        var cases: [FoldCase] = []
        cases.append(FoldCase("e\u{0301}", "e"))
        cases.append(FoldCase("e\u{0301}\u{0302}", "e"))
        cases.append(FoldCase("a\u{0300}\u{0316}", "a"))
        cases.append(FoldCase("\u{0345}", ""))
        cases.append(FoldCase("\u{1FB3}", "\u{03B1}"))
        return cases
    }()

    @Test("combining marks from U+0300 to U+036F are dropped, however many are stacked", arguments: combiningMarksCases)
    func combiningMarks(example: FoldCase) {
        #expect(TextFold.fold(example.text) == example.folded)
    }

    @Test("a combining mark outside that range is kept")
    func otherMarksStay() {
        #expect(TextFold.fold("a\u{20D0}") == "a\u{20D0}")
    }

    static let finalSigmaCases: [FoldCase] = {
        var cases: [FoldCase] = []
        cases.append(FoldCase("ΑΣ", "ας"))
        cases.append(FoldCase("ΑΣΑ", "ασα"))
        cases.append(FoldCase("Σ", "σ"))
        cases.append(FoldCase("ΣΑΣ", "σας"))
        cases.append(FoldCase("ΑΣ ΑΣ", "ας ας"))
        cases.append(FoldCase("ΑΣ.", "ας."))
        cases.append(FoldCase("ΑΣ\u{0301}", "ας"))
        cases.append(FoldCase("ὈΔΥΣΣΕΎΣ", "οδυσσευς"))
        return cases
    }()

    @Test("a final sigma is lowercased as the source lowercases it", arguments: finalSigmaCases)
    func finalSigma(example: FoldCase) {
        #expect(TextFold.fold(example.text) == example.folded)
    }

    static let whitespaceCases: [FoldCase] = {
        var cases: [FoldCase] = []
        cases.append(FoldCase("  sprachen  ", "sprachen"))
        cases.append(FoldCase("a\u{00A0}b", "a b"))
        cases.append(FoldCase("a\t\n\r b", "a b"))
        cases.append(FoldCase("\u{3000}a\u{3000}", "a"))
        cases.append(FoldCase("\u{FEFF}a\u{FEFF}", "a"))
        cases.append(FoldCase("a\u{2028}b\u{2029}c", "a b c"))
        cases.append(FoldCase("a\u{000B}b\u{000C}c", "a b c"))
        cases.append(FoldCase("\u{1680}a", "a"))
        cases.append(FoldCase("a\u{2003}b", "a b"))
        cases.append(FoldCase("a\u{202F}b", "a b"))
        cases.append(FoldCase("a\u{205F}b", "a b"))
        cases.append(FoldCase("Via  Slack", "via slack"))
        cases.append(FoldCase("\u{00A0}x\u{00A0}", "x"))
        cases.append(FoldCase("", ""))
        cases.append(FoldCase("   ", ""))
        return cases
    }()

    @Test("every whitespace character the source reads as white space is one space, and the ends are trimmed", arguments: whitespaceCases)
    func whitespace(example: FoldCase) {
        #expect(TextFold.fold(example.text) == example.folded)
    }

    static let notWhitespaceCases: [String] = {
        var values: [String] = []
        values.append(contentsOf: ["a\u{200B}b", "a\u{0085}b", "a\u{180E}b"])
        return values
    }()

    @Test("a character the source does not read as white space stays", arguments: notWhitespaceCases)
    func notWhitespace(text: String) {
        #expect(TextFold.fold(text) == text)
    }
}
