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
func addresses(with label: String) -> [String] {
    var addresses: [String] = []
    addresses.append("ada@example." + label)
    addresses.append("ada@" + label + ".example.com")
    return addresses
}

func aLabelLength(_ label: String) -> Int? { IDNA.aLabel(label)?.utf8.count }

/// MALAYALAM LETTER DOT REPH, a letter that grapheme clusters join to the scalar after it.
let prependLetter = "\u{0D4E}"

let encodedLabels: [(String, String)] = {
    var cases: [(String, String)] = []
    cases.append(("bücher", "xn--bcher-kva"))
    cases.append(("BÜCHER", "xn--bcher-kva"))
    cases.append(("bu\u{0308}cher", "xn--bcher-kva"))
    cases.append(("例え", "xn--r8jz45g"))
    cases.append(("テスト", "xn--zckzah"))
    cases.append(("مثال", "xn--mgbh0fb"))
    cases.append(("إختبار", "xn--kgbechtv"))
    cases.append(("हिन्दी", "xn--j2bd4cyah0f"))
    cases.append(("भारत", "xn--h2brj9c"))
    cases.append(("İstanbul", "xn--istanbul-o0e"))
    cases.append(("Example", "example"))
    cases.append(("\u{212A}elvin", "kelvin"))
    cases.append(("xn--bcher-kva", "xn--bcher-kva"))
    cases.append(("a" + prependLetter, "xn--a-mmf"))
    cases.append(("a-b", "a-b"))
    cases.append(("straße", "xn--strae-oqa"))                       // non-transitional: the sharp s stays
    cases.append(("οδυσσεύς", "xn--pxac2aodam1e"))                  // and so does the final sigma
    cases.append(("\u{FF21}\u{FF22}", "ab"))                        // fullwidth capitals map to ASCII letters
    cases.append(("\u{FB03}", "ffi"))
    cases.append(("\u{FB03}b\u{FF21}", "ffiba"))
    cases.append(("\u{03AA}\u{0300}", "xn--dtg"))                    // lowercasing decomposes it, and NFC puts it back together
    return cases
}()

/// Labels that IDNA maps to other letters before it encodes them: the label, its A-label and whether an address holding
/// the label is accepted.
let mappedLabelCases: [(String, String, Bool)] = {
    func repeated(_ text: String, _ count: Int) -> String { String(repeating: text, count: count) }
    let fullwidthA = "\u{FF41}", ligature = "\u{FB03}", longS = "\u{017F}"
    var cases: [(String, String, Bool)] = []
    cases.append((repeated(fullwidthA, 58), repeated("a", 58), true))
    cases.append((repeated(fullwidthA, 63), repeated("a", 63), true))
    cases.append((repeated(fullwidthA, 64), repeated("a", 64), false))
    cases.append((repeated(ligature, 21), repeated("ffi", 21), true))
    cases.append((repeated(ligature, 22), repeated("ffi", 22), false))
    cases.append((repeated(longS, 63), repeated("s", 63), true))
    return cases
}()

/// Labels whose mapping is not a label: it holds a dot, it starts or ends with a hyphen, it starts with a mark or it is empty.
let notLabels: [String] = {
    var labels: [String] = []
    labels.append("")
    labels.append("-abc")
    labels.append("abc-")
    labels.append("a.b")
    labels.append("\u{2488}")           // DIGIT ONE FULL STOP maps to "1."
    labels.append("a\u{2488}b")
    labels.append("\u{FF9E}a")          // HALFWIDTH KATAKANA VOICED SOUND MARK maps to a combining mark
    labels.append("a\u{2474}")          // PARENTHESIZED DIGIT ONE maps to "(1)"
    return labels
}()

/// Addresses whose domain holds a label that is valid as written and not once mapped.
let unmappableAddresses: [String] = {
    var addresses: [String] = []
    addresses.append("ada@\u{2488}.example.com")
    addresses.append("ada@a\u{2488}b.example.com")
    addresses.append("ada@\u{FF9E}a.example.com")
    addresses.append("ada@a\u{2474}.example.com")
    return addresses
}()

