import Foundation
@testable import PrestoCV
@testable import PrestoCVCore

/// The five sample CVs the app ships, read from the app bundle in a language, as the new-CV choices offer them
enum BundledSamples {

    /// A sample with a label that names it and its language
    struct Sample {
        let label: String
        let cv: CVModel
    }

    /// The languages the samples exist in: English is the file with no language in its name
    static let languages = ["en", "it", "de", "es", "fr", "pt"]

    private static let names = ["technical", "business", "creative", "academic", "healthcare"]

    static func load(language: String) async throws -> [Sample] {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("bundled_samples_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = SampleCVRepository(
            storageService: try FileStorageService(baseDirectory: directory),
            categoryService: TemplateCategoryService(),
            bundleResourceService: BundleResourceService(bundle: Bundle(for: AppRouter.self)),
            templateLoader: JSONTemplateLoader(),
            parallelSearchService: ParallelSearchService(),
            languages: language == "en" ? [] : [language]
        )
        let samples = try await repository.getAllSamples()
        return zip(names, samples).map { Sample(label: "sample-\($0)-\(language)", cv: $1) }
    }
}
