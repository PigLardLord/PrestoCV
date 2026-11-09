import Foundation
import Testing

/// A string catalog and the sources that look its keys up: what the checks that every catalog must pass run on.
struct CatalogUnderCheck: Sendable, CustomTestStringConvertible {
    let name: String
    /// Relative to the repository root.
    let catalog: String
    /// Relative to the repository root; the Swift files that git tracks under them.
    let folders: [String]
    let rules: StringRules

    var testDescription: String { name }

    /// The legacy app, which ships until the switch of migration step 5-17 (dropped by 5-17d).
    static let legacy = CatalogUnderCheck(
        name: "the legacy catalog", catalog: LocalizationCatalogTests.catalogPath,
        folders: LocalizationCatalogTests.shippedFolders, rules: LocalizationCatalogTests.legacyRules)

    /// The new app. No source of `PrestoCVApp/Sources` (presentation, composition, integration) names a catalog key
    /// (checked for step 5-15a: none looks up a text, and R13 leaves the text to the views).
    static let next = CatalogUnderCheck(
        name: "the catalog of the new app", catalog: "PrestoCVNext/Resources/Localizable.xcstrings",
        folders: ["PrestoCVNext"], rules: StringRules(
            // A format that carries only the order of its values and the punctuation, which a translation may still change.
            sameInEveryLanguage: ["shell.numbered %@ %lld"],
            valueTypes: [
                #"shell.numbered \(title) \(number)"#: ValueTypes(["%@", "%lld"], "makeCVList's numbered takes a String and an Int"),
                #"failed.code \(failure.rawValue)"#: ValueTypes(["%@"], "CompositionFailure's raw value is a String"),
                #"list.row.saved \(saved)"#: ValueTypes(["%@"], "RelativeDateTimeFormatter gives a String"),
                #"list.delete.title \(row.label)"#: ValueTypes(["%@"], "CVRow's label is a String"),
                #"list.copy.title \(row.label)"#: ValueTypes(["%@"], "CVRow's label is a String"),
                #"list.notice \(notice.count)"#: ValueTypes(["%lld"], "StoreNotice's count is an Int"),
            ],
            // The design system's views take a key; the screens hand one to ErrorStateView as title:, message:, code: and retryTitle:.
            extraViews: ["PrimaryButton", "ScreenTitle", "LoadingView", "WholeWordsText"],
            extraArguments: ["title", "message", "code", "retryTitle"],
            // Deny by default: English written anywhere in a view (a ternary, a local, a multiline literal) is not translated.
            everyLiteralInViews: true))

    static let all = [legacy, next]

    func findings() throws -> StringFindings {
        try StringChecks.run(
            catalog: Repository.root.appendingPathComponent(catalog),
            sources: SwiftSource.trackedFiles(in: folders), rules: rules)
    }
}

@Suite("String catalogs - the checks every catalog passes")
struct StringCatalogTests {
    @Test("Every key that the code looks up is in the catalog", arguments: CatalogUnderCheck.all)
    func everyLookedUpKeyIsInTheCatalog(_ pair: CatalogUnderCheck) throws {
        let missing = try pair.findings().lookedUpButMissing

        #expect(missing.isEmpty, "Keys that are looked up but missing from the catalog: \(missing)")
    }

    @Test("Every key has a text in each language, marked as translated", arguments: CatalogUnderCheck.all)
    func everyKeyHasATextInEveryLanguage(_ pair: CatalogUnderCheck) throws {
        let findings = try pair.findings()

        #expect(findings.missingLanguage.isEmpty, "Keys without a text in a language: \(findings.missingLanguage)")
        #expect(findings.notTranslated.isEmpty, "Texts empty or not marked translated: \(findings.notTranslated)")
    }

    @Test("No text is copied from English, except those that read the same", arguments: CatalogUnderCheck.all)
    func noTextIsCopiedFromEnglish(_ pair: CatalogUnderCheck) throws {
        let copied = try pair.findings().copiedFromEnglish

        #expect(copied.isEmpty, "Keys with a text copied from English: \(copied)")
    }

    @Test("Each text keeps the placeholders of the English text", arguments: CatalogUnderCheck.all)
    func textsKeepThePlaceholders(_ pair: CatalogUnderCheck) throws {
        let mismatched = try pair.findings().otherPlaceholders

        #expect(mismatched.isEmpty, "Keys whose placeholders differ from English: \(mismatched)")
    }

    @Test("Spanish, French, Italian and Portuguese texts are written in sentence case, not in English title case", arguments: CatalogUnderCheck.all)
    func noEnglishTitleCase(_ pair: CatalogUnderCheck) throws {
        let titleCase = try pair.findings().titleCase

        #expect(titleCase.isEmpty, "Texts with capitals of an English title: \(titleCase)")
    }

    @Test("The texts promise no future availability or readiness, in any language", arguments: CatalogUnderCheck.all)
    func textsPromiseNoAvailability(_ pair: CatalogUnderCheck) throws {
        let promises = try pair.findings().availabilityPromises

        #expect(promises.isEmpty, "Texts that promise future availability or readiness: \(promises)")
    }

    @Test("Every key of the catalog is used by the code", arguments: CatalogUnderCheck.all)
    func noKeyIsUnused(_ pair: CatalogUnderCheck) throws {
        let unused = try pair.findings().unused

        #expect(unused.isEmpty, "Keys that no code uses: \(unused)")
    }

    @Test("No exemption outlives its defect", arguments: CatalogUnderCheck.all)
    func exemptionsAreStillNeeded(_ pair: CatalogUnderCheck) throws {
        let stale = try StringChecks.staleExemptions(
            catalog: Repository.root.appendingPathComponent(pair.catalog),
            sources: SwiftSource.trackedFiles(in: pair.folders), rules: pair.rules)

        #expect(stale.isEmpty, "Exemptions to remove: \(stale)")
    }

    @Test("Each catalog has keys, and each folder of sources has files, so that no check passes by reading nothing", arguments: CatalogUnderCheck.all)
    func theChecksReadSomething(_ pair: CatalogUnderCheck) throws {
        let catalog = try LocalizationCatalog(contentsOf: Repository.root.appendingPathComponent(pair.catalog))
        let files = try SwiftSource.trackedFiles(in: pair.folders)

        #expect(!catalog.keys.isEmpty)
        for folder in pair.folders {
            #expect(files.contains { $0.path.contains("/\(folder)/") }, "No Swift file under \(folder)")
        }
    }
}
