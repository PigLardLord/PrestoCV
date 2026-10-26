import Testing
import Foundation
@testable import PrestoCVCore

@Suite("Integration Tests")
struct IntegrationTests {
    
    // MARK: - Complete New User Journey
    
    @Test("Complete new user onboarding and CV management workflow")
    func completeNewUserWorkflow() async throws {
        try await TestHelpers.withUseCases { onboardingUseCase, cvManagementUseCase in
            
            // 1. New user checks onboarding state
            let initialState = await onboardingUseCase.checkOnboardingRequired()
            #expect(initialState == .firstTime)
            
            // 2. No CVs exist initially
            let initialCVs = try await cvManagementUseCase.getAllCVs()
            #expect(initialCVs.isEmpty)
            
            // 3. User creates first CV from default template
            let container = TestDependencyContainer()
            defer { container.reset() }
            let sampleRepository = SampleCVRepository(storageService: MockStorageService(), categoryService: TemplateCategoryService(), bundleResourceService: MockBundleResourceService(), templateLoader: MockJSONTemplateLoader(), parallelSearchService: MockParallelSearchService())
            
            let defaultTemplate = try await sampleRepository.getDefaultSample()
            let firstCV = try await onboardingUseCase.createFirstCV(from: defaultTemplate)
            
            // 4. User is now a returning user
            let afterOnboardingState = await onboardingUseCase.checkOnboardingRequired()
            #expect(afterOnboardingState == .returning)
            
            // 5. CV appears in CV management system
            let cvsAfterOnboarding = try await cvManagementUseCase.getAllCVs()
            #expect(cvsAfterOnboarding.count == 1)
            #expect(cvsAfterOnboarding.first?.id == firstCV.id)
            
            // 6. User updates their CV with personal information
            let updatedCV = CVModel(
                id: firstCV.id,
                name: "John Doe",
                personalInfo: PersonalInfo(
                    name: "John Doe",
                    title: "iOS Developer",
                    location: "San Francisco, CA",
                    email: "john.doe@example.com",
                    phone: "+1-555-123-4567",
                    portfolio: "https://johndoe.dev",
                    profile: "Experienced iOS developer with passion for SwiftUI"
                ),
                relevant_experience: [
                    Experience(
                        title: "iOS Developer",
                        company: "Tech Corp",
                        location: "San Francisco, CA",
                        period: "2022-Present",
                        description: "Developing iOS applications using Swift and SwiftUI"
                    )
                ],
                education: firstCV.education,
                skills: [
                    Skill(name: "Swift", level: 5),
                    Skill(name: "SwiftUI", level: 4),
                    Skill(name: "UIKit", level: 4)
                ],
                languages: firstCV.languages,
                certifications: firstCV.certifications,
                interests: firstCV.interests,
                social: firstCV.social
            )
            
            _ = try await cvManagementUseCase.updateCV(updatedCV)
            
            // 7. User creates a second CV by duplicating the first
            let duplicatedCV = try await cvManagementUseCase.duplicateCV(id: firstCV.id, named: "John Doe (Copy)")
            #expect(duplicatedCV.name == "John Doe (Copy)")
            
            // 8. User now has 2 CVs
            let finalCVs = try await cvManagementUseCase.getAllCVs()
            #expect(finalCVs.count == 2)
            
            // 9. Both CVs have the updated information (original and copy)
            let originalCV = finalCVs.first { $0.id == firstCV.id }
            let copyCV = finalCVs.first { $0.id == duplicatedCV.id }
            
            #expect(originalCV?.name == "John Doe")
            #expect(copyCV?.name == "John Doe (Copy)")
            #expect(originalCV?.skills.count == 3)
            #expect(copyCV?.skills.count == 3)
            
            // 10. User remains a returning user throughout
            let finalState = await onboardingUseCase.checkOnboardingRequired()
            #expect(finalState == .returning)
        }
    }
    
    // MARK: - Returning User Journey
    
