import Testing
import Foundation
@testable import PrestoCVCore

// MARK: - Bundled Samples Tests

/// Reads the samples from the app bundle itself, which the package tests cannot reach.
@Suite("Bundled Samples Tests")
struct BundledSamplesTests {
    
    @Test("The app ships five distinct samples, each with a name and an experience")
    func appBundleShipsFiveSamples() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("bundled_samples_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try DependencyContainer(storageDirectory: { directory }).makeSampleCVRepository()
        
        let samples = try await repository.getAllSamples()
        
        #expect(samples.count == 5)
        #expect(Set(samples.map(\.name)).count == 5)
        for sample in samples {
            #expect(!sample.name.isEmpty)
            #expect(!sample.relevant_experience.isEmpty)
        }
    }
}
