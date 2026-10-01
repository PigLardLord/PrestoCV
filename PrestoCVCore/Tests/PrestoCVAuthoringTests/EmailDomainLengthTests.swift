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

/// `xn--` and the Punycode of an already mapped label.
func wire(_ mapped: String) -> String { "xn--" + (Punycode.encode(mapped) ?? "") }

/// `count` consecutive scalars from `first`.
func scalars(from first: UInt32, count: Int) -> String {
    var text = ""
    for offset in 0..<count { if let scalar = Unicode.Scalar(first + UInt32(offset)) { text.unicodeScalars.append(scalar) } }
    return text
}

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
    cases.append(("co\u{0140}legi", "xn--collegi-xma"))              // the Catalan middle dot between two l
    cases.append(("CO\u{013F}LEGI", "xn--collegi-xma"))
    cases.append(("l\u{00B7}l", "xn--ll-0ea"))
    cases.append(("\u{1FB3}", "xn--mxaq"))                           // alpha with iota subscript is alpha, iota
    cases.append(("\u{03B1}\u{0345}", "xn--mxaq"))
    cases.append(("\u{AB70}", "xn--58d"))                            // the small Cherokee letters fold to the capitals
    cases.append(("\u{13F8}", "xn--gce"))
    cases.append(("\u{1C80}", "xn--b1a"))                            // and so do the small Cyrillic variants
    cases.append(("\u{1C88}", "xn--xw8a"))
    cases.append(("a\u{3164}b", "ab"))                               // default-ignorable code points are dropped
    cases.append(("\u{845B}\u{E0100}", "xn--pt1a"))
    cases.append(("\u{1F80}\u{0300}", "xn--dng2q"))                // each scalar is mapped alone, then the label is put in NFC once
    cases.append(("\u{03F2}", "xn--4xa"))                            // UTS 46 maps the lunate sigma and the mathematical final sigmas to sigma
    cases.append(("\u{1D6D3}", "xn--4xa"))
    cases.append(("\u{1D70D}", "xn--4xa"))
    cases.append(("\u{1D747}", "xn--4xa"))
    cases.append(("\u{1D781}", "xn--4xa"))
    cases.append(("\u{1D7BB}", "xn--4xa"))
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
    cases.append((repeated(ligature, 21) + fullwidthA, repeated("ffi", 21) + "a", false))   // 22 characters, 64 bytes mapped
    cases.append((repeated("\u{845B}\u{E0100}", 25), wire(repeated("\u{845B}", 25)), true))   // ideographic variation selectors are ignored
    cases.append((repeated("\u{1FB3}", 57), wire(repeated("\u{03B1}\u{03B9}", 57)), false))   // each maps to two letters
    cases.append((repeated("\u{03B1}\u{0345}", 31) + "\u{03B1}", wire(repeated("\u{03B1}\u{03B9}", 31) + "\u{03B1}"), false))
    cases.append((scalars(from: 0x13A0, count: 41), wire(scalars(from: 0x13A0, count: 41)), true))   // 63 bytes
    cases.append((scalars(from: 0xAB70, count: 41), wire(scalars(from: 0x13A0, count: 41)), true))   // small letters fold to them
    cases.append((scalars(from: 0x13A0, count: 42), wire(scalars(from: 0x13A0, count: 42)), false))
    let accents = repeated("\u{1F80}\u{0300}\u{1FB3}", 12)   // 36 characters; 64 bytes, not 60, when mapped scalar by scalar
    cases.append((accents, "xn--mxaaaaaaaaaaaa7gbbbbbbbbbbb5665ocacccccccccc744bdadddddddddd", false))
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
    labels.append("a\u{0140}b")         // LATIN SMALL LETTER L WITH MIDDLE DOT maps to "l" and a middle dot: not between two l
    labels.append("\u{0140}")
    labels.append("l\u{00B7}")
    labels.append("\u{00B7}l")
    labels.append("a\u{00B7}l")
    labels.append("\u{3164}")           // default-ignorable code points are dropped, which leaves nothing
    labels.append("\u{FFA0}")
    labels.append("\u{FE0F}")
    labels.append("a\u{200D}b")         // joiners are not ignored: they are refused
    labels.append("a\u{200C}b")
    return labels
}()