    @Test("Returning user workflow with existing CVs")
    func returningUserWorkflow() async throws {
        try await TestHelpers.withUseCases { onboardingUseCase, cvManagementUseCase in
            
            // Setup: User already has CVs (simulate returning user)
            let _ = CVTestDataBuilder.completeCV().withName("Existing CV").build()
            let template = CVTestDataBuilder.completeCV().build()
            let createdCV = try await cvManagementUseCase.createCV(from: template)
            
            // 1. User checks onboarding state - should be returning
            let state = await onboardingUseCase.checkOnboardingRequired()
            #expect(state == .returning)
            
            // 2. User can see their existing CVs
            let existingCVs = try await cvManagementUseCase.getAllCVs()
            #expect(existingCVs.count == 1)
            #expect(existingCVs.first?.id == createdCV.id)
            
            // 3. User creates additional CVs from templates
            let template2 = CVTestDataBuilder.minimalCV().withName("Professional CV").build()
            let secondCV = try await cvManagementUseCase.createCV(from: template2)
            
            // 4. User can manage multiple CVs
            let allCVs = try await cvManagementUseCase.getAllCVs()
            #expect(allCVs.count == 2)
            
            // 5. User can duplicate and modify CVs
            let duplicatedCV = try await cvManagementUseCase.duplicateCV(id: secondCV.id, named: "Copy")
            
            let modifiedCV = CVModel(
                id: duplicatedCV.id,
                name: "Specialized CV for Startups",
                personalInfo: PersonalInfo(
                    name: duplicatedCV.personalInfo.name,
                    title: duplicatedCV.personalInfo.title,
                    location: duplicatedCV.personalInfo.location,
                    email: duplicatedCV.personalInfo.email,
                    phone: duplicatedCV.personalInfo.phone,
                    portfolio: duplicatedCV.personalInfo.portfolio,
                    profile: "Startup-focused developer with entrepreneurial mindset"
                ),
                relevant_experience: duplicatedCV.relevant_experience,
                education: duplicatedCV.education,
                skills: duplicatedCV.skills,
                languages: duplicatedCV.languages,
                certifications: duplicatedCV.certifications,
                interests: duplicatedCV.interests,
                social: duplicatedCV.social
            )
            
            _ = try await cvManagementUseCase.updateCV(modifiedCV)
            
            // 6. Final state: User has 3 customized CVs
            let finalCVs = try await cvManagementUseCase.getAllCVs()
            #expect(finalCVs.count == 3)
            
            let cvNames = finalCVs.map { $0.name }.sorted()
            #expect(cvNames.contains("Professional CV"))
            #expect(cvNames.contains("Specialized CV for Startups"))
        }
    }
    
    // MARK: - Template System Integration
    
    @Test("Template system integration with user workflows")
    func templateSystemIntegrationWorkflow() async throws {
        try await TestHelpers.withTestContainer { container in
            let sampleRepository = SampleCVRepository(storageService: MockStorageService(), categoryService: TemplateCategoryService(), bundleResourceService: MockBundleResourceService(), templateLoader: MockJSONTemplateLoader(), parallelSearchService: MockParallelSearchService())
            let onboardingUseCase = try container.makeOnboardingUseCase()
            let cvManagementUseCase = try container.makeCVManagementUseCase()
            
            // 1. Get available templates
            let availableTemplates = try await sampleRepository.getAllSamples()
            #expect(availableTemplates.count == 1) // Default template
            
            let defaultTemplate = try await sampleRepository.getDefaultSample()
            let namedDefaultTemplate = try await sampleRepository.getSample(by: "default")
            
            #expect(namedDefaultTemplate != nil)
            
            // 2. Create CV from default template through onboarding
            let onboardingCV = try await onboardingUseCase.createFirstCV(from: defaultTemplate)
            
            // 3. Create additional CV from named template through CV management
            let managementCV = try await cvManagementUseCase.createCV(from: namedDefaultTemplate!)
            
            // 4. Both CVs should exist and have similar structure
            let allCVs = try await cvManagementUseCase.getAllCVs()
            #expect(allCVs.count == 2)
            
            // 5. Template characteristics should be preserved
            let onboardingResult = allCVs.first { $0.id == onboardingCV.id }
            let managementResult = allCVs.first { $0.id == managementCV.id }
            
            #expect(onboardingResult?.name == "") // Default template has empty name
            #expect(managementResult?.name == "") // Same for named default
            #expect(onboardingResult?.skills.isEmpty == true)
            #expect(managementResult?.skills.isEmpty == true)
        }
    }
    
