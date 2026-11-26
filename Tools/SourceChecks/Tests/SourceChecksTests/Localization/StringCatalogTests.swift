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
            // German writes "Website" and "Link" as English does, Italian and Portuguese "Link", and French "Description" and
            // "Certification". German also names the website a CV of the released app lost "Website".
            // Spanish, French and Italian say "CV" as English does; French counts pages with the English word. German names
            // the designs "Minimal" and "Modern" and the fonts "System" as English does. An alert's "OK" reads the same in all
            // but Spanish. German, French and Italian say "Build", German and French "Version", German "Support", French
            // "Licences", and French and Italian "Open source".
            sameInSomeLanguages: [
                "editor.field.website": ["de"], "editor.field.link": ["de", "it", "pt"], "editor.field.description": ["fr"],
                "editor.field.certification": ["fr"], "editor.section.certifications": ["fr"],
                "export.file_name": ["es", "fr", "it"], "export.pages %lld": ["fr"],
                "editor.entry.title.certification": ["fr"], "import.review.field.certification %lld": ["fr"],
                "design.minimal": ["de"], "design.modern": ["de"], "fonts.system": ["de"],
                "import.error.ok": ["de", "fr", "it", "pt"],
                "legacyImport.detail.website": ["de"],
                "settings.about.build": ["de", "fr", "it"], "settings.about.version": ["de", "fr"],
                "settings.support.header": ["de"], "settings.licences.title": ["fr"], "settings.openSource.licences": ["fr"],
                "settings.openSource.header": ["fr", "it"],
            ],
            // The look picker names a design, fonts or a palette by the code the launch offers (LookName); the
            // composition's LookNamesTests checks that those codes and these keys are the same set.
            dynamicKeyPrefixes: ["design.", "fonts.", "palette."],
            // The hint of "Choose a PDF" names the system's Files app, whose name keeps its capital; the name of
            // the app's licence and the name of the store are ones no translation changes.
            properNamesOfKey: [
                "import.pdf.button.hint": ["Archivos", "Fichiers", "File", "Arquivos"],
                "settings.openSource.statement": ["Apache"],
                "settings.tips.loading": ["App", "Store"],
                "settings.tips.unreachable": ["App", "Store"],
            ],
            nonKeyLiterals: [
                "native": "the code of a language level, which ProficiencyPicker words (R13)",
                "designsOwn": "the end of the accessibility identifier of the look picker's item for the design's own (LookName)",
                "kept": "the end of the accessibility identifier of the look picker's item for a kept choice (LookName)",
            ],
            valueTypes: [
                #"shell.numbered \(title) \(number)"#: ValueTypes(["%@", "%lld"], "makeCVList's numbered takes a String and an Int"),
                #"failed.code \(failure.rawValue)"#: ValueTypes(["%@"], "CompositionFailure's raw value is a String"),
                #"list.row.saved \(saved)"#: ValueTypes(["%@"], "RelativeDateTimeFormatter gives a String"),
                #"editor.entry.since \(since)"#: ValueTypes(["%@"], "EntryYears' first year is a String"),
                #"list.delete.title \(row.label)"#: ValueTypes(["%@"], "CVRow's label is a String"),
                #"list.copy.title \(row.label)"#: ValueTypes(["%@"], "CVRow's label is a String"),
                #"list.copy.title \(title)"#: ValueTypes(["%@"], "makeShell's copyTitle takes a String"),
                #"list.rowFailure.hide \(failure.label)"#: ValueTypes(["%@"], "RowFailure's label is a String"),
                #"list.notice \(notice.count)"#: ValueTypes(["%lld"], "StoreNotice's count is an Int"),
                #"export.pages \(pages)"#: ValueTypes(["%lld"], "ExportedDocument's pages is an Int"),
                #"export.preview.open \(pages)"#: ValueTypes(["%lld"], "ExportedDocument's pages is an Int"),
                #"export.updated \(pages)"#: ValueTypes(["%lld"], "RemadePDF's pages is an Int"),
                #"export.headings \(name)"#: ValueTypes(["%@"], "LanguageName gives the language's name as a String"),
                #"export.error.too_many_pages \(required) \(pages)"#: ValueTypes(["%lld", "%lld"], "ExportStatus.truncated holds two Ints"),
                #"export.status.incomplete \(missing)"#: ValueTypes(["%lld"], "ExportStatus.incomplete holds an Int"),
                #"export.status.text_not_visible \(lines)"#: ValueTypes(["%lld"], "ExportStatus.textNotVisible holds an Int"),
                #"list.kept.open.label \(notice.label)"#: ValueTypes(["%@"], "KeptNotice's label is a String"),
                #"list.kept.retry.label \(notice.label)"#: ValueTypes(["%@"], "KeptNotice's label is a String"),
                #"editor.notice.textTooLong.named \(name)"#: ValueTypes(["%@"], "StatusNotice resolves the field's label to a String"),
                #"editor.row.delete.named \(name)"#: ValueTypes(["%@"], "EditorRowView's name is a String"),
                #"editor.row.delete.title \(name)"#: ValueTypes(["%@"], "EditorRowView's name is a String"),
                #"editor.row.delete.title \(removalName)"#: ValueTypes(["%@"], "EntryPage's removalName is a String"),
                #"editor.row.moveUp.named \(name)"#: ValueTypes(["%@"], "EditorRowView's name is a String"),
                #"editor.row.moveDown.named \(name)"#: ValueTypes(["%@"], "EditorRowView's name is a String"),
                #"settings.about.header \(settings.appName)"#: ValueTypes(["%@"], "SettingsViewModel's appName is a String"),
                #"settings.support.footer \(settings.supportAddress)"#: ValueTypes(
                    ["%@"], "SettingsViewModel's supportAddress is a String"),
                #"editor.level \(level) \(EditorChoices.skillLevels.count)"#: ValueTypes(
                    ["%lld", "%lld"], "a skill level and the number of levels are Ints"),
                #"import.review.field.experience \(entry)"#: ValueTypes(["%lld"], "ReviewedField's entry is an Int"),
                #"import.review.field.experiencePeriod \(entry)"#: ValueTypes(["%lld"], "ReviewedField's entry is an Int"),
                #"import.review.field.education \(entry)"#: ValueTypes(["%lld"], "ReviewedField's entry is an Int"),
                #"import.review.field.educationPeriod \(entry)"#: ValueTypes(["%lld"], "ReviewedField's entry is an Int"),
                #"import.review.field.educationLocation \(entry)"#: ValueTypes(["%lld"], "ReviewedField's entry is an Int"),
                #"import.review.field.language \(entry)"#: ValueTypes(["%lld"], "ReviewedField's entry is an Int"),
                #"import.review.field.languageNotKept \(entry)"#: ValueTypes(["%lld"], "ReviewedField's entry is an Int"),
                #"import.review.field.certificationYear \(entry)"#: ValueTypes(["%lld"], "ReviewedField's entry is an Int"),
                #"import.review.field.certification \(entry)"#: ValueTypes(["%lld"], "ReviewedField's entry is an Int"),
                #"legacyImport.summary \(report.leftOut.count)"#: ValueTypes(["%lld"], "an array's count is an Int"),
                #"legacyImport.row.label \(name) \(details)"#: ValueTypes(
                    ["%@", "%@"], "a row's label and its details as a list are Strings"),
                #"legacyImport.row.toCheck \(name) \(details)"#: ValueTypes(
                    ["%@", "%@"], "a row's label and its details as a list are Strings"),
                #"legacyImport.result.kept \(count)"#: ValueTypes(["%lld"], "LegacyReportState.keptSome holds an Int"),
                #"legacyImport.failed.count \(report.notImportedTotal)"#: ValueTypes(["%lld"], "notImportedTotal is an Int"),
                #"legacyImport.failed.damaged \(line.count)"#: ValueTypes(["%lld"], "NotImportedCount's count is an Int"),
                #"legacyImport.failed.notSaved \(line.count)"#: ValueTypes(["%lld"], "NotImportedCount's count is an Int"),
            ],
            // The design system's views take a key, as does the bar's BarButtonLabel; the screens hand one to
            // ErrorStateView as title:, message:, code: and retryTitle:.
            extraViews: ["PrimaryButton", "ScreenTitle", "LoadingView", "WholeWordsText", "BarButtonLabel"],
            extraArguments: ["title", "message", "code", "retryTitle"],
            // Deny by default: English written anywhere in a view (a ternary, a local, a multiline literal) is not translated.
            everyLiteralInViews: true,
            // French typography: the texts of the new app write a space that cannot break before : ; ? ! and inside « ».
            frenchNoBreakSpaces: true))

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

    @Test("French texts have a space that cannot break before : ; ? ! » and after «, where the catalog asks for it", arguments: CatalogUnderCheck.all)
    func frenchSpacesCannotBreak(_ pair: CatalogUnderCheck) throws {
        let breaking = try pair.findings().breakingSpacesInFrench

        #expect(breaking.isEmpty, "French texts with a space that can break before a mark (write U+00A0): \(breaking)")
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