/// Labels of at most 63 characters, with the length of their A-label and whether an address holding them is accepted.
let labelByteCases: [(String, Int, Bool)] = {
    let dense57 = String(repeating: "\u{00E9}", count: 57), dense58 = String(repeating: "\u{00E9}", count: 58)
    var cases: [(String, Int, Bool)] = []
    cases.append((spacedLabel(letters: 27, ascii: 1), 62, true))
    cases.append((spacedLabel(letters: 30), 63, true))
    cases.append((spacedLabel(letters: 28, ascii: 1), 64, false))
    cases.append((spacedLabel(letters: 31), 65, false))
    cases.append((spacedLabel(letters: 40), 83, false))
    cases.append((dense57, 63, true))     // the densest label: one byte per character after the first
    cases.append((dense58, 64, false))
    return cases
}()

/// Addresses with 28 one-letter international labels and `padding` letters in the next one: padding, bytes on the wire
/// (local part, "@" and the A-labels joined by dots) and whether the address is accepted.
let wireCases: [(Int, Int, Bool)] = {
    var cases: [(Int, Int, Bool)] = []
    cases.append((22, 254, true))
    cases.append((23, 255, false))
    cases.append((25, 257, false))
    return cases
}()

/// Labels of pairs "e" and a combining accent, then "a" when accepted: 63 and 64 scalars, both with a short A-label.
let labelCharacterCases: [(Int, Bool)] = {
    var cases: [(Int, Bool)] = []
    cases.append((31, true))
    cases.append((32, false))
    return cases
}()

/// Labels that end in a letter which grapheme clusters join to the dot after it: letters before it, A-label length, accepted.
let prependLabelCases: [(Int, Int, Bool)] = {
    var cases: [(Int, Int, Bool)] = []
    cases.append((54, 63, true))
    cases.append((55, 64, false))
    return cases
}()

let internationalAddresses: [String] = {
    var addresses: [String] = []
    addresses.append("ada@bücher.example")
    addresses.append("ada@例え.テスト")
    addresses.append("ada@مثال.إختبار")
    addresses.append("ada@हिन्दी.भारत")
    addresses.append("josé@BÜCHER.example")
    addresses.append("ada@" + spacedLabel(letters: 10) + ".example")
    addresses.append("ada@\u{20000}\u{20001}.example")
    return addresses
}()

let typedAddresses: [String] = {
    var addresses: [String] = []
    addresses.append("Ada@Bücher.Example")
    addresses.append("ada@bu\u{0308}cher.example")
    addresses.append("ADA@例え.テスト")
    addresses.append("ada@\u{212A}elvin.example")
    return addresses
}()