    // MARK: - Storage Persistence Integration
    
    @Test("Data persistence across different components")
    func dataPersistenceIntegration() async throws {
        // Use same mock storage across all components to test persistence
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage)
        let sampleRepository = SampleCVRepository(
            storageService: mockStorage,
            categoryService: TemplateCategoryService(),
            bundleResourceService: MockBundleResourceService(),
            templateLoader: MockJSONTemplateLoader(),
            parallelSearchService: MockParallelSearchService()
        )
        let onboardingRepository = OnboardingRepository(cvRepository: cvRepository)
        
        let cvManagementUseCase = CVManagementUseCase(
            cvRepository: cvRepository,
            sampleRepository: sampleRepository
        )
        
        let onboardingUseCase = OnboardingUseCase(
            onboardingRepository: onboardingRepository,
            sampleRepository: sampleRepository,
            cvManagementUseCase: cvManagementUseCase
        )
        
        // 1. Create CV through onboarding
        let template = try await sampleRepository.getDefaultSample()
        let cv1 = try await onboardingUseCase.createFirstCV(from: template)
        
        // 2. Verify persistence - CV should be accessible through different paths
        let directRepoCV = try await cvRepository.getCV(by: cv1.id)
        let mgmtUseCaseCVs = try await cvManagementUseCase.getAllCVs()
        
        #expect(directRepoCV != nil)
        #expect(directRepoCV?.id == cv1.id)
        #expect(mgmtUseCaseCVs.contains { $0.id == cv1.id })
        
        // 3. Update CV through CV management
        let updatedCV = CVModel(
            id: cv1.id,
            name: "Updated through management",
            personalInfo: PersonalInfo(
                name: cv1.personalInfo.name,
                title: cv1.personalInfo.title,
                location: cv1.personalInfo.location,
                email: cv1.personalInfo.email,
                phone: cv1.personalInfo.phone,
                portfolio: cv1.personalInfo.portfolio,
                profile: cv1.personalInfo.profile
            ),
            relevant_experience: cv1.relevant_experience,
            education: cv1.education,
            skills: cv1.skills,
            languages: cv1.languages,
            certifications: cv1.certifications,
            interests: cv1.interests,
            social: cv1.social
        )
        
        _ = try await cvManagementUseCase.updateCV(updatedCV)
        
        // 4. Verify update is reflected across all access paths
        let updatedDirectRepo = try await cvRepository.getCV(by: cv1.id)
        let updatedOnboardingState = await onboardingUseCase.checkOnboardingRequired()
        
        #expect(updatedDirectRepo?.name == "Updated through management")
        #expect(updatedOnboardingState == .returning) // Should still be returning
        
        // 5. Storage should have consistent data
        let storageIdentifiers = try await mockStorage.getAllIdentifiers()
        #expect(storageIdentifiers.count == 1)
        
