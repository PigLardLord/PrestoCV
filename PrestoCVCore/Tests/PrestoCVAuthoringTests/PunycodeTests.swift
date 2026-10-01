import Testing
@testable import PrestoCVDomain

/// Every sample string of RFC 3492 section 7.1, with the encoding that the RFC lists for it.
let punycodeSamples: [(String, String)] = {
    var samples: [(String, String)] = []
    samples.append(("\u{0644}\u{064A}\u{0647}\u{0645}\u{0627}\u{0628}\u{062A}\u{0643}\u{0644}\u{0645}\u{0648}\u{0634}\u{0639}\u{0631}\u{0628}\u{064A}\u{061F}",
                    "egbpdaj6bu4bxfgehfvwxn"))   // Arabic (Egyptian)
    samples.append(("\u{4ED6}\u{4EEC}\u{4E3A}\u{4EC0}\u{4E48}\u{4E0D}\u{8BF4}\u{4E2D}\u{6587}",
                    "ihqwcrb4cv8a8dqg056pqjye"))   // Chinese (simplified)
    samples.append(("\u{4ED6}\u{5011}\u{7232}\u{4EC0}\u{9EBD}\u{4E0D}\u{8AAA}\u{4E2D}\u{6587}",
                    "ihqwctvzc91f659drss3x8bo0yb"))   // Chinese (traditional)
    samples.append(("Pro\u{010D}prost\u{011B}nemluv\u{00ED}\u{010D}esky", "Proprostnemluvesky-uyb24dma41a"))   // Czech
    samples.append(("\u{05DC}\u{05DE}\u{05D4}\u{05D4}\u{05DD}\u{05E4}\u{05E9}\u{05D5}\u{05D8}\u{05DC}\u{05D0}\u{05DE}\u{05D3}\u{05D1}\u{05E8}\u{05D9}\u{05DD}\u{05E2}\u{05D1}\u{05E8}\u{05D9}\u{05EA}",
                    "4dbcagdahymbxekheh6e0a7fei0b"))   // Hebrew
    samples.append(("\u{092F}\u{0939}\u{0932}\u{094B}\u{0917}\u{0939}\u{093F}\u{0928}\u{094D}\u{0926}\u{0940}\u{0915}\u{094D}\u{092F}\u{094B}\u{0902}\u{0928}\u{0939}\u{0940}\u{0902}\u{092C}\u{094B}\u{0932}\u{0938}\u{0915}\u{0924}\u{0947}\u{0939}\u{0948}\u{0902}",
                    "i1baa7eci9glrd9b2ae1bj0hfcgg6iyaf8o0a1dig0cd"))   // Hindi (Devanagari)
    samples.append(("\u{306A}\u{305C}\u{307F}\u{3093}\u{306A}\u{65E5}\u{672C}\u{8A9E}\u{3092}\u{8A71}\u{3057}\u{3066}\u{304F}\u{308C}\u{306A}\u{3044}\u{306E}\u{304B}",
                    "n8jok5ay5dzabd5bym9f0cm5685rrjetr6pdxa"))   // Japanese (kanji and hiragana)
    samples.append(("\u{C138}\u{ACC4}\u{C758}\u{BAA8}\u{B4E0}\u{C0AC}\u{B78C}\u{B4E4}\u{C774}\u{D55C}\u{AD6D}\u{C5B4}\u{B97C}\u{C774}\u{D574}\u{D55C}\u{B2E4}\u{BA74}\u{C5BC}\u{B9C8}\u{B098}\u{C88B}\u{C744}\u{AE4C}",
                    "989aomsvi5e83db1d2a355cv1e0vak1dwrv93d5xbh15a0dt30a5jpsd879ccm6fea98c"))   // Korean (Hangul syllables)
    samples.append(("\u{043F}\u{043E}\u{0447}\u{0435}\u{043C}\u{0443}\u{0436}\u{0435}\u{043E}\u{043D}\u{0438}\u{043D}\u{0435}\u{0433}\u{043E}\u{0432}\u{043E}\u{0440}\u{044F}\u{0442}\u{043F}\u{043E}\u{0440}\u{0443}\u{0441}\u{0441}\u{043A}\u{0438}",
                    "b1abfaaepdrnnbgefbadotcwatmq2g4l"))   // Russian (Cyrillic)
    samples.append(("Porqu\u{00E9}nopuedensimplementehablarenEspa\u{00F1}ol", "PorqunopuedensimplementehablarenEspaol-fmd56a"))   // Spanish
    samples.append(("T\u{1EA1}isaoh\u{1ECD}kh\u{00F4}ngth\u{1EC3}ch\u{1EC9}n\u{00F3}iti\u{1EBF}ngVi\u{1EC7}t",
                    "TisaohkhngthchnitingVit-kjcr8268qyxafd2f1b9g"))   // Vietnamese
    samples.append(("3\u{5E74}B\u{7D44}\u{91D1}\u{516B}\u{5148}\u{751F}", "3B-ww4c5e180e575a65lsy2b"))   // 3<nen>B<gumi><kinpachi><sensei>
    samples.append(("\u{5B89}\u{5BA4}\u{5948}\u{7F8E}\u{6075}-with-SUPER-MONKEYS", "-with-SUPER-MONKEYS-pc58ag80a8qai00g7n9n"))   // <amuro><namie>-with-SUPER-MONKEYS
    samples.append(("Hello-Another-Way-\u{305D}\u{308C}\u{305E}\u{308C}\u{306E}\u{5834}\u{6240}",
                    "Hello-Another-Way--fc4qua05auwb3674vfr0b"))   // Hello-Another-Way-<sorezore><no><basho>
    samples.append(("\u{3072}\u{3068}\u{3064}\u{5C4B}\u{6839}\u{306E}\u{4E0B}2", "2-u9tlzr9756bt3uc0v"))   // <hitotsu><yane><no><shita>2
    samples.append(("Maji\u{3067}Koi\u{3059}\u{308B}5\u{79D2}\u{524D}", "MajiKoi5-783gue6qz075azm5e"))   // Maji<de>Koi<suru>5<byou><mae>
    samples.append(("\u{30D1}\u{30D5}\u{30A3}\u{30FC}de\u{30EB}\u{30F3}\u{30D0}", "de-jg4avhby1noc0d"))   // <pafii>de<runba>
    samples.append(("\u{305D}\u{306E}\u{30B9}\u{30D4}\u{30FC}\u{30C9}\u{3067}", "d9juau41awczczp"))   // <sono><supiido><de>
    samples.append(("-> $1.00 <-", "-> $1.00 <--"))   // ASCII only
    return samples
}()

