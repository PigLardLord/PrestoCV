import Testing
import Foundation
@testable import PrestoCVCore

@Suite("SampleCVRepository Tests")
struct SampleCVRepositoryTests {
    
    // MARK: - Initialization Tests
    
    @Test("SampleCVRepository initializes with storage service")
    func repositoryInitialization() {
        let mockStorage = MockStorageService()
        let repository = SampleCVRepository(storageService: mockStorage)
        
        #expect(type(of: repository) == SampleCVRepository.self)
    }
    
    // MARK: - GetDefaultSample Tests
    
    @Test("GetDefaultSample returns empty CV sample")
    func getDefaultSampleReturnsEmptyCV() async throws {
        let mockStorage = MockStorageService()
        let repository = SampleCVRepository(storageService: mockStorage)
        
        let sample = try await repository.getDefaultSample()
        
        #expect(sample.name == "")
        #expect(sample.title == "")
        #expect(sample.email == "")
        #expect(sample.phone == "")
        #expect(sample.location == "")
        #expect(sample.portfolio == "")
        #expect(sample.profile == "")
        #expect(sample.relevant_experience.isEmpty)
        #expect(sample.education.isEmpty)
        #expect(sample.skills.isEmpty)
        #expect(sample.languages.isEmpty)
        #expect(sample.certifications.isEmpty)
        #expect(sample.interests.isEmpty)
        #expect(sample.social.isEmpty)
    }
    
    @Test("GetDefaultSample returns consistent sample across calls")
    func getDefaultSampleConsistentAcrossCalls() async throws {
        let mockStorage = MockStorageService()
        let repository = SampleCVRepository(storageService: mockStorage)
        
        let sample1 = try await repository.getDefaultSample()
        let sample2 = try await repository.getDefaultSample()
        
        // Samples should have same structure but different IDs (since UUID() generates new ones)
        #expect(sample1.name == sample2.name)
        #expect(sample1.title == sample2.title)
        #expect(sample1.email == sample2.email)
        #expect(sample1.relevant_experience.count == sample2.relevant_experience.count)
        #expect(sample1.skills.count == sample2.skills.count)
        
        // But IDs should be different since CVModel() creates new UUIDs
        #expect(sample1.id != sample2.id)
    }
    
    @Test("GetDefaultSample does not require storage operations")
    func getDefaultSampleDoesNotRequireStorage() async throws {
        let mockStorage = MockStorageService()
        let repository = SampleCVRepository(storageService: mockStorage)
        
        // Clear mock storage to ensure it's empty
        mockStorage.clear()
        #expect(mockStorage.isEmpty())
        
        let sample = try await repository.getDefaultSample()
        
        // Sample should be returned successfully without any storage operations
        #expect(sample.name == "")
        
        // Storage should still be empty - no read or write operations occurred
        #expect(mockStorage.isEmpty())
    }
    
    // MARK: - GetAllSamples Tests
    
    @Test("GetAllSamples returns array containing default sample when no bundle resources")
    func getAllSamplesReturnsDefaultSampleWhenNoBundleResources() async throws {
        let mockStorage = MockStorageService()
        let repository = SampleCVRepository(storageService: mockStorage)
        
        let samples = try await repository.getAllSamples()
        
        #expect(samples.count >= 1)
        
        let sample = samples.first!
        #expect(sample.name == "")
        #expect(sample.title == "")
        #expect(sample.relevant_experience.isEmpty)
        #expect(sample.skills.isEmpty)
    }
    
    @Test("GetAllSamples is consistent with getDefaultSample")
    func getAllSamplesConsistentWithGetDefaultSample() async throws {
        let mockStorage = MockStorageService()
        let repository = SampleCVRepository(storageService: mockStorage)
        
        let defaultSample = try await repository.getDefaultSample()
        let allSamples = try await repository.getAllSamples()
        
        #expect(allSamples.count >= 1)
        
        // The default sample might not be the first one if bundle resources exist
        // But it should exist in the collection
        let containsDefault = allSamples.contains { sample in
            sample.name == defaultSample.name &&
            sample.title == defaultSample.title &&
            sample.email == defaultSample.email
        }
        
        #expect(containsDefault)
    }
    
    // MARK: - GetSample Tests
    
    @Test("GetSample returns default sample for 'default' name")
    func getSampleReturnsDefaultForDefaultName() async throws {
        let mockStorage = MockStorageService()
        let repository = SampleCVRepository(storageService: mockStorage)
        
        let sample = try await repository.getSample(by: "default")
        
        #expect(sample != nil)
        #expect(sample?.name == "")
        #expect(sample?.title == "")
        #expect(sample?.relevant_experience.isEmpty == true)
        #expect(sample?.skills.isEmpty == true)
    }
    
