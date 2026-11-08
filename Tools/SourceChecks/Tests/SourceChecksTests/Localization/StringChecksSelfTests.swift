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
        #expect(try Self.run().notTranslated.contains("plant.not_translated (es)"))
    }

    @Test("An empty text is found, in a translated language and in English")
    func emptyText() throws {
        let found = try Self.run().notTranslated
        #expect(found.contains("plant.empty_translation (de)"), "\(found)")
        #expect(found.contains("plant.empty_english (en)"), "\(found)")
    }

    @Test("An English text with no state, or a state other than translated, is found")
    func unmarkedEnglish() throws {
        let found = try Self.run().notTranslated
        #expect(found.contains("plant.unmarked_english (en)"), "\(found)")
        #expect(found.contains("plant.review_english (en)"), "\(found)")
    }

    @Test("A plural form after the first that is not translated, has no text or an empty one is found")
    func laterPluralForm() throws {
        let found = try Self.run().notTranslated
        #expect(found.contains("plant.plural_review (de)"), "\(found)")
        #expect(found.contains("plant.plural_no_value (de)"), "\(found)")
        #expect(found.contains("plant.plural_empty (de)"), "\(found)")
    }

    @Test("Nothing else is reported as empty or not translated")
    func onlyThePlantedOnes() throws {
        #expect(Set(try Self.run().notTranslated) == [
            "plant.not_translated (es)", "plant.empty_translation (de)", "plant.empty_english (en)",
            "plant.unmarked_english (en)", "plant.review_english (en)",
            "plant.plural_review (de)", "plant.plural_no_value (de)", "plant.plural_empty (de)",
        ])
    }

    @Test("A text copied from English is found")
    func copiedFromEnglish() throws {
        #expect(try Self.run().copiedFromEnglish == ["plant.copied (fr)"])
    }

    @Test("A text with other placeholders than the English one is found")
    func otherPlaceholders() throws {
        #expect(Set(try Self.run().otherPlaceholders).contains("plant.placeholders (it)"))
    }

    @Test("Placeholders are compared by argument position: a reversed mixed-type translation is found, a numbered reorder is not")
    func placeholdersByPosition() throws {
        let found = try Self.run().otherPlaceholders
        #expect(found.contains("plant.reversed (de)"), "\(found)")
        #expect(!found.contains { $0.hasPrefix("plant.reordered") }, "\(found)")
    }

    @Test("A plural form that omits the count passes while another form uses it; a position with two types in one language is found")
    func pluralPlaceholders() throws {
        let found = try Self.run().otherPlaceholders
        #expect(!found.contains { $0.hasPrefix("plant.plural_omitted_count") || $0.hasPrefix("plant.plural_count") }, "\(found)")
        #expect(found.contains("plant.plural_conflict (de)"), "\(found)")
    }

    @Test("Nothing else is reported for its placeholders")
    func onlyThePlantedPlaceholders() throws {
        #expect(Set(try Self.run().otherPlaceholders) == ["plant.placeholders (it)", "plant.reversed (de)", "plant.plural_conflict (de)"])
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

    // MARK: Literals handed to views

    private static func runOnLiterals(rules: StringRules = StringRules()) throws -> [String] {
        try StringChecks.run(
            catalog: planted.appendingPathComponent("Localizable.xcstrings"),
            sources: [planted.appendingPathComponent("PlantedLiterals.swift")],
            rules: rules
        ).lookedUpButMissing
    }

    private static func literals(_ found: [String]) -> [String] {
        found.map { String($0.split(separator: " (").first ?? "") }.sorted()
    }

    @Test("A key typed wrongly in a view, and English written in a view, are found; a key, a number, a symbol and verbatim text are not")
    func literalsOfViews() throws {
        let found = Self.literals(try Self.runOnLiterals())

        let expected: Set = ["\\(count) pages", "Double tap to save", "PDF", "Save your CV", "plant.heading", "plant.titel"]
        #expect(Set(found) == expected, "\(found)")
    }

    @Test("A literal that is deliberately not a key is exempt with its reason, and no other")
    func nonKeyLiteralsAreExempt() throws {
        var rules = StringRules()
        rules.nonKeyLiterals = ["PDF": "the name of the file format"]
        let found = Self.literals(try Self.runOnLiterals(rules: rules))

        #expect(!found.contains("PDF"))
        #expect(found.contains("plant.titel"))
    }

    @Test("The views of the design system and the arguments that take a key are read like the views of SwiftUI")
    func extraViewsAndArguments() throws {
        var rules = StringRules()
        rules.extraViews = ["ScreenTitle"]
        rules.extraArguments = ["title"]
        let found = Self.literals(try Self.runOnLiterals(rules: rules))

        #expect(found.contains("plant.screen_title"))
        #expect(found.contains("plant.box_title"))
        #expect(!found.contains("plant.complete"), "\(found)")
    }

    // MARK: Every literal of the views

    private static func runOnBypasses(rules: StringRules) throws -> [String] {
        literals(try StringChecks.run(
            catalog: planted.appendingPathComponent("Localizable.xcstrings"),
            sources: [planted.appendingPathComponent("PlantedBypasses.swift")],
            rules: rules
        ).lookedUpButMissing)
    }

    @Test("With every literal read, English reaches a view by a ternary, a local, a multiline or raw literal, or a member call, and is found")
    func everyLiteralIsRead() throws {
        var rules = StringRules()
        rules.everyLiteralInViews = true
        let found = try Self.runOnBypasses(rules: rules)

        #expect(Set(found) == [
            "Ready to send", "Try once more", "Name your resume", "Tell us about your last job", "Review your draft", "Raw words here",
        ], "\(found)")
    }

    @Test("A key, a lookup, a verbatim text, an identifier, a symbol name and a comment are not English in a view")
    func everyLiteralHasItsExemptions() throws {
        var rules = StringRules()
        rules.everyLiteralInViews = true
        rules.nonKeyLiterals = ["Review your draft": "a test reason"]
        let found = try Self.runOnBypasses(rules: rules)

        #expect(!found.contains("Review your draft"))
        for exempt in ["plant.complete", "Plain words here", "profile.save.button", "doc.text", "doc.richtext", "hero-banner", "Commented words", "Documented words", "Trailing words"] {
            #expect(!found.contains(exempt), "\(exempt): \(found)")
        }
    }

    @Test("Without the option only the literals handed straight to a view are read, in any form: raw and with a member call too")
    func legacyScanReadsWhatIsHandedToAView() throws {
        #expect(try Self.runOnBypasses(rules: StringRules()) == ["Raw words here", "Review your draft"])
    }
}
