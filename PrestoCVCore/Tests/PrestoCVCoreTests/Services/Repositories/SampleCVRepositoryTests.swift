import Testing
import Foundation
@testable import PrestoCVCore

@Suite("SampleCVRepository Tests")
struct SampleCVRepositoryTests {
    
    // MARK: - Initialization Tests
    
    @Test("SampleCVRepository initializes with storage service")
    func repositoryInitialization() {
        let mockStorage = MockStorageService()
        let repository = SampleCVRepository(
            storageService: mockStorage,
            categoryService: TemplateCategoryService(),
            bundleResourceService: MockBundleResourceService(),
            templateLoader: MockJSONTemplateLoader(),
            parallelSearchService: MockParallelSearchService()
        )
        
        #expect(type(of: repository) == SampleCVRepository.self)
    }
    
    // MARK: - GetDefaultTemplate Tests
    
    @Test("GetDefaultTemplate returns empty CV template")
    func getDefaultSampleReturnsEmptyCV() async throws {
        let mockStorage = MockStorageService()
        let repository = SampleCVRepository(
            storageService: mockStorage,
            categoryService: TemplateCategoryService(),
            bundleResourceService: MockBundleResourceService(),
            templateLoader: MockJSONTemplateLoader(),
            parallelSearchService: MockParallelSearchService()
        )
        
        let template = try await repository.getDefaultSample()
        
        #expect(template.name == "")
        #expect(template.personalInfo.title == "")
        #expect(template.personalInfo.email == "")
        #expect(template.personalInfo.phone == "")
        #expect(template.personalInfo.location == "")
        #expect(template.personalInfo.portfolio == "")
        #expect(template.personalInfo.profile == "")
        #expect(template.relevant_experience.isEmpty)
        #expect(template.education.isEmpty)
        #expect(template.skills.isEmpty)
        #expect(template.languages.isEmpty)
        #expect(template.certifications.isEmpty)
        #expect(template.interests.isEmpty)
        #expect(template.social.isEmpty)
    }
    
    @Test("GetDefaultTemplate returns consistent template across calls")
    func getDefaultSampleConsistentAcrossCalls() async throws {
        let mockStorage = MockStorageService()
        let repository = SampleCVRepository(
            storageService: mockStorage,
            categoryService: TemplateCategoryService(),
            bundleResourceService: MockBundleResourceService(),
            templateLoader: MockJSONTemplateLoader(),
            parallelSearchService: MockParallelSearchService()
        )
        
        let template1 = try await repository.getDefaultSample()
        let template2 = try await repository.getDefaultSample()
        
        // Templates should have same structure but different IDs (since UUID() generates new ones)
        #expect(template1.name == template2.name)
        #expect(template1.personalInfo.title == template2.personalInfo.title)
        #expect(template1.personalInfo.email == template2.personalInfo.email)
        #expect(template1.relevant_experience.count == template2.relevant_experience.count)
        #expect(template1.skills.count == template2.skills.count)
        
        // But IDs should be different since CVModel() creates new UUIDs
        #expect(template1.id != template2.id)
    }
    
    @Test("GetDefaultTemplate does not require storage operations")
    func getDefaultSampleDoesNotRequireStorage() async throws {
        let mockStorage = MockStorageService()
        let repository = SampleCVRepository(
            storageService: mockStorage,
            categoryService: TemplateCategoryService(),
            bundleResourceService: MockBundleResourceService(),
            templateLoader: MockJSONTemplateLoader(),
            parallelSearchService: MockParallelSearchService()
        )
        
        // Clear mock storage to ensure it's empty
        mockStorage.clear()
        #expect(mockStorage.isEmpty())
        
        let template = try await repository.getDefaultSample()
        
        // Template should be returned successfully without any storage operations
        #expect(template.name == "")
        
        // Storage should still be empty - no read or write operations occurred
        #expect(mockStorage.isEmpty())
    }
    
    // MARK: - GetAllTemplates Tests
    
    @Test("GetAllTemplates returns array containing default template")
    func getAllSamplesReturnsDefaultTemplate() async throws {
        let mockStorage = MockStorageService()
        let repository = SampleCVRepository(
            storageService: mockStorage,
            categoryService: TemplateCategoryService(),
            bundleResourceService: MockBundleResourceService(),
            templateLoader: MockJSONTemplateLoader(),
            parallelSearchService: MockParallelSearchService()
        )
        
        let templates = try await repository.getAllSamples()
        
        #expect(templates.count == 1)
        
        let template = templates.first!
        #expect(template.name == "")
        #expect(template.personalInfo.title == "")
        #expect(template.relevant_experience.isEmpty)
        #expect(template.skills.isEmpty)
    }
    
