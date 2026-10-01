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
    try DesignPackageValidator().validate(designData(".cv{}", manifestExtra: ["version": text])).version
}

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

    @Test("the violations name what was wrong")
    func descriptions() {
        #expect(DesignPackageViolation.unknownPalette("minimal").description == "unknown palette minimal")
        #expect(DesignPackageViolation.unknownFontScheme("comic").description == "unknown font scheme comic")
        #expect(DesignPackageViolation.invalidVersion("1.0").description == "invalid version 1.0")
    }

    // MARK: Version

    @Test("MAJOR.MINOR.PATCH is a version, and the manifest keeps its text", arguments: [
        "0.0.0", "1.0.0", "10.20.30", "1.0.10", "999999999.999999999.999999999",
    ])
    func validVersion(text: String) throws {
        let design = try DesignPackageValidator().validate(designData(".cv{}", manifestExtra: ["version": text]))
        #expect(design.manifest.version == text)
    }

    @Test("anything else is an invalid version", arguments: [
        "", "1", "1.0", "1.0.0.0", "1..0", "1.0.", ".1.0", "01.0.0", "1.00.0", "1.0.00", "+1.0.0", "-1.0.0", "1.-1.0", "1.0.0-beta",
        "1.0.0+build", "v1.0.0", "1.0.x", " 1.0.0", "1.0.0 ", "1. 0.0", "1.0.0\n", "1.0.0\u{2028}", "9999999999.0.0", "1.9999999999.0",
        "1.0.9999999999", "\u{0661}.0.0", "1,0,0",
    ])
    func invalidVersion(text: String) {
        #expect(violations(of: designData(".cv{}", manifestExtra: ["version": text])) == [.invalidVersion(text)])
    }

    @Test("a version that is not a string is a malformed manifest", arguments: ["1", "1.5", "null", #"["1.0.0"]"#])
    func versionNotAString(json: String) throws {
        #expect(violations(of: designData(".cv{}", manifestExtra: ["version": try fragment(json)])) == [.malformed("manifest")])
    }

    @Test("versions are compared by number, part by part", arguments: [
        ("1.0.10", "1.0.9"), ("1.10.0", "1.9.9"), ("2.0.0", "1.99.99"), ("10.0.0", "9.0.0"), ("1.0.1", "1.0.0"), ("1.1.0", "1.0.99"),
        ("0.0.1", "0.0.0"),
    ])
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

    @Test("a validated design carries the parsed version of its manifest")
    func validatedDesignVersion() throws {
        let design = try DesignPackageValidator().validate(designData(".cv{}", manifestExtra: ["version": "3.4.5"]))
        let (before, same, after) = (try version("3.4.4"), try version("3.4.5"), try version("3.4.6"))
        #expect(design.version == same)
        #expect(design.version > before && design.version < after)
    }
}
