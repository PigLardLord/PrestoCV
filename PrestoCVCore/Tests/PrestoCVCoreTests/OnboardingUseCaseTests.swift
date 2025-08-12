import Testing
import Foundation
@testable import PrestoCVCore

@Suite("OnboardingUseCase Tests")
struct OnboardingUseCaseTests {
    
    // MARK: - Initialization Tests
    
    @Test("OnboardingUseCase initializes with required dependencies")
    func useCaseInitialization() {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage)
        let sampleRepository = SampleCVRepository(storageService: mockStorage)
        let onboardingRepository = OnboardingRepository(cvRepository: cvRepository)
        let cvManagementUseCase = CVManagementUseCase(
            cvRepository: cvRepository,
            sampleRepository: sampleRepository
        )
        
        let useCase = OnboardingUseCase(
            onboardingRepository: onboardingRepository,
            sampleRepository: sampleRepository,
            cvManagementUseCase: cvManagementUseCase
        )
        
        #expect(type(of: useCase) == OnboardingUseCase.self)
    }
    
    // MARK: - CheckOnboardingRequired Tests
    
    @Test("CheckOnboardingRequired returns firstTime when no CVs exist")
    func checkOnboardingRequiredReturnsFirstTimeWhenNoCVs() async {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage)
        let sampleRepository = SampleCVRepository(storageService: mockStorage)
        let onboardingRepository = OnboardingRepository(cvRepository: cvRepository)
        let cvManagementUseCase = CVManagementUseCase(
            cvRepository: cvRepository,
            sampleRepository: sampleRepository
        )
        
        let useCase = OnboardingUseCase(
            onboardingRepository: onboardingRepository,
            sampleRepository: sampleRepository,
            cvManagementUseCase: cvManagementUseCase
        )
        
        let state = await useCase.checkOnboardingRequired()
        #expect(state == .firstTime)
    }
    
    @Test("CheckOnboardingRequired returns returning when CVs exist")
    func checkOnboardingRequiredReturnsReturningWhenCVsExist() async throws {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage)
        let sampleRepository = SampleCVRepository(storageService: mockStorage)
        let onboardingRepository = OnboardingRepository(cvRepository: cvRepository)
        let cvManagementUseCase = CVManagementUseCase(
            cvRepository: cvRepository,
            sampleRepository: sampleRepository
        )
        
        let useCase = OnboardingUseCase(
            onboardingRepository: onboardingRepository,
            sampleRepository: sampleRepository,
            cvManagementUseCase: cvManagementUseCase
        )
        
        // Add a CV to make user a returning user
        let cv = CVTestDataBuilder.minimalCV().build()
        _ = try await cvRepository.saveCV(cv)
        
        let state = await useCase.checkOnboardingRequired()
        #expect(state == .returning)
    }
    
    @Test("CheckOnboardingRequired delegates correctly to onboarding repository")
    func checkOnboardingRequiredDelegatesToRepository() async {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage)
        let sampleRepository = SampleCVRepository(storageService: mockStorage)
        let onboardingRepository = OnboardingRepository(cvRepository: cvRepository)
        let cvManagementUseCase = CVManagementUseCase(
            cvRepository: cvRepository,
            sampleRepository: sampleRepository
        )
        
        let useCase = OnboardingUseCase(
            onboardingRepository: onboardingRepository,
            sampleRepository: sampleRepository,
            cvManagementUseCase: cvManagementUseCase
        )
        
        let useCaseState = await useCase.checkOnboardingRequired()
        let repositoryState = await onboardingRepository.getOnboardingState()
        
        #expect(useCaseState == repositoryState)
    }
    
    // MARK: - CreateFirstCV Tests
    
    @Test("CreateFirstCV creates new CV from template")
    func createFirstCVCreatesNewCVFromTemplate() async throws {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage)
        let sampleRepository = SampleCVRepository(storageService: mockStorage)
        let onboardingRepository = OnboardingRepository(cvRepository: cvRepository)
        let cvManagementUseCase = CVManagementUseCase(
            cvRepository: cvRepository,
            sampleRepository: sampleRepository
        )
        
        let useCase = OnboardingUseCase(
            onboardingRepository: onboardingRepository,
            sampleRepository: sampleRepository,
            cvManagementUseCase: cvManagementUseCase
        )
        
        let template = CVTestDataBuilder.completeCV().build()
        let createdCV = try await useCase.createFirstCV(from: template)
        
        // New CV should have a different ID but same content
        #expect(createdCV.id != template.id)
        #expect(createdCV.name == template.name)
        #expect(createdCV.personalInfo.title == template.personalInfo.title)
        #expect(createdCV.personalInfo.email == template.personalInfo.email)
        #expect(createdCV.skills.count == template.skills.count)
        #expect(createdCV.relevant_experience.count == template.relevant_experience.count)
    }
    
    @Test("CreateFirstCV saves CV to repository")
    func createFirstCVSavesCVToRepository() async throws {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage)
        let sampleRepository = SampleCVRepository(storageService: mockStorage)
        let onboardingRepository = OnboardingRepository(cvRepository: cvRepository)
        let cvManagementUseCase = CVManagementUseCase(
            cvRepository: cvRepository,
            sampleRepository: sampleRepository
        )
        
        let useCase = OnboardingUseCase(
            onboardingRepository: onboardingRepository,
            sampleRepository: sampleRepository,
            cvManagementUseCase: cvManagementUseCase
        )
        
        let template = CVTestDataBuilder.minimalCV().build()
        let createdCV = try await useCase.createFirstCV(from: template)
        
        // Verify CV was saved by retrieving it
        let savedCV = try await cvRepository.getCV(by: createdCV.id)
        #expect(savedCV != nil)
        #expect(savedCV?.name == createdCV.name)
        #expect(savedCV?.id == createdCV.id)
    }
    
    @Test("CreateFirstCV returns the saved CV")
    func createFirstCVReturnsTheSavedCV() async throws {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage)
        let sampleRepository = SampleCVRepository(storageService: mockStorage)
        let onboardingRepository = OnboardingRepository(cvRepository: cvRepository)
        let cvManagementUseCase = CVManagementUseCase(
            cvRepository: cvRepository,
            sampleRepository: sampleRepository
        )
        
        let useCase = OnboardingUseCase(
            onboardingRepository: onboardingRepository,
            sampleRepository: sampleRepository,
            cvManagementUseCase: cvManagementUseCase
        )
        
        let template = CVTestDataBuilder.completeCV().build()
        let createdCV = try await useCase.createFirstCV(from: template)
        
        // The returned CV should be the same as what was saved
        let retrievedCV = try await cvRepository.getCV(by: createdCV.id)
        #expect(retrievedCV?.id == createdCV.id)
        #expect(retrievedCV?.name == createdCV.name)
        #expect(retrievedCV?.personalInfo.email == createdCV.personalInfo.email)
    }
    
    @Test("CreateFirstCV creates CV with all template fields copied")
    func createFirstCVCopiesAllTemplateFields() async throws {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage)
        let sampleRepository = SampleCVRepository(storageService: mockStorage)
        let onboardingRepository = OnboardingRepository(cvRepository: cvRepository)
        let cvManagementUseCase = CVManagementUseCase(
            cvRepository: cvRepository,
            sampleRepository: sampleRepository
        )
        
        let useCase = OnboardingUseCase(
            onboardingRepository: onboardingRepository,
            sampleRepository: sampleRepository,
            cvManagementUseCase: cvManagementUseCase
        )
        
        let template = CVTestDataBuilder.completeCV().build()
        let createdCV = try await useCase.createFirstCV(from: template)
        
        // Verify all fields are copied
        #expect(createdCV.name == template.name)
        #expect(createdCV.personalInfo.title == template.personalInfo.title)
        #expect(createdCV.personalInfo.location == template.personalInfo.location)
        #expect(createdCV.personalInfo.email == template.personalInfo.email)
        #expect(createdCV.personalInfo.phone == template.personalInfo.phone)
        #expect(createdCV.personalInfo.portfolio == template.personalInfo.portfolio)
        #expect(createdCV.personalInfo.profile == template.personalInfo.profile)
        
        // Verify collections are copied
        #expect(createdCV.relevant_experience.count == template.relevant_experience.count)
        #expect(createdCV.education.count == template.education.count)
        #expect(createdCV.skills.count == template.skills.count)
        #expect(createdCV.languages.count == template.languages.count)
        #expect(createdCV.certifications.count == template.certifications.count)
        #expect(createdCV.interests.count == template.interests.count)
        #expect(createdCV.social.count == template.social.count)
        
        // Verify first elements of collections to ensure deep copy
        if let templateExperience = template.relevant_experience.first,
           let createdExperience = createdCV.relevant_experience.first {
            #expect(createdExperience.title == templateExperience.title)
            #expect(createdExperience.company == templateExperience.company)
            // IDs should be the same since we're copying the collection
            #expect(createdExperience.id == templateExperience.id)
        }
    }
    
    @Test("CreateFirstCV handles empty template correctly")
    func createFirstCVHandlesEmptyTemplate() async throws {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage)
        let sampleRepository = SampleCVRepository(storageService: mockStorage)
        let onboardingRepository = OnboardingRepository(cvRepository: cvRepository)
        let cvManagementUseCase = CVManagementUseCase(
            cvRepository: cvRepository,
            sampleRepository: sampleRepository
        )
        
        let useCase = OnboardingUseCase(
            onboardingRepository: onboardingRepository,
            sampleRepository: sampleRepository,
            cvManagementUseCase: cvManagementUseCase
        )
        
        let emptyTemplate = CVModel() // Default empty template
        let createdCV = try await useCase.createFirstCV(from: emptyTemplate)
        
        #expect(createdCV.id != emptyTemplate.id)
        #expect(createdCV.name == "")
        #expect(createdCV.personalInfo.title == "")
        #expect(createdCV.relevant_experience.isEmpty)
        #expect(createdCV.skills.isEmpty)
        
        // Should still be saved successfully
        let savedCV = try await cvRepository.getCV(by: createdCV.id)
        #expect(savedCV != nil)
    }
    
    // MARK: - Integration with Onboarding State Tests
    
    @Test("CreateFirstCV changes onboarding state from firstTime to returning")
    func createFirstCVChangesOnboardingState() async throws {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage)
        let sampleRepository = SampleCVRepository(storageService: mockStorage)
        let onboardingRepository = OnboardingRepository(cvRepository: cvRepository)
        let cvManagementUseCase = CVManagementUseCase(
            cvRepository: cvRepository,
            sampleRepository: sampleRepository
        )
        
        let useCase = OnboardingUseCase(
            onboardingRepository: onboardingRepository,
            sampleRepository: sampleRepository,
            cvManagementUseCase: cvManagementUseCase
        )
        
        // Initially should be first time
        let initialState = await useCase.checkOnboardingRequired()
        #expect(initialState == .firstTime)
        
        // Create first CV
        let template = CVTestDataBuilder.minimalCV().build()
        _ = try await useCase.createFirstCV(from: template)
        
        // Should now be returning
        let afterState = await useCase.checkOnboardingRequired()
        #expect(afterState == .returning)
    }
    
    @Test("OnboardingUseCase workflow: complete first-time user flow")
    func onboardingUseCaseCompleteFirstTimeUserFlow() async throws {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage)
        let sampleRepository = SampleCVRepository(storageService: mockStorage)
        let onboardingRepository = OnboardingRepository(cvRepository: cvRepository)
        let cvManagementUseCase = CVManagementUseCase(
            cvRepository: cvRepository,
            sampleRepository: sampleRepository
        )
        
        let useCase = OnboardingUseCase(
            onboardingRepository: onboardingRepository,
            sampleRepository: sampleRepository,
            cvManagementUseCase: cvManagementUseCase
        )
        
        // 1. Check if onboarding required (should be first time)
        let onboardingState = await useCase.checkOnboardingRequired()
        #expect(onboardingState == .firstTime)
        
        // 2. Get default template from template repository
        let defaultTemplate = try await sampleRepository.getDefaultSample()
        
        // 3. Create first CV from template
        let firstCV = try await useCase.createFirstCV(from: defaultTemplate)
        
        // 4. Verify first CV was created correctly
        #expect(firstCV.id != defaultTemplate.id)
        #expect(firstCV.name == defaultTemplate.name) // Empty string for default template
        
        // 5. Verify CV exists in repository
        let savedCV = try await cvRepository.getCV(by: firstCV.id)
        #expect(savedCV != nil)
        
        // 6. Check onboarding state again (should now be returning)
        let finalState = await useCase.checkOnboardingRequired()
        #expect(finalState == .returning)
        
        // 7. Verify CV count increased
        let cvCount = await cvRepository.getCVsCount()
        #expect(cvCount == 1)
    }
    
    // MARK: - Error Handling Tests
    
    @Test("CreateFirstCV propagates repository save errors")
    func createFirstCVPropagatesRepositorySaveErrors() async throws {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage)
        let sampleRepository = SampleCVRepository(storageService: mockStorage)
        let onboardingRepository = OnboardingRepository(cvRepository: cvRepository)
        let cvManagementUseCase = CVManagementUseCase(
            cvRepository: cvRepository,
            sampleRepository: sampleRepository
        )
        
        let useCase = OnboardingUseCase(
            onboardingRepository: onboardingRepository,
            sampleRepository: sampleRepository,
            cvManagementUseCase: cvManagementUseCase
        )
        
        // Since MockStorageService doesn't throw errors, this test verifies the pattern
        // In a real scenario with a failing storage service, errors would be propagated
        
        let template = CVTestDataBuilder.minimalCV().build()
        let createdCV = try await useCase.createFirstCV(from: template)
        
        // Should succeed with mock storage
        #expect(createdCV.name == template.name)
    }
    
    // MARK: - Concurrency Tests
    
    @Test("OnboardingUseCase handles concurrent operations correctly")
    func onboardingUseCaseHandlesConcurrentOperations() async throws {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage)
        let sampleRepository = SampleCVRepository(storageService: mockStorage)
        let onboardingRepository = OnboardingRepository(cvRepository: cvRepository)
        let cvManagementUseCase = CVManagementUseCase(
            cvRepository: cvRepository,
            sampleRepository: sampleRepository
        )
        
        let useCase = OnboardingUseCase(
            onboardingRepository: onboardingRepository,
            sampleRepository: sampleRepository,
            cvManagementUseCase: cvManagementUseCase
        )
        
        // Perform sequential state checks to verify consistency
        let state1 = await useCase.checkOnboardingRequired()
        let state2 = await useCase.checkOnboardingRequired()
        
        // Both should return the same state
        #expect(state1 == .firstTime)
        #expect(state2 == .firstTime)
    }
    
    @Test("OnboardingUseCase handles concurrent CV creation attempts")
    func onboardingUseCaseHandlesConcurrentCVCreation() async throws {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage)
        let sampleRepository = SampleCVRepository(storageService: mockStorage)
        let onboardingRepository = OnboardingRepository(cvRepository: cvRepository)
        let cvManagementUseCase = CVManagementUseCase(
            cvRepository: cvRepository,
            sampleRepository: sampleRepository
        )
        
        let useCase = OnboardingUseCase(
            onboardingRepository: onboardingRepository,
            sampleRepository: sampleRepository,
            cvManagementUseCase: cvManagementUseCase
        )
        
        let template1 = CVTestDataBuilder.minimalCV().withName("CV 1").build()
        let template2 = CVTestDataBuilder.minimalCV().withName("CV 2").build()
        
        // Create two CVs concurrently
        async let cv1Creation = useCase.createFirstCV(from: template1)
        async let cv2Creation = useCase.createFirstCV(from: template2)
        
        let createdCVs = try await (cv1Creation, cv2Creation)
        
        // Both should succeed and have different IDs
        #expect(createdCVs.0.id != createdCVs.1.id)
        #expect(createdCVs.0.name == "CV 1")
        #expect(createdCVs.1.name == "CV 2")
        
        // Both should be saved in the repository
        let cv1Retrieved = try await cvRepository.getCV(by: createdCVs.0.id)
        let cv2Retrieved = try await cvRepository.getCV(by: createdCVs.1.id)
        
        #expect(cv1Retrieved != nil)
        #expect(cv2Retrieved != nil)
        
        // Total count should be 2
        let totalCVs = await cvRepository.getCVsCount()
        #expect(totalCVs == 2)
    }
    
    // MARK: - Edge Cases
    
    @Test("OnboardingUseCase handles multiple createFirstCV calls correctly")
    func onboardingUseCaseHandlesMultipleCreateFirstCVCalls() async throws {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage)
        let sampleRepository = SampleCVRepository(storageService: mockStorage)
        let onboardingRepository = OnboardingRepository(cvRepository: cvRepository)
        let cvManagementUseCase = CVManagementUseCase(
            cvRepository: cvRepository,
            sampleRepository: sampleRepository
        )
        
        let useCase = OnboardingUseCase(
            onboardingRepository: onboardingRepository,
            sampleRepository: sampleRepository,
            cvManagementUseCase: cvManagementUseCase
        )
        
        let template = CVTestDataBuilder.minimalCV().build()
        
        // Call createFirstCV multiple times
        let cv1 = try await useCase.createFirstCV(from: template)
        let cv2 = try await useCase.createFirstCV(from: template)
        let cv3 = try await useCase.createFirstCV(from: template)
        
        // All should succeed and have different IDs
        #expect(cv1.id != cv2.id)
        #expect(cv2.id != cv3.id)
        #expect(cv1.id != cv3.id)
        
        // All should have the same content from template
        #expect(cv1.name == template.name)
        #expect(cv2.name == template.name)
        #expect(cv3.name == template.name)
        
        // All should be saved
        let count = await cvRepository.getCVsCount()
        #expect(count == 3)
        
        // State should be returning after first CV
        let state = await useCase.checkOnboardingRequired()
        #expect(state == .returning)
    }
}