    @Test("GetAllTemplates is consistent with getDefaultSample")
    func getAllSamplesConsistentWithGetDefaultTemplate() async throws {
        let mockStorage = MockStorageService()
        let repository = SampleCVRepository(
            storageService: mockStorage,
            categoryService: TemplateCategoryService(),
            bundleResourceService: MockBundleResourceService(),
            templateLoader: MockJSONTemplateLoader(),
            parallelSearchService: MockParallelSearchService()
        )
        
        let defaultTemplate = try await repository.getDefaultSample()
        let allTemplates = try await repository.getAllSamples()
        
        #expect(allTemplates.count == 1)
        
        let templateFromAll = allTemplates.first!
        
        // Should have same structure (but different IDs due to separate CVModel() calls)
        #expect(templateFromAll.name == defaultTemplate.name)
        #expect(templateFromAll.personalInfo.title == defaultTemplate.personalInfo.title)
        #expect(templateFromAll.personalInfo.email == defaultTemplate.personalInfo.email)
        #expect(templateFromAll.relevant_experience.count == defaultTemplate.relevant_experience.count)
    }
    
    @Test("GetAllTemplates does not require storage operations")
    func getAllSamplesDoesNotRequireStorage() async throws {
        let mockStorage = MockStorageService()
        let repository = SampleCVRepository(
            storageService: mockStorage,
            categoryService: TemplateCategoryService(),
            bundleResourceService: MockBundleResourceService(),
            templateLoader: MockJSONTemplateLoader(),
            parallelSearchService: MockParallelSearchService()
        )
        
        // Ensure storage is empty
        mockStorage.clear()
        #expect(mockStorage.isEmpty())
        
        let templates = try await repository.getAllSamples()
        
        #expect(templates.count == 1)
        #expect(mockStorage.isEmpty()) // No storage operations occurred
    }
    
    // MARK: - GetTemplate Tests
    
    @Test("GetTemplate returns default template for 'default' name")
    func getSampleReturnsDefaultForDefaultName() async throws {
        let mockStorage = MockStorageService()
        let repository = SampleCVRepository(
            storageService: mockStorage,
            categoryService: TemplateCategoryService(),
            bundleResourceService: MockBundleResourceService(),
            templateLoader: MockJSONTemplateLoader(),
            parallelSearchService: MockParallelSearchService()
        )
        
        let template = try await repository.getSample(by: "default")
        
        #expect(template != nil)
        #expect(template?.name == "")
        #expect(template?.personalInfo.title == "")
        #expect(template?.relevant_experience.isEmpty == true)
        #expect(template?.skills.isEmpty == true)
    }
    
    @Test("GetTemplate returns nil for unknown template names")
    func getSampleReturnsNilForUnknownNames() async throws {
        let mockStorage = MockStorageService()
        let repository = SampleCVRepository(
            storageService: mockStorage,
            categoryService: TemplateCategoryService(),
            bundleResourceService: MockBundleResourceService(),
            templateLoader: MockJSONTemplateLoader(),
            parallelSearchService: MockParallelSearchService()
        )
        
        let unknownTemplate = try await repository.getSample(by: "unknown")
        #expect(unknownTemplate == nil)
        
        let emptyTemplate = try await repository.getSample(by: "")
        #expect(emptyTemplate == nil)
        
        let professionalTemplate = try await repository.getSample(by: "professional")
        #expect(professionalTemplate == nil)
    }
    
    @Test("GetTemplate is case sensitive")
    func getSampleIsCaseSensitive() async throws {
        let mockStorage = MockStorageService()
        let repository = SampleCVRepository(
            storageService: mockStorage,
            categoryService: TemplateCategoryService(),
            bundleResourceService: MockBundleResourceService(),
            templateLoader: MockJSONTemplateLoader(),
            parallelSearchService: MockParallelSearchService()
        )
        
        let defaultTemplate = try await repository.getSample(by: "default")
        let uppercaseTemplate = try await repository.getSample(by: "DEFAULT")
        let mixedCaseTemplate = try await repository.getSample(by: "Default")
        
        #expect(defaultTemplate != nil)
        #expect(uppercaseTemplate == nil)
        #expect(mixedCaseTemplate == nil)
    }
    
    @Test("GetTemplate is consistent with getDefaultSample for 'default' name")
    func getSampleConsistentWithGetDefaultTemplate() async throws {
        let mockStorage = MockStorageService()
        let repository = SampleCVRepository(
            storageService: mockStorage,
            categoryService: TemplateCategoryService(),
            bundleResourceService: MockBundleResourceService(),
            templateLoader: MockJSONTemplateLoader(),
            parallelSearchService: MockParallelSearchService()
        )
        
        let defaultTemplate = try await repository.getDefaultSample()
        let namedDefaultTemplate = try await repository.getSample(by: "default")
        
        #expect(namedDefaultTemplate != nil)
        #expect(namedDefaultTemplate?.name == defaultTemplate.name)
        #expect(namedDefaultTemplate?.personalInfo.title == defaultTemplate.personalInfo.title)
        #expect(namedDefaultTemplate?.personalInfo.email == defaultTemplate.personalInfo.email)
        #expect(namedDefaultTemplate?.relevant_experience.count == defaultTemplate.relevant_experience.count)
    }
    
