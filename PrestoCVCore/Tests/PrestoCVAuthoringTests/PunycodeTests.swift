import Testing
@testable import PrestoCVDomain

/// The sample strings of RFC 3492, section 7.1, with the Punycode the RFC publishes for them.
let punycodeSamples: [(String, String)] = [
    ("\u{0644}\u{064A}\u{0647}\u{0645}\u{0627}\u{0628}\u{062A}\u{0643}\u{0644}\u{0645}\u{0648}\u{0634}\u{0639}\u{0631}\u{0628}\u{064A}\u{061F}",
     "egbpdaj6bu4bxfgehfvwxn"),                                                                      // (A) Arabic
    ("\u{4ED6}\u{4EEC}\u{4E3A}\u{4EC0}\u{4E48}\u{4E0D}\u{8BF4}\u{4E2D}\u{6587}", "ihqwcrb4cv8a8dqg056pqjye"),   // (B) Chinese
    ("Pro\u{010D}prost\u{011B}nemluv\u{00ED}\u{010D}esky", "Proprostnemluvesky-uyb24dma41a"),           // (D) Czech
    ("3\u{5E74}B\u{7D44}\u{91D1}\u{516B}\u{5148}\u{751F}", "3B-ww4c5e180e575a65lsy2b"),                   // (L) Japanese and ASCII
    ("\u{5B89}\u{5BA4}\u{5948}\u{7F8E}\u{6075}-with-SUPER-MONKEYS", "-with-SUPER-MONKEYS-pc58ag80a8qai00g7n9n"),
    ("Maji\u{3067}Koi\u{3059}\u{308B}5\u{79D2}\u{524D}", "MajiKoi5-783gue6qz075azm5e"),                 // (S) Japanese and ASCII
    ("ada-lovelace-1815", "ada-lovelace-1815-"),                                                     // only ASCII
]

@Suite("Punycode (RFC 3492)")
struct PunycodeTests {
    @Test("the sample strings of RFC 3492 section 7.1 encode to their published Punycode", arguments: punycodeSamples)
    func samples(text: String, encoded: String) {
        #expect(Punycode.encode(Array(text.unicodeScalars)) == encoded)
    }

    @Test("a label is as long on the wire as ASCII, or xn-- and its Punycode otherwise")
    func wireLength() {
        #expect(IDNALabel.encodedByteCount("example") == 7)
        #expect(IDNALabel.encodedByteCount("bücher") == "xn--bcher-kva".utf8.count)
    }

    @Test("a label weighs the same composed or decomposed, as IDNA normalizes it first (RFC 5891 section 5.2)")
    func normalizedLength() {
        let composed = String(repeating: "\u{00E9}", count: 30), decomposed = String(repeating: "e\u{0301}", count: 30)
        #expect(IDNALabel.encodedByteCount(Substring(decomposed)) == IDNALabel.encodedByteCount(Substring(composed)))
        #expect(IDNALabel.encodedByteCount(Substring(decomposed)) == 36)
    }
}
