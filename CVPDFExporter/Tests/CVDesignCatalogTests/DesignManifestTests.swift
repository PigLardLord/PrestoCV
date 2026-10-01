import Testing
import Foundation
import CVDesignCatalog

private func violations(of data: Data) -> [DesignPackageViolation]? {
    do throws(DesignPackageRejected) { _ = try DesignPackageValidator().validate(data); return nil } catch { return error.violations }
}

private func fragment(_ json: String) throws -> Any {
    try JSONSerialization.jsonObject(with: Data(json.utf8), options: .fragmentsAllowed)
}

private func version(_ text: String) throws -> DesignVersion {
    try #require(DesignVersion(text), "\(text) should be a version")
}

/// Texts that are not versions, built step by step: a long literal array is slow to type-check.
private let invalidVersions: [String] = {
    var texts: [String] = []
    texts.append(contentsOf: ["", "1", "1.0", "1.0.0.0", "1..0", "1.0.", ".1.0"])
    texts.append(contentsOf: ["01.0.0", "1.00.0", "1.0.00", "+1.0.0", "-1.0.0", "1.-1.0"])
    texts.append(contentsOf: ["1.0.0-beta", "1.0.0+build", "v1.0.0", "1.0.x", "1,0,0"])
    texts.append(contentsOf: [" 1.0.0", "1.0.0 ", "1. 0.0", "1.0.0\n", "1.0.0\u{2028}"])
    texts.append(contentsOf: ["9999999999.0.0", "1.9999999999.0", "1.0.9999999999", "\u{0661}.0.0"])
    return texts
}()

private let orderedPairs: [(greater: String, lesser: String)] = {
    var pairs: [(greater: String, lesser: String)] = []
    pairs.append(("1.0.10", "1.0.9"))
    pairs.append(("1.10.0", "1.9.9"))
    pairs.append(("2.0.0", "1.99.99"))
    pairs.append(("10.0.0", "9.0.0"))
    pairs.append(("1.0.1", "1.0.0"))
    pairs.append(("1.1.0", "1.0.99"))
    pairs.append(("0.0.1", "0.0.0"))
    return pairs
}()

@Suite("the manifest names a design's defaults and an ordered version (#125)")
struct DesignManifestTests {
    // MARK: Default palette and font scheme

    @Test("a package with valid defaults decodes them", arguments: NamedPalette.allCases, FontScheme.allCases)
    func defaults(palette: NamedPalette, fonts: FontScheme) throws {
        let data = designData(".cv{}", manifestExtra: ["defaultPalette": palette.rawValue, "defaultFonts": fonts.rawValue])
        let design = try DesignPackageValidator().validate(data)
        #expect(design.manifest.defaultPalette == palette && design.manifest.defaultFonts == fonts)
    }

    @Test("a missing default is a malformed manifest, not an unknown identifier", arguments: ["defaultPalette", "defaultFonts"])
    func missingDefault(key: String) {
        #expect(violations(of: designData(".cv{}", manifestWithout: [key])) == [.malformed("manifest")])
    }