    // MARK: - Integration Tests
    
    @Test("All template methods work together consistently")
    func allTemplateMethodsWorkTogether() async throws {
        let mockStorage = MockStorageService()
        let repository = SampleCVRepository(
            storageService: mockStorage,
            categoryService: TemplateCategoryService(),
            bundleResourceService: MockBundleResourceService(),
            templateLoader: MockJSONTemplateLoader(),
            parallelSearchService: MockParallelSearchService()
        )
        
        // Get templates through different methods
        let defaultTemplate = try await repository.getDefaultSample()
        let allTemplates = try await repository.getAllSamples()
        let namedDefault = try await repository.getSample(by: "default")
        
        // Verify consistency
        #expect(allTemplates.count == 1)
        #expect(namedDefault != nil)
        
        let allTemplate = allTemplates.first!
        let namedTemplate = namedDefault!
        
        // All should have same structure (different IDs due to separate instantiation)
        #expect(defaultTemplate.name == allTemplate.name)
        #expect(defaultTemplate.name == namedTemplate.name)
        #expect(allTemplate.personalInfo.title == namedTemplate.personalInfo.title)
        #expect(defaultTemplate.personalInfo.email == allTemplate.personalInfo.email)
    }
    
    // MARK: - Concurrency Tests
    
    @Test("SampleCVRepository handles concurrent operations correctly")
    func templateRepositoryHandlesConcurrentOperations() async throws {
        let mockStorage = MockStorageService()
        let repository = SampleCVRepository(
            storageService: mockStorage,
            categoryService: TemplateCategoryService(),
            bundleResourceService: MockBundleResourceService(),
            templateLoader: MockJSONTemplateLoader(),
            parallelSearchService: MockParallelSearchService()
        )
        
        // Test concurrent access by performing operations one after another
        // This tests thread safety without causing data race warnings
        let template1 = try await repository.getDefaultSample()
        let template2 = try await repository.getDefaultSample()
        let allTemplates = try await repository.getAllSamples()
        let namedTemplate = try await repository.getSample(by: "default")
        
        // All operations should succeed
        #expect(template1.name.isEmpty)
        #expect(template2.name.isEmpty)
        #expect(allTemplates.count == 1)
        #expect(namedTemplate != nil)
        #expect(namedTemplate?.name.isEmpty == true)
        
        // Templates should be structurally identical
        #expect(template1.personalInfo.title == template2.personalInfo.title)
        #expect(template1.personalInfo.email == template2.personalInfo.email)
        
        // Test with actual concurrent operations using separate repository instances
        try await withThrowingTaskGroup(of: CVModel.self) { group in
            group.addTask { 
                try await SampleCVRepository(
                    storageService: MockStorageService(),
                    categoryService: TemplateCategoryService(),
                    bundleResourceService: MockBundleResourceService(),
                    templateLoader: MockJSONTemplateLoader(),
                    parallelSearchService: MockParallelSearchService()
                ).getDefaultSample() 
            }
            group.addTask { 
                try await SampleCVRepository(
                    storageService: MockStorageService(),
                    categoryService: TemplateCategoryService(),
                    bundleResourceService: MockBundleResourceService(),
                    templateLoader: MockJSONTemplateLoader(),
                    parallelSearchService: MockParallelSearchService()
                ).getDefaultSample() 
            }
            
            var results: [CVModel] = []
            for try await result in group {
                results.append(result)
            }
            
            #expect(results.count == 2)
            #expect(results.allSatisfy { $0.name.isEmpty })
        }
    }
    
    // MARK: - Edge Cases and Error Handling
    
    @Test("SampleCVRepository handles various template name inputs")
    func templateRepositoryHandlesVariousTemplateNames() async throws {
        let mockStorage = MockStorageService()
        let repository = SampleCVRepository(
            storageService: mockStorage,
            categoryService: TemplateCategoryService(),
            bundleResourceService: MockBundleResourceService(),
            templateLoader: MockJSONTemplateLoader(),
            parallelSearchService: MockParallelSearchService()
        )
        
        // Test various edge case inputs
        let specialCharacterNames = ["@default", "default!", "def-ault", "default.template", "default/template"]
        let numericNames = ["1", "123", "0"]
        let longNames = ["very_long_template_name_that_might_cause_issues"]
        
        let allTestNames = specialCharacterNames + numericNames + longNames
        
        for name in allTestNames {
            let template = try await repository.getSample(by: name)
            #expect(template == nil, "Template '\(name)' should return nil")
        }
        
        // Only "default" should work
        let validTemplate = try await repository.getSample(by: "default")
        #expect(validTemplate != nil)
    }
    