/// Addresses whose domain holds a label that is valid as written and not once mapped.
let unmappableAddresses: [String] = {
    var addresses: [String] = []
    addresses.append("ada@\u{2488}.example.com")
    addresses.append("ada@a\u{2488}b.example.com")
    addresses.append("ada@\u{FF9E}a.example.com")
    addresses.append("ada@a\u{2474}.example.com")
    addresses.append("ada@a\u{0140}b.example.com")
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
    addresses.append("ada@co\u{0140}legi.cat")
    addresses.append("ada@CO\u{013F}LEGI.cat")
    addresses.append("ada@" + String(repeating: "\u{845B}\u{E0100}", count: 25) + ".jp")
    return addresses
}()

let typedAddresses: [String] = {
    var addresses: [String] = []
    addresses.append("Ada@Bücher.Example")
    addresses.append("ada@bu\u{0308}cher.example")
    addresses.append("ADA@例え.テスト")
    addresses.append("ada@\u{212A}elvin.example")
    addresses.append("ada@co\u{0140}legi.cat")
    addresses.append("x\u{FE0F}@example.com")
    return addresses
}()

/// Addresses with an invisible filler or another default-ignorable code point that is not a variation selector.
let hiddenAddresses: [String] = {
    var addresses: [String] = []
    addresses.append("\u{3164}ada@example.com")
    addresses.append("ada\u{FFA0}@example.com")
    addresses.append("a\u{034F}da@example.com")
    addresses.append("ada@exa\u{3164}mple.com")
    addresses.append("ada@\u{3164}.example.com")
    addresses.append("ada@a\u{FFA0}.example.com")
    return addresses
}()

/// Every scalar that case folding changes after lowercasing and that UTS 46 folds, with its folding (CaseFolding.txt,
/// Unicode 16, status C): the combining iota subscript, the small Cherokee letters, and the small Cyrillic variants.
let caseFoldingEntries: [(UInt32, UInt32)] = {
    var cases: [(UInt32, UInt32)] = []
    cases.append((0x0345, 0x03B9))
    cases.append((0xAB70, 0x13A0))
    cases.append((0xAB71, 0x13A1))
    cases.append((0xAB72, 0x13A2))
    cases.append((0xAB73, 0x13A3))
    cases.append((0xAB74, 0x13A4))
    cases.append((0xAB75, 0x13A5))
    cases.append((0xAB76, 0x13A6))
    cases.append((0xAB77, 0x13A7))
    cases.append((0xAB78, 0x13A8))
    cases.append((0xAB79, 0x13A9))
    cases.append((0xAB7A, 0x13AA))
    cases.append((0xAB7B, 0x13AB))
    cases.append((0xAB7C, 0x13AC))
    cases.append((0xAB7D, 0x13AD))
    cases.append((0xAB7E, 0x13AE))
    cases.append((0xAB7F, 0x13AF))
    cases.append((0xAB80, 0x13B0))
    cases.append((0xAB81, 0x13B1))
    cases.append((0xAB82, 0x13B2))
    cases.append((0xAB83, 0x13B3))
    cases.append((0xAB84, 0x13B4))
    cases.append((0xAB85, 0x13B5))
    cases.append((0xAB86, 0x13B6))
    cases.append((0xAB87, 0x13B7))
    cases.append((0xAB88, 0x13B8))
    cases.append((0xAB89, 0x13B9))
    cases.append((0xAB8A, 0x13BA))
    cases.append((0xAB8B, 0x13BB))
    cases.append((0xAB8C, 0x13BC))
    cases.append((0xAB8D, 0x13BD))
    cases.append((0xAB8E, 0x13BE))
    cases.append((0xAB8F, 0x13BF))
    cases.append((0xAB90, 0x13C0))
    cases.append((0xAB91, 0x13C1))
    cases.append((0xAB92, 0x13C2))
    cases.append((0xAB93, 0x13C3))
    cases.append((0xAB94, 0x13C4))
    cases.append((0xAB95, 0x13C5))
    cases.append((0xAB96, 0x13C6))
    cases.append((0xAB97, 0x13C7))
    cases.append((0xAB98, 0x13C8))
    cases.append((0xAB99, 0x13C9))
    cases.append((0xAB9A, 0x13CA))
    cases.append((0xAB9B, 0x13CB))
    cases.append((0xAB9C, 0x13CC))
    cases.append((0xAB9D, 0x13CD))
    cases.append((0xAB9E, 0x13CE))
    cases.append((0xAB9F, 0x13CF))
    cases.append((0xABA0, 0x13D0))
    cases.append((0xABA1, 0x13D1))
    cases.append((0xABA2, 0x13D2))
    cases.append((0xABA3, 0x13D3))
    cases.append((0xABA4, 0x13D4))
    cases.append((0xABA5, 0x13D5))
    cases.append((0xABA6, 0x13D6))
    cases.append((0xABA7, 0x13D7))
    cases.append((0xABA8, 0x13D8))
    cases.append((0xABA9, 0x13D9))
    cases.append((0xABAA, 0x13DA))
    cases.append((0xABAB, 0x13DB))
    cases.append((0xABAC, 0x13DC))
    cases.append((0xABAD, 0x13DD))
    cases.append((0xABAE, 0x13DE))
    cases.append((0xABAF, 0x13DF))
    cases.append((0xABB0, 0x13E0))
    cases.append((0xABB1, 0x13E1))
    cases.append((0xABB2, 0x13E2))
    cases.append((0xABB3, 0x13E3))
    cases.append((0xABB4, 0x13E4))
    cases.append((0xABB5, 0x13E5))
    cases.append((0xABB6, 0x13E6))
    cases.append((0xABB7, 0x13E7))
    cases.append((0xABB8, 0x13E8))
    cases.append((0xABB9, 0x13E9))
    cases.append((0xABBA, 0x13EA))
    cases.append((0xABBB, 0x13EB))
    cases.append((0xABBC, 0x13EC))
    cases.append((0xABBD, 0x13ED))
    cases.append((0xABBE, 0x13EE))
    cases.append((0xABBF, 0x13EF))
    cases.append((0x13F8, 0x13F0))
    cases.append((0x13F9, 0x13F1))
    cases.append((0x13FA, 0x13F2))
    cases.append((0x13FB, 0x13F3))
    cases.append((0x13FC, 0x13F4))
    cases.append((0x13FD, 0x13F5))
    cases.append((0x1C80, 0x0432))
    cases.append((0x1C81, 0x0434))
    cases.append((0x1C82, 0x043E))
    cases.append((0x1C83, 0x0441))
    cases.append((0x1C84, 0x0442))
    cases.append((0x1C85, 0x0442))
    cases.append((0x1C86, 0x044A))
    cases.append((0x1C87, 0x0463))
    cases.append((0x1C88, 0xA64B))
    return cases
}()