/// Well-known labels, with the encoding every IDNA implementation gives.
let wellKnownLabels: [(String, String)] = {
    var labels: [(String, String)] = []
    labels.append(("bücher", "bcher-kva"))
    labels.append(("münchen", "mnchen-3ya"))
    labels.append(("例え", "r8jz45g"))
    return labels
}()

@Suite("Punycode encoding")
struct PunycodeTests {
    @Test("the strings of RFC 3492 section 7.1 encode as the RFC lists", arguments: punycodeSamples)
    func rfcSamples(label: String, encoded: String) { #expect(Punycode.encode(label) == encoded) }

    @Test("well-known labels encode as every IDNA implementation encodes them", arguments: wellKnownLabels)
    func wellKnown(label: String, encoded: String) { #expect(Punycode.encode(label) == encoded) }

    @Test("an empty label encodes as an empty string") func emptyLabel() { #expect(Punycode.encode("") == "") }

    @Test("an input too long for the 32-bit counters is refused instead of overflowing")
    func overflow() {
        // The first non-ASCII scalar costs (U+10FFFF - 128) * (basic scalars + 1): 3855 steps still fit in 32 bits, 3856 do not.
        let farthest = "\u{10FFFF}"
        #expect(Punycode.encode(String(repeating: "a", count: 3_854) + farthest) != nil)
        #expect(Punycode.encode(String(repeating: "a", count: 3_855) + farthest) == nil)
    }
}
