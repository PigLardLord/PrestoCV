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
    
    private func makeRepository(bundleDirectory: URL) -> SampleCVRepository {
        SampleCVRepository(
            storageService: MockStorageService(),
            categoryService: TemplateCategoryService(),
            bundleResourceService: DirectoryBundleResourceService(directory: bundleDirectory),
            templateLoader: JSONTemplateLoader(),
            parallelSearchService: ParallelSearchService()
        )
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
}
