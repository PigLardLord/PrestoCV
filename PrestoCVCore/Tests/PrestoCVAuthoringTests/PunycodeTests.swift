import Testing
@testable import PrestoCVDomain

/// Sample strings of RFC 3492 section 7.1, and the encodings that the RFC lists for them.
let punycodeSamples: [(String, String)] = [
    ("\u{0644}\u{064A}\u{0647}\u{0645}\u{0627}\u{0628}\u{062A}\u{0643}\u{0644}\u{0645}\u{0648}\u{0634}\u{0639}\u{0631}\u{0628}\u{064A}\u{061F}",
     "egbpdaj6bu4bxfgehfvwxn"),                                                                        // Arabic (Egyptian)
    ("\u{4ED6}\u{4EEC}\u{4E3A}\u{4EC0}\u{4E48}\u{4E0D}\u{8BF4}\u{4E2D}\u{6587}", "ihqwcrb4cv8a8dqg056pqjye"),   // Chinese (simplified)
    ("\u{4ED6}\u{5011}\u{7232}\u{4EC0}\u{9EBD}\u{4E0D}\u{8AAA}\u{4E2D}\u{6587}", "ihqwctvzc91f659drss3x8bo0yb"), // Chinese (traditional)
    ("\u{05DC}\u{05DE}\u{05D4}\u{05D4}\u{05DD}\u{05E4}\u{05E9}\u{05D5}\u{05D8}\u{05DC}\u{05D0}\u{05DE}\u{05D3}\u{05D1}\u{05E8}\u{05D9}\u{05DD}\u{05E2}\u{05D1}\u{05E8}\u{05D9}\u{05EA}",
     "4dbcagdahymbxekheh6e0a7fei0b"),                                                                  // Hebrew
    ("\u{043F}\u{043E}\u{0447}\u{0435}\u{043C}\u{0443}\u{0436}\u{0435}\u{043E}\u{043D}\u{0438}\u{043D}\u{0435}\u{0433}\u{043E}\u{0432}\u{043E}\u{0440}\u{044F}\u{0442}\u{043F}\u{043E}\u{0440}\u{0443}\u{0441}\u{0441}\u{043A}\u{0438}",
     "b1abfaaepdrnnbgefbadotcwatmq2g4l"),                                                              // Russian
    ("3\u{5E74}B\u{7D44}\u{91D1}\u{516B}\u{5148}\u{751F}", "3B-ww4c5e180e575a65lsy2b"),                // 3<nen>B<gumi><kinpachi><sensei>
    ("\u{5B89}\u{5BA4}\u{5948}\u{7F8E}\u{6075}-with-SUPER-MONKEYS", "-with-SUPER-MONKEYS-pc58ag80a8qai00g7n9n"),
    ("Hello-Another-Way-\u{305D}\u{308C}\u{305E}\u{308C}\u{306E}\u{5834}\u{6240}", "Hello-Another-Way--fc4qua05auwb3674vfr0b"),
    ("\u{3072}\u{3068}\u{3064}\u{5C4B}\u{6839}\u{306E}\u{4E0B}2", "2-u9tlzr9756bt3uc0v"),
    ("\u{305D}\u{306E}\u{30B9}\u{30D4}\u{30FC}\u{30C9}\u{3067}", "d9juau41awczczp"),
    ("-> $1.00 <-", "-> $1.00 <--"),                                                                  // ASCII only: the string, then a hyphen
]

/// Well-known labels, with the encoding every IDNA implementation gives.
let wellKnownLabels: [(String, String)] = [("bücher", "bcher-kva"), ("münchen", "mnchen-3ya"), ("例え", "r8jz45g")]

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
