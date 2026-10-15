import Testing
import Foundation
@testable import PrestoCV
@testable import PrestoCVCore

// MARK: - Localized Samples Tests

/// The sample CVs in the languages of the app: `technical_cv.json` is the English one, `technical_cv.de.json` the German one.
@Suite("Localized Samples Tests")
struct LocalizedSamplesTests {

    private static let names = ["technical_cv", "business_cv", "creative_cv", "academic_cv", "healthcare_cv"]
    private static let translatedLanguages = ["de", "es", "fr", "it", "pt"]

    /// What a translation must keep as it is: a link, an address, a number to dial and a level are not words.
    private static let untranslatedKeys: Set<String> = ["email", "phone", "portfolio", "url", "level", "year"]

    private static let resources = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("PrestoCV/Resources", isDirectory: true)

    private static func fileURL(_ name: String, language: String?) -> URL {
        resources.appendingPathComponent(language.map { "\(name).\($0).json" } ?? "\(name).json")
    }

    private static func json(_ name: String, language: String?) throws -> [String: Any] {
        let data = try Data(contentsOf: fileURL(name, language: language))
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    /// Where a translation has another structure than the English sample, and where it changed what is not words
    private static func differences(_ english: Any, _ other: Any, path: String = "") -> [String] {
        switch (english, other) {
        case let (english as [String: Any], other as [String: Any]):
            let missing = Set(english.keys).symmetricDifference(other.keys)
            guard missing.isEmpty else { return ["\(path): keys differ: \(missing.sorted())"] }
            return english.keys.sorted().flatMap { differences(english[$0]!, other[$0]!, path: "\(path)/\($0)") }
        case let (english as [Any], other as [Any]):
            guard english.count == other.count else { return ["\(path): \(english.count) items against \(other.count)"] }
            return zip(english, other).enumerated().flatMap { differences($1.0, $1.1, path: "\(path)/\($0)") }
        case let (english as String, other as String):
            let key = String(path.split(separator: "/").last ?? "")
            return untranslatedKeys.contains(key) && english != other ? ["\(path): \"\(english)\" became \"\(other)\""] : []
        case let (english as NSNumber, other as NSNumber):
            return english == other ? [] : ["\(path): \(english) became \(other)"]
        default:
            return ["\(path): another kind of value"]
        }
    }

    @Test("Every sample has a version in every language")
    func everySampleExistsInEveryLanguage() {
        for name in Self.names {
            for language in Self.translatedLanguages {
                let file = Self.fileURL(name, language: language)
                #expect(FileManager.default.fileExists(atPath: file.path), "\(file.lastPathComponent) is missing")
            }
        }
    }

    @Test("A translation has the structure of the English sample, with the same numbers, links and levels")
    func translationsHaveTheShapeOfTheEnglishSample() throws {
        for name in Self.names {
            let english = try Self.json(name, language: nil)
            for language in Self.translatedLanguages {
                let translation = try Self.json(name, language: language)

                let differences = Self.differences(english, translation)

                #expect(differences.isEmpty, "\(name).\(language).json: \(differences)")
            }
        }
    }

    @Test("A translation is written in its language: the summary and every description differ from the English ones")
    func translationsAreNotCopiesOfTheEnglishText() throws {
        for name in Self.names {
            let english = try Self.json(name, language: nil)
            for language in Self.translatedLanguages {
                let translation = try Self.json(name, language: language)
                let prose = { (sample: [String: Any]) -> [String] in
                    var texts: [String] = []
                    texts.append((sample["personalInfo"] as? [String: Any])?["profile"] as? String ?? "")
                    for section in ["relevant_experience", "education", "certifications"] {
                        texts += (sample[section] as? [[String: Any]] ?? []).compactMap { $0["description"] as? String }
                    }
                    return texts
                }

                for (original, translated) in zip(prose(english), prose(translation)) {
                    #expect(!original.isEmpty && original != translated, "\(name).\(language).json keeps English text: \(original.prefix(50))")
                }
            }
        }
    }

    @Test("A translation holds no other e-mail address or link than the placeholders of the English sample")
    func translationsHoldOnlyPlaceholderLinks() throws {
        for name in Self.names {
            for language in Self.translatedLanguages {
                let sample = try Self.json(name, language: language)
                let personal = try #require(sample["personalInfo"] as? [String: Any])
                let social = (sample["social"] as? [[String: Any]] ?? []).compactMap { $0["url"] as? String }

                #expect((personal["email"] as? String ?? "").hasSuffix("@example.com"))
                for link in [personal["portfolio"] as? String ?? ""] + social where !link.isEmpty {
                    #expect(URL(string: link)?.host == "example.com", "\(name).\(language).json: \(link)")
                }
            }
        }
    }

    // MARK: - From the app bundle

    private func loadSamples(languages: [String]) async throws -> [CVModel] {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("localized_samples_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = SampleCVRepository(
            storageService: try FileStorageService(baseDirectory: directory),
            categoryService: TemplateCategoryService(),
            bundleResourceService: BundleResourceService(),
            templateLoader: JSONTemplateLoader(),
            parallelSearchService: ParallelSearchService(),
            languages: languages
        )
        return try await repository.getAllSamples()
    }

    private func titles(language: String?) throws -> [String] {
        try Self.names.map { try #require((Self.json($0, language: language)["personalInfo"] as? [String: Any])?["title"] as? String) }
    }

    @Test("The app bundle offers the five samples in each language of the app")
    func bundleOffersEachLanguage() async throws {
        for language in Self.translatedLanguages {
            let samples = try await loadSamples(languages: [language])

            #expect(samples.map(\.personalInfo.title) == (try titles(language: language)), "\(language)")
        }
    }

    @Test("The app bundle offers the English samples in a language it has no translation for")
    func bundleFallsBackToEnglish() async throws {
        let samples = try await loadSamples(languages: ["ja"])

        #expect(samples.map(\.personalInfo.title) == (try titles(language: nil)))
    }
}