@Suite("IDNA A-labels")
struct IDNALabelTests {
    @Test("a label is mapped as IDNA maps it, then written in ASCII only if it needs it", arguments: encodedLabels)
    func encoded(label: String, aLabel: String) { #expect(IDNA.aLabel(label) == aLabel) }

    @Test("a label whose mapping is not a label has no A-label", arguments: notLabels)
    func notALabel(label: String) { #expect(IDNA.aLabel(label) == nil) }

    @Test("a label that overflows the encoder has no A-label")
    func overflow() {
        // The last CJK ideograph of Unicode 15 costs (U+323AF - 128) * (basic scalars + 1) in the encoder.
        let ideograph = "\u{323AF}"
        #expect(IDNA.aLabel(String(repeating: "a", count: 20_000) + ideograph) != nil)
        #expect(IDNA.aLabel(String(repeating: "a", count: 25_000) + ideograph) == nil)
    }
}

@Suite("R6 · email domain length once encoded")
struct EmailDomainLengthTests {
    @Test("a label within 63 characters is refused when its A-label passes 63 bytes, at 63 bytes exactly it is accepted",
          arguments: labelByteCases)
    func labelBytes(label: String, bytes: Int, accepted: Bool) {
        #expect(label.unicodeScalars.count <= 63 && aLabelLength(label) == bytes)   // the premise: it fits in characters, not always in bytes
        for raw in addresses(with: label) { #expect((EmailAddress(raw) != nil) == accepted) }
    }

    @Test("an address is accepted only when its local part, the at sign and the A-labels of its domain fit in 254 bytes",
          arguments: wireCases)
    func wireBytes(padding: Int, bytes: Int, accepted: Bool) {
        var labels = [String](repeating: "\u{00FC}", count: 28)
        labels.append(String(repeating: "a", count: padding))
        labels.append("com")
        let local = "ada", raw = local + "@" + labels.joined(separator: ".")
        let aLabels = labels.compactMap(IDNA.aLabel)
        #expect(aLabels.count == labels.count && aLabels.allSatisfy { $0.utf8.count <= 63 })   // every label fits
        #expect(local.utf8.count + 1 + aLabels.joined(separator: ".").utf8.count == bytes)
        #expect(raw.utf8.count <= 254)   // as typed it fits
        #expect((EmailAddress(raw) != nil) == accepted)
    }

    @Test("a label is also refused past 63 characters as written, although its A-label fits",
          arguments: labelCharacterCases)
    func labelCharacters(pairs: Int, accepted: Bool) {
        let label = String(repeating: "e\u{0301}", count: pairs) + (accepted ? "a" : "")   // 63 and 64 scalars
        #expect(label.unicodeScalars.count == (accepted ? 63 : 64) && (aLabelLength(label) ?? .max) <= 63)
        for raw in addresses(with: label) { #expect((EmailAddress(raw) != nil) == accepted) }
    }

    @Test("a label is measured as IDNA maps it: fullwidth letters and ligatures count as the letters they stand for",
          arguments: mappedLabelCases)
    func mappedLabelBytes(label: String, aLabel: String, accepted: Bool) {
        #expect(IDNA.aLabel(label) == aLabel && (aLabel.utf8.count <= 63) == accepted)   // the premise
        for raw in addresses(with: label) { #expect((EmailAddress(raw) != nil) == accepted) }
    }

    @Test("an address whose label is not a label once mapped is refused", arguments: unmappableAddresses)
    func unmappableLabel(raw: String) { #expect(EmailAddress(raw) == nil) }

    @Test("a label ending in a letter that grapheme clusters join to the next dot is measured on its own",
          arguments: prependLabelCases)
    func labelBeforeDot(letters: Int, bytes: Int, accepted: Bool) {
        let label = String(repeating: "b", count: letters) + prependLetter
        #expect(aLabelLength(label) == bytes)
        #expect((EmailAddress("ada@" + label + ".example.com") != nil) == accepted)
    }

    @Test("two labels that fit are not measured as one because the first ends in a letter joined to the dot")
    func neighbouringLabels() {
        let first = String(repeating: "b", count: 30) + prependLetter, second = String(repeating: "c", count: 40)
        #expect(aLabelLength(first) == 39 && aLabelLength(second) == 40)
        #expect(EmailAddress("ada@" + first + "." + second + ".example.com") != nil)
    }

    @Test("a short label ending in a letter joined to the dot is accepted, measured alone")
    func shortLabelBeforeDot() {
        #expect(aLabelLength("a" + prependLetter) == 9)
        #expect(EmailAddress("ada@a" + prependLetter + ".example.com") != nil)
    }

    @Test("a local part ending in a letter joined to the at sign is accepted, and kept as written")
    func localPartBeforeAt() {
        let raw = "x" + prependLetter + "@example.com"
        #expect(EmailAddress(raw)?.value == raw)
    }

    @Test("international domains that fit are accepted", arguments: internationalAddresses)
    func accepted(raw: String) { #expect(EmailAddress(raw) != nil) }

    @Test("the stored value is what was typed: not lowercased, normalised or encoded", arguments: typedAddresses)
    func storedValue(raw: String) { #expect(EmailAddress(raw)?.value == raw) }
}
