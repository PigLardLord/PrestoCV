import Testing
@testable import PrestoCVDomain

/// `ascii` letters "a", then `letters` CJK letters seven code points apart, each of which costs two bytes in Punycode.
func spacedLabel(letters: Int, ascii: Int = 0) -> String {
    var label = String(repeating: "a", count: ascii)
    for index in 0..<letters {
        if let scalar = Unicode.Scalar(0x4E00 + UInt32(index) * 7) { label.unicodeScalars.append(scalar) }
    }
    return label
}

/// The label as the last label of a domain and as an inner one.
func addresses(with label: String) -> [String] { ["ada@example.\(label)", "ada@\(label).example.com"] }

func aLabelLength(_ label: String) -> Int? { IDNA.aLabel(label)?.utf8.count }

let encodedLabels: [(String, String)] = [
    ("bücher", "xn--bcher-kva"), ("BÜCHER", "xn--bcher-kva"), ("bu\u{0308}cher", "xn--bcher-kva"),
    ("例え", "xn--r8jz45g"), ("テスト", "xn--zckzah"), ("مثال", "xn--mgbh0fb"), ("إختبار", "xn--kgbechtv"),
    ("हिन्दी", "xn--j2bd4cyah0f"), ("भारत", "xn--h2brj9c"), ("İstanbul", "xn--istanbul-o0e"),
    ("Example", "example"), ("\u{212A}elvin", "kelvin"), ("xn--bcher-kva", "xn--bcher-kva"),
]

@Suite("IDNA A-labels")
struct IDNALabelTests {
    @Test("a label is lowercased and put in NFC, then written in ASCII only if it needs it", arguments: encodedLabels)
    func encoded(label: String, aLabel: String) { #expect(IDNA.aLabel(label) == aLabel) }

    @Test("a label that overflows the encoder has no A-label")
    func overflow() { #expect(IDNA.aLabel(String(repeating: "a", count: 3_855) + "\u{10FFFF}") == nil) }
}

@Suite("R6 · email domain length once encoded")
struct EmailDomainLengthTests {
    @Test("a label within 63 characters is refused when its A-label passes 63 bytes, at 63 bytes exactly it is accepted",
          arguments: [(spacedLabel(letters: 27, ascii: 1), 62, true), (spacedLabel(letters: 30), 63, true),
                      (spacedLabel(letters: 28, ascii: 1), 64, false), (spacedLabel(letters: 31), 65, false),
                      (spacedLabel(letters: 40), 83, false)])
    func labelBytes(label: String, bytes: Int, accepted: Bool) {
        #expect(label.unicodeScalars.count <= 63 && aLabelLength(label) == bytes)   // the premise: it fits in characters, not always in bytes
        for raw in addresses(with: label) { #expect((EmailAddress(raw) != nil) == accepted) }
    }

    @Test("a domain is refused when its A-labels joined by dots pass 253 bytes, although every label fits",
          arguments: [(25, 253, true), (26, 254, false)])
    func domainBytes(padding: Int, bytes: Int, accepted: Bool) {
        let labels = Array(repeating: "ü", count: 28) + [String(repeating: "a", count: padding), "com"]
        let raw = "ada@" + labels.joined(separator: ".")
        let aLabels = labels.compactMap(IDNA.aLabel)
        #expect(aLabels.count == labels.count && aLabels.allSatisfy { $0.utf8.count <= 63 })
        #expect(aLabels.joined(separator: ".").utf8.count == bytes && raw.utf8.count <= 254)
        #expect((EmailAddress(raw) != nil) == accepted)
    }

    @Test("a label is also refused past 63 characters as written, although its A-label fits",
          arguments: [(31, true), (32, false)])
    func labelCharacters(pairs: Int, accepted: Bool) {
        let label = String(repeating: "e\u{0301}", count: pairs) + (accepted ? "a" : "")   // 63 and 64 scalars
        #expect(label.unicodeScalars.count == (accepted ? 63 : 64) && (aLabelLength(label) ?? .max) <= 63)
        for raw in addresses(with: label) { #expect((EmailAddress(raw) != nil) == accepted) }
    }

    @Test("international domains that fit are accepted",
          arguments: ["ada@bücher.example", "ada@例え.テスト", "ada@مثال.إختبار", "ada@हिन्दी.भारत", "josé@BÜCHER.example",
                      "ada@" + spacedLabel(letters: 10) + ".example", "ada@\u{20000}\u{20001}.example"])
    func accepted(raw: String) { #expect(EmailAddress(raw) != nil) }

    @Test("the stored value is what was typed: not lowercased, normalised or encoded",
          arguments: ["Ada@Bücher.Example", "ada@bu\u{0308}cher.example", "ADA@例え.テスト", "ada@\u{212A}elvin.example"])
    func storedValue(raw: String) { #expect(EmailAddress(raw)?.value == raw) }
}