        let storedCV = try await mockStorage.load(CVModel.self, from: storageIdentifiers.first!)
        #expect(storedCV?.name == "Updated through management")
    }
    
    // MARK: - Error Recovery Integration
    
    @Test("Error recovery across components")
    func errorRecoveryIntegration() async throws {
        try await TestHelpers.withUseCases { onboardingUseCase, cvManagementUseCase in
            
            // 1. Normal operation - create CV
            let template = CVTestDataBuilder.minimalCV().build()
            let cv = try await onboardingUseCase.createFirstCV(from: template)
            
            // 2. Attempt invalid operation - duplicate non-existent CV
            let nonExistentId = UUID()
            
            await #expect(throws: AppError.self) {
                _ = try await cvManagementUseCase.duplicateCV(id: nonExistentId, named: "Copy")
            }
            
            // 3. System should remain consistent after error
            let state = await onboardingUseCase.checkOnboardingRequired()
            #expect(state == .returning) // Original CV should still exist
            
            let allCVs = try await cvManagementUseCase.getAllCVs()
            #expect(allCVs.count == 1) // No additional CVs created due to error
            #expect(allCVs.first?.id == cv.id) // Original CV still exists
            
            // 4. Subsequent operations should work normally
            let duplicatedCV = try await cvManagementUseCase.duplicateCV(id: cv.id, named: "Copy")
            #expect(duplicatedCV.id != cv.id)
            
            let finalCVs = try await cvManagementUseCase.getAllCVs()
            #expect(finalCVs.count == 2)
        }
    }
    
    // MARK: - Large Dataset Integration
    
    @Test("System performance with larger datasets")
    func largeDatasetIntegration() async throws {
        try await TestHelpers.withUseCases { onboardingUseCase, cvManagementUseCase in
            
            // 1. Create onboarding CV
            let template = CVTestDataBuilder.minimalCV().withName("Base CV").build()
            _ = try await onboardingUseCase.createFirstCV(from: template)
            
            // 2. Create many additional CVs
            let cvCount = 50
            var createdCVs: [CVModel] = []
            
            for i in 1...cvCount {
                let cvTemplate = CVTestDataBuilder.minimalCV().withName("CV \(i)").build()
                let cv = try await cvManagementUseCase.createCV(from: cvTemplate)
                createdCVs.append(cv)
            }
            
            // 3. System should handle large dataset
            let allCVs = try await cvManagementUseCase.getAllCVs()
            #expect(allCVs.count == cvCount + 1) // +1 for onboarding CV
            
            // 4. Onboarding state should still work correctly
            let state = await onboardingUseCase.checkOnboardingRequired()
            #expect(state == .returning)
            
            // 5. Operations on specific CVs should still work
            let randomCV = createdCVs.randomElement()!
            let duplicatedCV = try await cvManagementUseCase.duplicateCV(id: randomCV.id, named: "\(randomCV.name) (Copy)")
            
            #expect(duplicatedCV.name.hasSuffix("(Copy)"))
            
            let finalCount = try await cvManagementUseCase.getAllCVs()
            #expect(finalCount.count == cvCount + 2) // +1 onboarding, +1 duplicate
            
            // 6. Cleanup - delete some CVs
            let cvsToDelete = createdCVs.prefix(10)
            for cv in cvsToDelete {
                try await cvManagementUseCase.deleteCV(id: cv.id)
            }
            
            let afterDeletion = try await cvManagementUseCase.getAllCVs()
            #expect(afterDeletion.count == cvCount + 2 - 10)
            
            // 7. Should still be returning user (at least onboarding CV exists)
            let finalState = await onboardingUseCase.checkOnboardingRequired()
            #expect(finalState == .returning)
        }
    }
    
    // MARK: - Concurrent Operations Integration
    
    @Test("Multiple operations across use cases")
    func multipleOperationsIntegration() async throws {
        try await TestHelpers.withUseCases { onboardingUseCase, cvManagementUseCase in
            
            // 1. Setup initial state
            let template = CVTestDataBuilder.minimalCV().withName("Initial CV").build()
            let initialCV = try await onboardingUseCase.createFirstCV(from: template)
            
            // 2. Perform operations - testing multiple interleaved operations
            let template2 = CVTestDataBuilder.minimalCV().withName("Concurrent CV 1").build()
            let template3 = CVTestDataBuilder.minimalCV().withName("Concurrent CV 2").build()
            
            // Test that operations work correctly when executed in sequence
            // This tests the actor isolation is working properly
            let createResult1 = try await cvManagementUseCase.createCV(from: template2)
            let createResult2 = try await cvManagementUseCase.createCV(from: template3)
            let duplicateResult = try await cvManagementUseCase.duplicateCV(id: initialCV.id, named: "Initial CV (Copy)")
            let stateResult = await onboardingUseCase.checkOnboardingRequired()
            let getAllResult = try await cvManagementUseCase.getAllCVs()
            
            // 3. Verify all operations succeeded
            #expect(createResult1.name == "Concurrent CV 1")
            #expect(createResult2.name == "Concurrent CV 2")
            #expect(duplicateResult.name == "Initial CV (Copy)")
            #expect(stateResult == .returning)
            #expect(getAllResult.count >= 1) // At least the initial CV
            
            // 4. Final consistency check
            let finalCVs = try await cvManagementUseCase.getAllCVs()
            #expect(finalCVs.count == 4) // initial + 2 created + 1 duplicated
            
            let finalState = await onboardingUseCase.checkOnboardingRequired()
            #expect(finalState == .returning)
            
            // 5. All CVs should have unique IDs
            let cvIds = finalCVs.map { $0.id }
            let uniqueIds = Set(cvIds)
            #expect(uniqueIds.count == finalCVs.count)
        }
    }
    
    // MARK: - Complex Data Structures Integration
    
    @Test("Complex CV data structures integration")
    func complexDataStructuresIntegration() async throws {
        try await TestHelpers.withUseCases { onboardingUseCase, cvManagementUseCase in
            
            // 1. Create CV with complex data from complete template
            let complexTemplate = CVTestDataBuilder.completeCV().build()
            let complexCV = try await onboardingUseCase.createFirstCV(from: complexTemplate)
            
            // 2. Verify complex data persisted correctly
            let retrievedCVs = try await cvManagementUseCase.getAllCVs()
            let retrievedCV = retrievedCVs.first { $0.id == complexCV.id }
            
            #expect(retrievedCV != nil)
            #expect(retrievedCV?.skills.count == complexTemplate.skills.count)
            #expect(retrievedCV?.relevant_experience.count == complexTemplate.relevant_experience.count)
            #expect(retrievedCV?.education.count == complexTemplate.education.count)
            #expect(retrievedCV?.languages.count == complexTemplate.languages.count)
            #expect(retrievedCV?.certifications.count == complexTemplate.certifications.count)
            #expect(retrievedCV?.interests.count == complexTemplate.interests.count)
            #expect(retrievedCV?.social.count == complexTemplate.social.count)
            
            // 3. Duplicate complex CV
            let duplicatedComplexCV = try await cvManagementUseCase.duplicateCV(id: complexCV.id, named: "Copy")
            
            // 4. Verify all complex data was duplicated
            #expect(duplicatedComplexCV.skills.count == complexCV.skills.count)
            #expect(duplicatedComplexCV.relevant_experience.count == complexCV.relevant_experience.count)
            #expect(duplicatedComplexCV.certifications.first?.year == complexCV.certifications.first?.year)
            
            // 5. Modify complex data
            let modifiedSkills = complexCV.skills + [
                Skill(name: "Docker", level: 3),
                Skill(name: "Kubernetes", level: 2)
            ]
            
            let modifiedCV = CVModel(
                id: complexCV.id,
                name: complexCV.name,
                personalInfo: PersonalInfo(
                    name: complexCV.personalInfo.name,
                    title: "Senior Full Stack Developer",
                    location: complexCV.personalInfo.location,
                    email: complexCV.personalInfo.email,
                    phone: complexCV.personalInfo.phone,
                    portfolio: complexCV.personalInfo.portfolio,
                    profile: complexCV.personalInfo.profile
                ),
                relevant_experience: complexCV.relevant_experience,
                education: complexCV.education,
                skills: modifiedSkills,
                languages: complexCV.languages,
                certifications: complexCV.certifications,
                interests: complexCV.interests,
                social: complexCV.social
            )
            
            _ = try await cvManagementUseCase.updateCV(modifiedCV)
            
            // 6. Verify modifications persisted
            let finalCVs = try await cvManagementUseCase.getAllCVs()
            let finalCV = finalCVs.first { $0.id == complexCV.id }
            
            #expect(finalCV?.personalInfo.title == "Senior Full Stack Developer")
            #expect(finalCV?.skills.count == modifiedSkills.count)
            #expect(finalCV?.skills.contains { $0.name == "Docker" } == true)
        }
    }
}