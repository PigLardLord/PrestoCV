import Testing
import Foundation
import CVDesignCatalog

private func violations(of data: Data) -> [DesignPackageViolation]? {
    do throws(DesignPackageRejected) { _ = try DesignPackageValidator().validate(data); return nil } catch { return error.violations }
}

private func name(_ text: String) -> [DesignPackageViolation]? { violations(of: designData(".cv{}", manifestExtra: ["name": text])) }
private func description(_ text: String) -> [DesignPackageViolation]? { violations(of: designData(".cv{}", manifestExtra: ["description": text])) }

/// The explicit bidirectional embeddings, overrides and isolates: U+202A–U+202E and U+2066–U+2069.
private let bidiControls: [String] = ["\u{202A}", "\u{202B}", "\u{202C}", "\u{202D}", "\u{202E}", "\u{2066}", "\u{2067}", "\u{2068}", "\u{2069}"]

/// Control characters other than `\n`.
private let controls: [String] = ["\u{0}", "\u{7}", "\t", "\r", "\u{1B}", "\u{7F}", "\u{85}", "\u{9F}"]

@Suite("a design's name and description are bounded and clean (#125)")
struct ManifestTextTests {
    @Test("a name of one to 80 Unicode scalars is accepted", arguments: [
        "a", "Clean", String(repeating: "a", count: 80), String(repeating: "\u{1F600}", count: 80), String(repeating: "e\u{301}", count: 40),
        "Modern \u{2014} two columns",
    ])
    func validName(text: String) {
        #expect(name(text) == nil)
        #expect(DesignManifest.isValidName(text))
    }

    @Test("a name over 80 scalars is refused, counted in scalars and not in characters", arguments: [
        String(repeating: "a", count: 81), String(repeating: "\u{1F600}", count: 81), String(repeating: "e\u{301}", count: 41),
    ])
    func longName(text: String) {
        #expect(name(text) == [.invalidName])
        #expect(!DesignManifest.isValidName(text))
    }

    @Test("a name with nothing but white space is empty", arguments: ["", " ", "   ", "\u{00A0}", "\u{3000}", "\u{2003} \u{2003}"])
    func emptyName(text: String) {
        #expect(name(text) == [.invalidName])
    }

    @Test("a name is one line: no control character, not even a newline", arguments: controls + ["\n", "a\nb", "\n a"])
    func controlInName(text: String) {
        #expect(name("A" + text + "B") == [.invalidName])
        #expect(!DesignManifest.isValidName("A" + text + "B"))
    }

    @Test("a name with a bidirectional embedding, override or isolate is refused", arguments: bidiControls)
    func bidiInName(control: String) {
        #expect(name("A" + control + "B") == [.invalidName])
    }

    @Test("a name may hold the characters next to the refused ranges", arguments: ["\u{2029}", "\u{202F}", "\u{2065}", "\u{206A}", "\u{200E}"])
    func neighbours(text: String) {
        #expect(name("A" + text + "B") == nil)
        #expect(description("A" + text + "B") == nil)
    }

    @Test("a description of up to 500 scalars is accepted, empty or with new lines", arguments: [
        "", "Two columns.", String(repeating: "a", count: 500), String(repeating: "\u{1F600}", count: 500), "First line.\nSecond line.\n\nThird.",
        "\n", String(repeating: "e\u{301}", count: 250),
    ])
    func validDescription(text: String) {
        #expect(description(text) == nil)
        #expect(DesignManifest.isValidDescription(text))
    }

    @Test("a description over 500 scalars is refused", arguments: [
        String(repeating: "a", count: 501), String(repeating: "\u{1F600}", count: 501), String(repeating: "e\u{301}", count: 251),
        String(repeating: "a\n", count: 251),
    ])
    func longDescription(text: String) {
        #expect(description(text) == [.invalidDescription])
        #expect(!DesignManifest.isValidDescription(text))
    }

    @Test("a description holds no control character other than the new line", arguments: controls)
    func controlInDescription(text: String) {
        #expect(description("A" + text + "B") == [.invalidDescription])
        #expect(!DesignManifest.isValidDescription("A" + text + "B"))
    }

    @Test("a description with a bidirectional embedding, override or isolate is refused", arguments: bidiControls)
    func bidiInDescription(control: String) {
        #expect(description("A" + control + "B") == [.invalidDescription])
    }

    @Test("a name of half a million scalars is refused, and the package is still read")
    func hugeName() {
        let text = String(repeating: "a", count: 500_000)
        #expect(name(text) == [.invalidName])
    }

    @Test("the violations carry no text of the package")
    func descriptions() {
        #expect(DesignPackageViolation.invalidName.description == "invalid name")
        #expect(DesignPackageViolation.invalidDescription.description == "invalid description")
    }

    @Test("the name and description are reported with the other violations, in manifest order")
    func accumulate() {
        let data = designData(".cv{}", id: "Bad", manifestExtra: ["name": "", "version": "1", "description": String(repeating: "a", count: 501)])
        #expect(violations(of: data) == [.invalidID("Bad"), .invalidName, .invalidVersion("1"), .invalidDescription])
    }
}
