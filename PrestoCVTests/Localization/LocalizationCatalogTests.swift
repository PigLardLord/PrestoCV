import Testing
import Foundation
@testable import PrestoCV
@testable import PrestoCVCore

// MARK: - Localization Catalog Tests

/// What of the localisation needs the app's own types. The checks of the catalog's source and of the code that looks
/// it up read the repository, so they are in Tools/SourceChecks, which runs where the repository is.
@Suite("Localization catalog")
struct LocalizationCatalogTests {

    static let languages = ["de", "en", "es", "fr", "it", "pt"]

    /// The text of a key in a language, from the catalog as the app bundle carries it: compiled into each language's
    /// table. Nil when that language's table does not have the key.
    private static func compiledText(of key: String, in language: String) throws -> String? {
        let app = Bundle(for: AppRouter.self)
        let folder = try #require(app.path(forResource: language, ofType: "lproj"), "The app bundle has no \(language).lproj")
        let table = try #require(Bundle(path: folder))
        let missing = "\u{0}missing"
        let text = table.localizedString(forKey: key, value: missing, table: nil)
        return text == missing ? nil : text
    }

    @Test("The levels of a language have a text in each language")
    func languageLevelsAreInTheCatalog() throws {
        for level in LanguageProficiencyLevel.allCases {
            for language in Self.languages {
                #expect(try Self.compiledText(of: level.localizationKey, in: language) != nil, "\(level.localizationKey) has no \(language) text")
            }
        }
    }

    @Test("A failure to start the app is described in words, with the reason")
    func dependencyErrorIsDescribed() {
        let reason = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "no space left"])

        let description = DependencyError.serviceCreationFailed("StorageService", reason).errorDescription

        #expect(description?.contains("no space left") == true)
        #expect(description?.contains("error.dependency_failed") == false)
        #expect(description?.contains("StorageService") == false)
    }

    @Test("A sample that cannot be read is reported without English of its own")
    func unreadableSampleIsReportedWithoutEnglish() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("l10n_sample_\(UUID().uuidString).json")
        try Data("not json".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }

        do {
            _ = try await JSONTemplateLoader().loadTemplate(from: file)
            Issue.record("A file that is not JSON should not load")
        } catch AppError.decodingError(let message) {
            #expect(message.hasPrefix(file.lastPathComponent))
            #expect(message.contains("Failed to decode") == false)
        }
    }
}
