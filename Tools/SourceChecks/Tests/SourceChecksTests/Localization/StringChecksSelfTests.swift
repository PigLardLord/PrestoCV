import Foundation
import Testing

/// The string checks, run on a small catalog and a small source that plant one defect of each kind. A check that finds
/// nothing in a catalog full of defects would pass every real catalog, so each kind is shown to be found here.
@Suite("The string checks find a planted defect of each kind")
struct StringChecksSelfTests {
    private static let planted = Repository.root.appendingPathComponent("Tools/SourceChecks/Tests/SourceChecksTests/Localization/Planted")

    private static func run(rules: StringRules = StringRules()) throws -> StringFindings {
        try StringChecks.run(
            catalog: planted.appendingPathComponent("Localizable.xcstrings"),
            sources: [planted.appendingPathComponent("PlantedViews.swift")],
            rules: rules
        )
    }

    @Test("A language missing from a key is found")
    func missingLanguage() throws {
        #expect(try Self.run().missingLanguage == ["plant.no_german (de)"])
    }

    @Test("A text in a state other than translated is found")
    func notTranslated() throws {
        #expect(try Self.run().notTranslated == ["plant.not_translated (es)"])
    }

    @Test("A text copied from English is found")
    func copiedFromEnglish() throws {
        #expect(try Self.run().copiedFromEnglish == ["plant.copied (fr)"])
    }

    @Test("A text with other placeholders than the English one is found")
    func otherPlaceholders() throws {
        #expect(try Self.run().otherPlaceholders == ["plant.placeholders (it)"])
    }

    @Test("A promise of availability is found in any language")
    func availabilityPromise() throws {
        let promises = try Self.run().availabilityPromises
        #expect(promises.count == 6, "\(promises)")
        #expect(promises.allSatisfy { $0.hasPrefix("plant.promise (") }, "\(promises)")
    }

    @Test("English title case in Spanish, French, Italian or Portuguese is found")
    func titleCase() throws {
        let found = try Self.run().titleCase
        #expect(found.count == 1 && found[0].hasPrefix("plant.title_case (es)"), "\(found)")
    }

    @Test("A key that no source looks up is found")
    func unusedKey() throws {
        #expect(try Self.run().unused == ["plant.unused"])
    }

    @Test("A key that a source looks up and the catalog lacks is found")
    func lookedUpButMissing() throws {
        let found = try Self.run().lookedUpButMissing
        #expect(found.count == 1 && found[0].hasPrefix("plant.absent"), "\(found)")
    }

    @Test("An exemption removes only the finding it names")
    func exemptionsRemoveOneFinding() throws {
        var rules = StringRules()
        rules.sameInSomeLanguages = ["plant.copied": ["fr"]]
        rules.pendingKeys = ["plant.unused"]
        let findings = try Self.run(rules: rules)
        #expect(findings.copiedFromEnglish.isEmpty)
        #expect(findings.unused.isEmpty)
        #expect(findings.missingLanguage == ["plant.no_german (de)"])
    }
}