/// Scalars next to the folded ranges, which stay as they are, and the two that non-transitional processing keeps.
let unfoldedScalars: [UInt32] = {
    var scalars: [UInt32] = []
    scalars.append(0x0344)
    scalars.append(0x0346)
    scalars.append(0xAB6F)
    scalars.append(0xABC0)
    scalars.append(0x13F7)
    scalars.append(0x13FE)
    scalars.append(0x1C7F)
    scalars.append(0x1C89)
    scalars.append(0x00DF)   // the sharp s
    scalars.append(0x03C2)   // the final sigma
    return scalars
}()

@Suite("IDNA A-labels")
struct IDNALabelTests {
    @Test("a label is mapped as IDNA maps it, then written in ASCII only if it needs it", arguments: encodedLabels)
    func encoded(label: String, aLabel: String) { #expect(IDNA.aLabel(label) == aLabel) }

    @Test("every scalar that case folding changes after lowercasing is folded as CaseFolding.txt says", arguments: caseFoldingEntries)
    func caseFolding(scalar: UInt32, folded: UInt32) {
        #expect(Unicode.Scalar(scalar).map(IDNA.caseFolded)?.value == folded)
    }

    @Test("the scalars next to the folded ranges, the sharp s and the final sigma are left as they are", arguments: unfoldedScalars)
    func notFolded(scalar: UInt32) { #expect(Unicode.Scalar(scalar).map(IDNA.caseFolded)?.value == scalar) }

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

    @Test("an invisible filler is refused anywhere in an address; variation selectors are not fillers", arguments: hiddenAddresses)
    func hidden(raw: String) { #expect(EmailAddress(raw) == nil) }

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
