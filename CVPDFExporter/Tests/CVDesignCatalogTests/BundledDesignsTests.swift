import Testing
import Foundation
@testable import CVDesignCatalog
import CVBundledDesigns

/// The designs the package ships are written against the current markup contract (#3, ADR 0011): they pass the same validator an
/// installed design does, and they style the classes the renderer emits.
@Suite("The bundled designs follow the current markup contract (#3)")
struct BundledDesignsTests {
    static let ids = ["minimal", "modern", "professional"]
    /// The classes every design must style: without them a design prints as a plain page (the symptom of #3).
    static let keyClasses = ["cv", "cv-header", "cv-name", "cv-title", "cv-contact", "cv-section", "cv-section-title",
                             "cv-entry", "cv-entry-title", "cv-entry-subtitle", "cv-entry-period", "cv-skill"]

    static func designs() async throws -> [(name: String, design: ValidatedDesign)] {
        try await BundleDesignSource().bundledPackages().map { ($0.name, try DesignPackageValidator().validate($0.data)) }
    }

    @Test("the package ships professional, modern and minimal, and each passes the validator")
    func validates() async throws {
        let packages = try await BundleDesignSource().bundledPackages()
        #expect(packages.map(\.name) == Self.ids)
        for package in packages {
            do { _ = try DesignPackageValidator().validate(package.data) } catch { Issue.record("\(package.name): \(error.violations)") }
        }
    }

    @Test("a manifest names its file, targets the current contract and carries a MAJOR.MINOR.PATCH version")
    func manifests() async throws {
        for (name, design) in try await Self.designs() {
            #expect(design.manifest.id == name && design.manifest.markupContract == MarkupContract.version)
            #expect(design.manifest.version.text.fullyMatches(#"\d+\.\d+\.\d+"#), "\(name): version \(design.manifest.version.text)")
            #expect(!design.manifest.name.isEmpty && !design.manifest.description.isEmpty)
        }
    }

    @Test("a design styles every key class, so its CSS matches what the renderer emits")
    func stylesTheKeyClasses() async throws {
        for (name, design) in try await Self.designs() {
            for cls in Self.keyClasses {
                #expect(design.stylesheet.css.range(of: "\\." + cls + "(?![a-z-])", options: .regularExpression) != nil, "\(name) never selects .\(cls)")
            }
        }
    }

    @Test("a design paints the document with the palette's background and text colour, so no palette can print unreadable text")
    func paintsWithThePalette() async throws {
        for (name, design) in try await Self.designs() {
            let rule = try #require(Self.declarations(of: ".cv", in: design.stylesheet.css), "\(name) has no rule for .cv")
            #expect(rule.contains("background-color:var(--color-background)") && rule.contains("color:var(--color-text)"), "\(name): \(rule)")
        }
    }

    @Test("each bundled design carries its preview, a PNG the validator has checked")
    func carriesAPreview() async throws {
        for (name, design) in try await Self.designs() {
            #expect(design.previewPNG?.isEmpty == false, "\(name) has no preview")
        }
    }

    /// The declarations of the rules whose selector list contains `selector` (`.cv` or `main.cv`), joined. It reads the
    /// validated canonical CSS, which the policy writes back from its tokens, so no comment or string can hold a brace;
    /// only top-level rules count, as a rule inside an at-rule's block never matches the selector.
    static func declarations(of selector: String, in css: String) -> String? {
        css.split(separator: "}").compactMap { rule -> String? in
            let parts = rule.split(separator: "{", maxSplits: 1)
            guard parts.count == 2, parts[0].split(separator: ",").map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
                .contains(where: { $0 == selector || $0 == "main" + selector }) else { return nil }
            return String(parts[1])
        }.joined(separator: ";")
        .nilIfEmpty
    }
}

private extension String { var nilIfEmpty: String? { isEmpty ? nil : self } }