    @Test("a default that is not a string is a malformed manifest", arguments: [
        ("defaultPalette", "3"), ("defaultFonts", "null"), ("defaultPalette", #"["ink"]"#), ("defaultFonts", "true"),
    ])
    func defaultNotAString(key: String, json: String) throws {
        #expect(violations(of: designData(".cv{}", manifestExtra: [key: try fragment(json)])) == [.malformed("manifest")])
    }

    @Test("an unknown palette is reported by its identifier", arguments: ["", "minimal", "Ink", "ink ", "ink\n", "../ink"])
    func unknownPalette(identifier: String) {
        #expect(violations(of: designData(".cv{}", manifestExtra: ["defaultPalette": identifier])) == [.unknownPalette(identifier)])
    }

    @Test("an unknown font scheme is reported by its identifier", arguments: ["", "comic", "Serif", "serif ", "serif\n", "Georgia"])
    func unknownFonts(identifier: String) {
        #expect(violations(of: designData(".cv{}", manifestExtra: ["defaultFonts": identifier])) == [.unknownFontScheme(identifier)])
    }

    @Test("the violations of one package add up")
    func violationsAdd() {
        let data = designData(".cv{}", id: "Bad", manifestExtra: ["version": "1", "defaultPalette": "x", "defaultFonts": "y"])
        #expect(violations(of: data) == [.invalidID("Bad"), .invalidVersion("1"), .unknownPalette("x"), .unknownFontScheme("y")])
    }

    @Test("the violations name what was wrong, quoted")
    func descriptions() {
        #expect(DesignPackageViolation.unknownPalette("minimal").description == #"unknown palette "minimal""#)
        #expect(DesignPackageViolation.unknownFontScheme("comic").description == #"unknown font scheme "comic""#)
        #expect(DesignPackageViolation.invalidVersion("1.0").description == #"invalid version "1.0""#)
        #expect(DesignPackageViolation.invalidID("Bad").description == #"invalid id "Bad""#)
        #expect(DesignPackageViolation.unknownKeys(["scripts"]).description == #"unknown keys (1): "scripts""#)
    }

    // MARK: Violations do not echo a package at length

    private static func hostile(_ violation: (String) -> DesignPackageViolation) -> [String] {
        let long = String(repeating: "a", count: 100_000)
        let escapes = "a\nb\u{1B}[31mc\u{202E}d\r\u{0}e" + String(repeating: "x", count: 100_000)
        let marks = "e" + String(repeating: "\u{301}", count: 100_000)
        return [long, escapes, marks].map { violation($0).description }
    }

    @Test("a violation prints an excerpt of the text it names: short, escaped, and marked when cut")
    func excerpts() {
        let violations: [(String) -> DesignPackageViolation] = [
            { .invalidID($0) }, { .invalidVersion($0) }, { .unknownPalette($0) }, { .unknownFontScheme($0) }, { .unknownKeys([$0]) },
        ]
        for violation in violations {
            for text in Self.hostile(violation) {
                #expect(text.count < 800)
                #expect(text.contains("…"))
                #expect(!text.contains("\n") && !text.contains("\r"))
                #expect(text.unicodeScalars.allSatisfy { $0.properties.generalCategory != .control && $0 != "\u{202E}" })
            }
        }
    }

    @Test("an excerpt keeps the first 64 scalars, escaped, and is not marked when nothing was cut")
    func excerptShape() {
        let exact = String(repeating: "a", count: 64)
        #expect(DesignPackageViolation.invalidID(exact).description == "invalid id \"\(exact)\"")
        #expect(DesignPackageViolation.invalidID(exact + "b").description == "invalid id \"\(exact)\"…")
        #expect(DesignPackageViolation.invalidID("a\nb\u{1B}c\u{202E}d").description == #"invalid id "a\nb\u{1B}c\u{202E}d""#)
    }

    @Test("a long list of unknown keys shows the first 16 and the count")
    func unknownKeys() {
        let keys = (1...20).map { "key\($0)" }
        let text = DesignPackageViolation.unknownKeys(keys).description
        #expect(text.hasPrefix("unknown keys (20): "))
        #expect(text.contains("\"key16\"") && !text.contains("\"key17\""))
        #expect(text.hasSuffix("…"))
        let few = DesignPackageViolation.unknownKeys(["a", "b"]).description
        #expect(few == #"unknown keys (2): "a", "b""#)
    }

    @Test("the violations keep the full text, so that tests and callers can compare it")
    func fullText() {
        let long = String(repeating: "a", count: 1_000)
        #expect(violations(of: designData(".cv{}", manifestExtra: ["defaultPalette": long])) == [.unknownPalette(long)])
        #expect(DesignPackageViolation.unknownPalette(long) != .unknownPalette(long + "b"))
    }

    // MARK: Version

    @Test("MAJOR.MINOR.PATCH is a version, and the manifest keeps its text", arguments: [
        "0.0.0", "1.0.0", "10.20.30", "1.0.10", "999999999.999999999.999999999",
    ])
    func validVersion(text: String) throws {
        let design = try DesignPackageValidator().validate(designData(".cv{}", manifestExtra: ["version": text]))
        #expect(design.manifest.version == DesignVersion(text) && design.manifest.version.text == text)
    }

    @Test("anything else is an invalid version", arguments: invalidVersions)
    func invalidVersion(text: String) {
        #expect(violations(of: designData(".cv{}", manifestExtra: ["version": text])) == [.invalidVersion(text)])
        #expect(DesignVersion(text) == nil)
    }

    @Test("a version that is not a string is a malformed manifest", arguments: ["1", "1.5", "null", #"["1.0.0"]"#])
    func versionNotAString(json: String) throws {
        #expect(violations(of: designData(".cv{}", manifestExtra: ["version": try fragment(json)])) == [.malformed("manifest")])
    }

    @Test("versions are compared by number, part by part", arguments: orderedPairs)
    func ordering(greater: String, lesser: String) throws {
        let (high, low) = (try version(greater), try version(lesser))
        #expect(high > low)
        #expect(low < high)
        #expect(high != low)
    }

    @Test("equal versions compare equal")
    func equality() throws {
        let (first, second) = (try version("1.2.3"), try version("1.2.3"))
        #expect(first == second)
        #expect(first <= second && first >= second)
        #expect(!(first < second) && !(first > second))
    }

    @Test("a version has one spelling, and is hashable")
    func text() throws {
        for text in ["0.0.0", "1.2.3", "10.20.30", "999999999.999999999.999999999"] { #expect(try version(text).text == text) }
        #expect(Set([try version("1.2.3"), try version("1.2.3"), try version("1.2.4")]).count == 2)
    }

    @Test("a version is stored as its text, and a text that is not a version does not decode")
    func codable() throws {
        struct Holder: Codable, Equatable { var version: DesignVersion }
        let holder = Holder(version: try version("3.4.5"))
        let json = try JSONEncoder().encode(holder)
        #expect(try JSONDecoder().decode([String: String].self, from: json) == ["version": "3.4.5"])
        #expect(try JSONDecoder().decode(Holder.self, from: json) == holder)
        for bad in [#"{"version":"1.0"}"#, #"{"version":"01.0.0"}"#, #"{"version":1}"#, #"{"version":null}"#, "{}"] {
            #expect(throws: DecodingError.self) { _ = try JSONDecoder().decode(Holder.self, from: Data(bad.utf8)) }
        }
    }

    @Test("a manifest keeps its version typed, and stores it as text")
    func manifestVersion() throws {
        let manifest = DesignManifest(id: "clean", name: "Clean", version: try version("2.0.1"), description: "", defaultPalette: .ink, defaultFonts: .system)
        let object = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(manifest)) as? [String: Any])
        #expect(object["version"] as? String == "2.0.1")
        #expect(try JSONDecoder().decode(DesignManifest.self, from: JSONEncoder().encode(manifest)) == manifest)
    }
}