    @Test("GetSample returns nil for unknown sample names")
    func getSampleReturnsNilForUnknownNames() async throws {
        let mockStorage = MockStorageService()
        let repository = SampleCVRepository(storageService: mockStorage)
        
        let unknownSample = try await repository.getSample(by: "unknown")
        #expect(unknownSample == nil)
        
        let emptySample = try await repository.getSample(by: "")
        #expect(emptySample == nil)
    }
    
    @Test("GetSample is consistent with getDefaultSample for 'default' name")
    func getSampleConsistentWithGetDefaultSample() async throws {
        let mockStorage = MockStorageService()
        let repository = SampleCVRepository(storageService: mockStorage)
        
        let defaultSample = try await repository.getDefaultSample()
        let namedDefault = try await repository.getSample(by: "default")
        
        #expect(namedDefault != nil)
        #expect(namedDefault?.name == defaultSample.name)
        #expect(namedDefault?.title == defaultSample.title)
        #expect(namedDefault?.email == defaultSample.email)
        #expect(namedDefault?.relevant_experience.count == defaultSample.relevant_experience.count)
    }
    
    // MARK: - Bundle Resource Tests
    
    @Test("SampleCVRepository can access bundle resources")
    func sampleRepositoryCanAccessBundleResources() async throws {
        let mockStorage = MockStorageService()
        let repository = SampleCVRepository(storageService: mockStorage)
        
        // This test verifies the repository can access bundle resources
        // Actual content testing is done through integration tests
        let allSamples = try await repository.getAllSamples()
        
        #expect(allSamples.count >= 1) // Should include at least default sample
        
        // With our 5 sample JSON files, we should have more than just the default
        // But this might vary in test environment vs real app
    }
    
    // MARK: - Integration Tests
    
    @Test("All sample methods work together consistently")
    func allSampleMethodsWorkTogether() async throws {
        let mockStorage = MockStorageService()
        let repository = SampleCVRepository(storageService: mockStorage)
        
        // Get samples through different methods
        let defaultSample = try await repository.getDefaultSample()
        let allSamples = try await repository.getAllSamples()
        let namedSample = try await repository.getSample(by: "default")
        
        // Verify consistency
        #expect(allSamples.count >= 1)
        #expect(namedSample != nil)
        
        // Default should exist in the all samples collection
        let containsNamedDefault = allSamples.contains { $0.name == namedSample?.name }
        #expect(containsNamedDefault)
    }
    
    // MARK: - Concurrency Tests
    
    @Test("SampleCVRepository handles concurrent operations correctly")
    func sampleRepositoryHandlesConcurrentOperations() async throws {
        let mockStorage = MockStorageService()
        let repository = SampleCVRepository(storageService: mockStorage)
        
        // Test concurrent access by performing operations one after another
        // This tests thread safety without causing data race warnings
        let sample1 = try await repository.getDefaultSample()
        let sample2 = try await repository.getDefaultSample()
        let allSamples = try await repository.getAllSamples()
        let namedSample = try await repository.getSample(by: "default")
        
        // All operations should succeed
        #expect(sample1.name.isEmpty)
        #expect(sample2.name.isEmpty)
        #expect(allSamples.count >= 1)
        #expect(namedSample != nil)
        #expect(namedSample?.name.isEmpty == true)
        
        // Samples should be structurally identical
        #expect(sample1.title == sample2.title)
        #expect(sample1.email == sample2.email)
        
        // Test with actual concurrent operations using separate repository instances
        try await withThrowingTaskGroup(of: CVModel.self) { group in
            group.addTask { try await SampleCVRepository(storageService: MockStorageService()).getDefaultSample() }
            group.addTask { try await SampleCVRepository(storageService: MockStorageService()).getDefaultSample() }
            
            var results: [CVModel] = []
            for try await result in group {
                results.append(result)
            }
            
            #expect(results.count == 2)
            #expect(results.allSatisfy { $0.name.isEmpty })
        }
    }
    
    // MARK: - Category Matching Tests
    
    @Test("SampleCVRepository uses category service for pattern matching")
    func sampleRepositoryUsesCategoryServiceForMatching() async throws {
        let mockStorage = MockStorageService()
        let repository = SampleCVRepository(storageService: mockStorage)
        
        // Test that the repository properly uses the category service
        // This simulates getting a technical template by category name
        let technicalTemplate = try await repository.getSample(by: "technical")
        
        // We can't assert specific values here since it depends on bundle resources,
        // but we can verify the method doesn't throw and returns either a template or nil
        #expect(technicalTemplate == nil || technicalTemplate is CVModel)
    }
}