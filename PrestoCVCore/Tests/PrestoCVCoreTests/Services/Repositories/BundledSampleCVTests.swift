import Testing
import Foundation
@testable import PrestoCVCore

@Suite("Bundled Sample CV Tests")
struct BundledSampleCVTests {
    
    private static let sampleNames = ["technical_cv", "business_cv", "creative_cv", "academic_cv", "healthcare_cv"]
    
    /// A directory standing in for the app bundle: the samples, and the other JSON files the bundle also holds
    private func makeBundleDirectory(samples: [String] = sampleNames) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("test_bundle_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for name in samples {
            try Data(#"{"name": "\#(name) sample"}"#.utf8).write(to: directory.appendingPathComponent("\(name).json"))
        }
        for decoy in ["academic.cv", "technical.cv", "default", "Contents"] {
            try Data(#"{"name": "\#(decoy) decoy"}"#.utf8).write(to: directory.appendingPathComponent("\(decoy).json"))
        }
        return directory
    }
    
    private func makeRepository(bundleDirectory: URL, languages: [String] = []) -> SampleCVRepository {
        SampleCVRepository(
            storageService: MockStorageService(),
            categoryService: TemplateCategoryService(),
            bundleResourceService: DirectoryBundleResourceService(directory: bundleDirectory),
            templateLoader: JSONTemplateLoader(),
            parallelSearchService: ParallelSearchService(),
            languages: languages
        )
    }
    
    /// Adds the German and Italian versions of two samples to a bundle directory
    private func addTranslations(to directory: URL) throws {
        for (name, language) in [("technical_cv", "de"), ("academic_cv", "de"), ("technical_cv", "it")] {
            try Data(#"{"name": "\#(name) \#(language)"}"#.utf8).write(to: directory.appendingPathComponent("\(name).\(language).json"))
        }
    }
    
    @Test("GetAllSamples returns the five samples in a fixed order")
    func getAllSamplesReturnsTheListedSamples() async throws {
        let directory = try makeBundleDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        
        let samples = try await makeRepository(bundleDirectory: directory).getAllSamples()
        
        #expect(samples.map(\.name) == Self.sampleNames.map { "\($0) sample" })
    }
    
    @Test("GetAllSamples skips a sample that is not in the bundle")
    func getAllSamplesSkipsMissingSamples() async throws {
        let present = ["technical_cv", "academic_cv"]
        let directory = try makeBundleDirectory(samples: present)
        defer { try? FileManager.default.removeItem(at: directory) }
        
        let samples = try await makeRepository(bundleDirectory: directory).getAllSamples()
        
        #expect(samples.map(\.name) == ["technical_cv sample", "academic_cv sample"])
    }
    
    @Test("GetSample finds a listed sample by its file name")
    func getSampleFindsListedSampleByName() async throws {
        let directory = try makeBundleDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        
        let sample = try await makeRepository(bundleDirectory: directory).getSample(by: "healthcare_cv")
        
        #expect(sample?.name == "healthcare_cv sample")
    }
    
    @Test("GetSample does not find a JSON file that is not a listed sample")
    func getSampleIgnoresOtherJSONFiles() async throws {
        let directory = try makeBundleDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = makeRepository(bundleDirectory: directory)
        
        #expect(try await repository.getSample(by: "academic.cv") == nil)
        #expect(try await repository.getSample(by: "Contents") == nil)
    }
    
    @Test("GetSample finds the listed sample of a category, not a file that only looks like it")
    func getSampleByCategoryUsesListedSamples() async throws {
        let directory = try makeBundleDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = makeRepository(bundleDirectory: directory)
        
        #expect(try await repository.getSample(by: "academic")?.name == "academic_cv sample")
        #expect(try await repository.getSample(by: "technical")?.name == "technical_cv sample")
    }
    
    @Test("GetAllSamples reads each sample in the language of the app, and in English where it has no version in it")
    func getAllSamplesUsesTheLanguageOfTheApp() async throws {
        let directory = try makeBundleDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try addTranslations(to: directory)
        
        let samples = try await makeRepository(bundleDirectory: directory, languages: ["de"]).getAllSamples()
        
        #expect(samples.map(\.name) == ["technical_cv de", "business_cv sample", "creative_cv sample", "academic_cv de", "healthcare_cv sample"])
    }
    
    @Test("GetAllSamples reads the samples in English when the language has no translations")
    func getAllSamplesFallsBackToEnglish() async throws {
        let directory = try makeBundleDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try addTranslations(to: directory)
        
        let samples = try await makeRepository(bundleDirectory: directory, languages: ["ja"]).getAllSamples()
        
        #expect(samples.map(\.name) == Self.sampleNames.map { "\($0) sample" })
    }
    
    @Test("GetAllSamples tries the languages in the order they are given")
    func getAllSamplesTriesLanguagesInOrder() async throws {
        let directory = try makeBundleDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try addTranslations(to: directory)
        
        let samples = try await makeRepository(bundleDirectory: directory, languages: ["fr", "it", "de"]).getAllSamples()
        
        #expect(samples.first?.name == "technical_cv it")
        #expect(samples.last?.name == "healthcare_cv sample")
    }
    
    @Test("GetSample finds a sample in the language of the app")
    func getSampleUsesTheLanguageOfTheApp() async throws {
        let directory = try makeBundleDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try addTranslations(to: directory)
        let repository = makeRepository(bundleDirectory: directory, languages: ["de"])
        
        #expect(try await repository.getSample(by: "academic_cv")?.name == "academic_cv de")
        #expect(try await repository.getSample(by: "healthcare_cv")?.name == "healthcare_cv sample")
    }
}