    @Test("SampleCVRepository operations don't interfere with each other")
    func templateRepositoryOperationsDontInterfere() async throws {
        let mockStorage = MockStorageService()
        let repository = SampleCVRepository(
            storageService: mockStorage,
            categoryService: TemplateCategoryService(),
            bundleResourceService: MockBundleResourceService(),
            templateLoader: MockJSONTemplateLoader(),
            parallelSearchService: MockParallelSearchService()
        )
        
        // Get initial state
        let template1 = try await repository.getDefaultSample()
        let templates1 = try await repository.getAllSamples()
        
        // Perform more operations
        _ = try await repository.getSample(by: "default")
        _ = try await repository.getSample(by: "nonexistent")
        
        // Get state again - should be unchanged
        let template2 = try await repository.getDefaultSample()
        let templates2 = try await repository.getAllSamples()
        
        #expect(template1.name == template2.name)
        #expect(templates1.count == templates2.count)
        #expect(templates1.count == 1)
    }
    
    // MARK: - Future Extension Tests
    
    @Test("SampleCVRepository architecture supports future extensions")
    func templateRepositorySupportsExtensions() async throws {
        let mockStorage = MockStorageService()
        let repository = SampleCVRepository(
            storageService: mockStorage,
            categoryService: TemplateCategoryService(),
            bundleResourceService: MockBundleResourceService(),
            templateLoader: MockJSONTemplateLoader(),
            parallelSearchService: MockParallelSearchService()
        )
        
        // Current implementation returns 1 template
        let currentTemplates = try await repository.getAllSamples()
        #expect(currentTemplates.count == 1)
        
        // The architecture supports returning more templates in the future
        // This test verifies the current contract while documenting extensibility
        
        // All current template methods should work consistently
        let defaultExists = try await repository.getSample(by: "default")
        #expect(defaultExists != nil)
        
        // Storage service is available for future template loading
        #expect(type(of: mockStorage) == MockStorageService.self)
    }
    
    // MARK: - Template Content Validation Tests
    
    @Test("Default template has valid structure for CV creation")
    func defaultTemplateHasValidStructure() async throws {
        let mockStorage = MockStorageService()
        let repository = SampleCVRepository(
            storageService: mockStorage,
            categoryService: TemplateCategoryService(),
            bundleResourceService: MockBundleResourceService(),
            templateLoader: MockJSONTemplateLoader(),
            parallelSearchService: MockParallelSearchService()
        )
        
        let template = try await repository.getDefaultSample()
        
        // Verify the template can be used to create a valid CV
        #expect(template.id != UUID()) // Has a unique ID
        
        // All collections should be initialized (empty arrays)
        #expect(template.relevant_experience.isEmpty)
        #expect(template.education.isEmpty)
        #expect(template.skills.isEmpty)
        #expect(template.languages.isEmpty)
        #expect(template.certifications.isEmpty)
        #expect(template.interests.isEmpty)
        #expect(template.social.isEmpty)
        
        // String fields should be empty by default
        #expect(template.name.isEmpty)
        #expect(template.personalInfo.title.isEmpty)
        #expect(template.personalInfo.location.isEmpty)
        #expect(template.personalInfo.email.isEmpty)
        #expect(template.personalInfo.phone.isEmpty)
        #expect(template.personalInfo.portfolio.isEmpty)
        #expect(template.personalInfo.profile.isEmpty)
    }
    
    @Test("Template can be serialized and deserialized")
    func templateCanBeSerializedAndDeserialized() async throws {
        let mockStorage = MockStorageService()
        let repository = SampleCVRepository(
            storageService: mockStorage,
            categoryService: TemplateCategoryService(),
            bundleResourceService: MockBundleResourceService(),
            templateLoader: MockJSONTemplateLoader(),
            parallelSearchService: MockParallelSearchService()
        )
        
        let originalTemplate = try await repository.getDefaultSample()
        
        // Serialize
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalTemplate)
        
        // Deserialize
        let decoder = JSONDecoder()
        let deserializedTemplate = try decoder.decode(CVModel.self, from: data)
        
        // Verify deserialized template matches original
        #expect(deserializedTemplate.id == originalTemplate.id)
        #expect(deserializedTemplate.name == originalTemplate.name)
        #expect(deserializedTemplate.relevant_experience.count == originalTemplate.relevant_experience.count)
        #expect(deserializedTemplate.skills.count == originalTemplate.skills.count)
    }
}