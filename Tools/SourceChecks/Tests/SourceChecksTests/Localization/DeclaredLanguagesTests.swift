import Foundation
import Testing

// MARK: - Declared Languages Tests

/// The project declares the six languages the new app is written in (migration step 5-15b, #408).
///
/// The Xcode 27 project format writes the project's languages as a development language and a list of supported ones:
/// the old `knownRegions = (en, Base)` became `"development": "en"` and `"supported": ["Base"]`, so the development
/// language is not repeated in the list, and `Base` is the base internationalisation, not a language. The built app
/// takes its `.lproj` folders from the catalog; the declaration is what Xcode lists as the project's languages, for the
/// catalog editor and the localisation export. Both app targets share it.
@Suite("Declared Languages Tests")
struct DeclaredLanguagesTests {

    private static let projectFile = "PrestoCV.xcodeproj/project.xcproj"
    private static let catalogFile = CatalogUnderCheck.next.catalog

    /// The part of the project file that holds its languages.
    private struct Project: Decodable {
        struct Localizations: Decodable {
            let development: String
            let supported: [String]
        }
        let localizations: Localizations
    }

    /// The project file read as JSON5, which allows its trailing commas, so the languages are read by structure and not
    /// by matching lines.
    private static func localizations() throws -> Project.Localizations {
        let data = try Data(contentsOf: Repository.root.appendingPathComponent(projectFile))
        let decoder = JSONDecoder()
        decoder.allowsJSON5 = true
        return try decoder.decode(Project.self, from: data).localizations
    }

    /// The languages the project declares: its development language and the supported ones, without `Base`.
    private static func declaredLanguages() throws -> Set<String> {
        let localizations = try localizations()
        return Set([localizations.development] + localizations.supported).subtracting(["Base"])
    }

    @Test("English is the development language of the project")
    func englishIsTheDevelopmentLanguage() throws {
        #expect(try Self.localizations().development == "en")
    }

    @Test("The project declares the six languages of the new app")
    func projectDeclaresTheSixLanguages() throws {
        let declared = try Self.declaredLanguages()

        #expect(declared == Set(LocalizationCatalog.languages), "\(Self.projectFile) declares \(declared.sorted())")
    }

    @Test("The new app's catalog is written in the languages the project declares, no more and no fewer")
    func catalogIsWrittenInTheDeclaredLanguages() throws {
        let catalog = try LocalizationCatalog(contentsOf: Repository.root.appendingPathComponent(Self.catalogFile))
        var written = Set<String>()
        for entry in catalog.strings.values {
            if let localizations = entry["localizations"] as? [String: Any] { written.formUnion(localizations.keys) }
        }

        #expect(!written.isEmpty, "\(Self.catalogFile) has no text in any language")
        #expect(written == (try Self.declaredLanguages()), "\(Self.catalogFile) is written in \(written.sorted())")
    }
}
