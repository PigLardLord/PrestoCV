import Testing
import Foundation
@testable import PrestoCV
@testable import PrestoCVCore

// MARK: - Bundled Samples Tests

/// Reads the samples from the app bundle itself, which the package tests cannot reach.
@Suite("Bundled Samples Tests")
struct BundledSamplesTests {
    
    private func loadBundledSamples() async throws -> [CVModel] {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("bundled_samples_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try DependencyContainer(storageDirectory: { directory }).makeSampleCVRepository()
        return try await repository.getAllSamples()
    }
    
    @Test("The app ships five distinct samples, each with a name and an experience")
    func appBundleShipsFiveSamples() async throws {
        let samples = try await loadBundledSamples()
        
        #expect(samples.count == 5)
        #expect(Set(samples.map(\.name)).count == 5)
        for sample in samples {
            #expect(!sample.name.isEmpty)
            #expect(!sample.relevant_experience.isEmpty)
        }
    }
    
    @Test("A sample holds no real person's links: every link and e-mail address is a placeholder")
    func samplesHoldOnlyPlaceholderLinks() async throws {
        let samples = try await loadBundledSamples()
        
        for sample in samples {
            let links = [sample.personalInfo.portfolio] + sample.social.map(\.url)
            for link in links where !link.isEmpty {
                #expect(URL(string: link)?.host == "example.com", "\(sample.personalInfo.title): \(link) is not an example.com placeholder")
            }
            #expect(sample.personalInfo.email.hasSuffix("@example.com"), "\(sample.personalInfo.title): \(sample.personalInfo.email)")
        }
    }
    
    @Test("A draft from each bundled sample carries none of its personal details and has its own id")
    @MainActor
    func draftsFromBundledSamplesAreAnonymous() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("bundled_samples_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try DependencyContainer(storageDirectory: { directory }).makeSampleCVRepository()
        let viewModel = NewCVChoicesViewModel(aiAvailability: { .available }, sampleRepository: repository)
        
        await viewModel.loadSamples()
        let samples = viewModel.samples
        let drafts = samples.map(viewModel.makeDraft(from:))
        
        #expect(samples.count == 5)
        #expect(Set(drafts.map(\.id)).count == 5)
        #expect(Set(drafts.map(\.id)).isDisjoint(with: samples.map(\.id)))
        for draft in drafts {
            #expect(draft.name.isEmpty)
            #expect(draft.personalInfo.name.isEmpty)
            #expect(draft.personalInfo.email.isEmpty)
            #expect(draft.personalInfo.phone.isEmpty)
            #expect(draft.personalInfo.location.isEmpty)
            #expect(draft.personalInfo.portfolio.isEmpty)
            #expect(draft.social.allSatisfy { $0.url.isEmpty })
            #expect(!draft.personalInfo.title.isEmpty, "The profession stays, it is what the example is about")
            #expect(!draft.relevant_experience.isEmpty)
        }
    }
}
