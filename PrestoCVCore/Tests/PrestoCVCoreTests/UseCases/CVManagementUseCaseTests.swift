import Testing
import Foundation
@testable import PrestoCVCore

@Suite("CVManagementUseCase Tests")
struct CVManagementUseCaseTests {
    
    // MARK: - Initialization Tests
    
    @Test("CVManagementUseCase initializes with required dependencies")
    func useCaseInitialization() {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage)
        let sampleRepository = SampleCVRepository(storageService: mockStorage, categoryService: TemplateCategoryService(), bundleResourceService: MockBundleResourceService(), templateLoader: MockJSONTemplateLoader(), parallelSearchService: MockParallelSearchService())
        
        let useCase = CVManagementUseCase(
            cvRepository: cvRepository,
            sampleRepository: sampleRepository
        )
        
        #expect(type(of: useCase) == CVManagementUseCase.self)
    }
    
    // MARK: - GetAllCVs Tests
    
    @Test("GetAllCVs returns empty array when no CVs exist")
    func getAllCVsReturnsEmptyWhenNoCVs() async throws {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage)
        let sampleRepository = SampleCVRepository(storageService: mockStorage, categoryService: TemplateCategoryService(), bundleResourceService: MockBundleResourceService(), templateLoader: MockJSONTemplateLoader(), parallelSearchService: MockParallelSearchService())
        
        let useCase = CVManagementUseCase(
            cvRepository: cvRepository,
            sampleRepository: sampleRepository
        )
        
        let cvs = try await useCase.getAllCVs()
        #expect(cvs.isEmpty)
    }
    
    @Test("GetAllCVs returns all stored CVs")
    func getAllCVsReturnsAllStoredCVs() async throws {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage)
        let sampleRepository = SampleCVRepository(storageService: mockStorage, categoryService: TemplateCategoryService(), bundleResourceService: MockBundleResourceService(), templateLoader: MockJSONTemplateLoader(), parallelSearchService: MockParallelSearchService())
        
        let useCase = CVManagementUseCase(
            cvRepository: cvRepository,
            sampleRepository: sampleRepository
        )
        
        // Create and save CVs directly through repository
        let cv1 = CVTestDataBuilder.minimalCV().withName("CV 1").build()
        let cv2 = CVTestDataBuilder.minimalCV().withName("CV 2").build()
        
        _ = try await cvRepository.saveCV(cv1)
        _ = try await cvRepository.saveCV(cv2)
        
        let allCVs = try await useCase.getAllCVs()
        
        #expect(allCVs.count == 2)
        let names = allCVs.map { $0.name }.sorted()
        #expect(names == ["CV 1", "CV 2"])
    }
    
    @Test("GetAllCVs delegates to CV repository")
    func getAllCVsDelegatesToCVRepository() async throws {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage)
        let sampleRepository = SampleCVRepository(storageService: mockStorage, categoryService: TemplateCategoryService(), bundleResourceService: MockBundleResourceService(), templateLoader: MockJSONTemplateLoader(), parallelSearchService: MockParallelSearchService())
        
        let useCase = CVManagementUseCase(
            cvRepository: cvRepository,
            sampleRepository: sampleRepository
        )
        
        let cv = CVTestDataBuilder.completeCV().build()
        _ = try await cvRepository.saveCV(cv)
        
        let useCaseCVs = try await useCase.getAllCVs()
        let repositoryCVs = try await cvRepository.getAllCVs()
        
        #expect(useCaseCVs.count == repositoryCVs.count)
        #expect(useCaseCVs.first?.id == repositoryCVs.first?.id)
    }
    
    @Test("GetCVListing delegates to CV repository")
    func getCVListingDelegatesToCVRepository() async throws {
        let mockStorage = MockStorageService()
        mockStorage.unreadableCount = 2
        let cvRepository = CVRepository(storageService: mockStorage)
        let sampleRepository = SampleCVRepository(storageService: mockStorage, categoryService: TemplateCategoryService(), bundleResourceService: MockBundleResourceService(), templateLoader: MockJSONTemplateLoader(), parallelSearchService: MockParallelSearchService())
        let useCase = CVManagementUseCase(cvRepository: cvRepository, sampleRepository: sampleRepository)
        let cv = CVTestDataBuilder.completeCV().build()
        _ = try await cvRepository.saveCV(cv)
        
        let listing = try await useCase.getCVListing()
        
        #expect(listing == CVListing(cvs: [cv], unreadableCount: 2))
    }
    
    @Test("AcknowledgeUnreadableCVs delegates to CV repository")
    func acknowledgeUnreadableCVsDelegatesToCVRepository() async throws {
        let mockStorage = MockStorageService()
        mockStorage.unreadableCount = 1
        let cvRepository = CVRepository(storageService: mockStorage)
        let sampleRepository = SampleCVRepository(storageService: mockStorage, categoryService: TemplateCategoryService(), bundleResourceService: MockBundleResourceService(), templateLoader: MockJSONTemplateLoader(), parallelSearchService: MockParallelSearchService())
        let useCase = CVManagementUseCase(cvRepository: cvRepository, sampleRepository: sampleRepository)
        
        try await useCase.acknowledgeUnreadableCVs()
        
        #expect(mockStorage.acknowledgeCount == 1)
        #expect(try await useCase.getCVListing().unreadableCount == 0)
    }
    
    // MARK: - CreateCV Tests
    
    @Test("CreateCV creates new CV from template")
    func createCVCreatesNewCVFromTemplate() async throws {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage)
        let sampleRepository = SampleCVRepository(storageService: mockStorage, categoryService: TemplateCategoryService(), bundleResourceService: MockBundleResourceService(), templateLoader: MockJSONTemplateLoader(), parallelSearchService: MockParallelSearchService())
        
        let useCase = CVManagementUseCase(
            cvRepository: cvRepository,
            sampleRepository: sampleRepository
        )
        
        let template = CVTestDataBuilder.completeCV().build()
        let createdCV = try await useCase.createCV(from: template)
        
        // New CV should have different ID but same content
        #expect(createdCV.id != template.id)
        #expect(createdCV.name == template.name)
        #expect(createdCV.personalInfo.name == template.personalInfo.name)
        #expect(createdCV.personalInfo.title == template.personalInfo.title)
        #expect(createdCV.personalInfo.email == template.personalInfo.email)
        #expect(createdCV.skills.count == template.skills.count)
    }
    
    @Test("CreateCV saves CV to repository")
    func createCVSavesCVToRepository() async throws {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage)
        let sampleRepository = SampleCVRepository(storageService: mockStorage, categoryService: TemplateCategoryService(), bundleResourceService: MockBundleResourceService(), templateLoader: MockJSONTemplateLoader(), parallelSearchService: MockParallelSearchService())
        
        let useCase = CVManagementUseCase(
            cvRepository: cvRepository,
            sampleRepository: sampleRepository
        )
        
        let template = CVTestDataBuilder.minimalCV().withName("Test CV").build()
        let createdCV = try await useCase.createCV(from: template)
        
        // Verify CV was saved by retrieving it
        let savedCV = try await cvRepository.getCV(by: createdCV.id)
        #expect(savedCV != nil)
        #expect(savedCV?.name == "Test CV")
        #expect(savedCV?.id == createdCV.id)
    }
    
    @Test("CreateCV copies all template fields")
    func createCVCopiesAllTemplateFields() async throws {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage)
        let sampleRepository = SampleCVRepository(storageService: mockStorage, categoryService: TemplateCategoryService(), bundleResourceService: MockBundleResourceService(), templateLoader: MockJSONTemplateLoader(), parallelSearchService: MockParallelSearchService())
        
        let useCase = CVManagementUseCase(
            cvRepository: cvRepository,
            sampleRepository: sampleRepository
        )
        
        let template = CVTestDataBuilder.completeCV().build()
        let createdCV = try await useCase.createCV(from: template)
        
        // Verify all fields are copied
        #expect(createdCV.name == template.name)
        #expect(createdCV.personalInfo.name == template.personalInfo.name)
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
    }
    
    // MARK: - UpdateCV Tests
    
    @Test("UpdateCV saves updated CV to repository")
    func updateCVSavesUpdatedCV() async throws {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage)
        let sampleRepository = SampleCVRepository(storageService: mockStorage, categoryService: TemplateCategoryService(), bundleResourceService: MockBundleResourceService(), templateLoader: MockJSONTemplateLoader(), parallelSearchService: MockParallelSearchService())
        
        let useCase = CVManagementUseCase(
            cvRepository: cvRepository,
            sampleRepository: sampleRepository
        )
        
        // Create initial CV
        let originalCV = CVTestDataBuilder.minimalCV().withName("Original Name").build()
        _ = try await cvRepository.saveCV(originalCV)
        
        // Update CV
        let updatedPersonalInfo = PersonalInfo(
            name: originalCV.personalInfo.name,
            title: "Senior Developer",
            location: originalCV.personalInfo.location,
            email: originalCV.personalInfo.email,
            phone: originalCV.personalInfo.phone,
            portfolio: originalCV.personalInfo.portfolio,
            profile: originalCV.personalInfo.profile
        )
        
        let updatedCV = CVModel(
            id: originalCV.id,
            name: "Updated Name",
            personalInfo: updatedPersonalInfo,
            relevant_experience: originalCV.relevant_experience,
            education: originalCV.education,
            skills: originalCV.skills,
            languages: originalCV.languages,
            certifications: originalCV.certifications,
            interests: originalCV.interests,
            social: originalCV.social
        )
        
        let result = try await useCase.updateCV(updatedCV)
        
        #expect(result.id == updatedCV.id)
        #expect(result.name == "Updated Name")
        #expect(result.personalInfo.title == "Senior Developer")
        
        // Verify update was persisted
        let retrievedCV = try await cvRepository.getCV(by: originalCV.id)
        #expect(retrievedCV?.name == "Updated Name")
        #expect(retrievedCV?.personalInfo.title == "Senior Developer")
    }
    
    @Test("UpdateCV returns the updated CV")
    func updateCVReturnsUpdatedCV() async throws {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage)
        let sampleRepository = SampleCVRepository(storageService: mockStorage, categoryService: TemplateCategoryService(), bundleResourceService: MockBundleResourceService(), templateLoader: MockJSONTemplateLoader(), parallelSearchService: MockParallelSearchService())
        
        let useCase = CVManagementUseCase(
            cvRepository: cvRepository,
            sampleRepository: sampleRepository
        )
        
        let cv = CVTestDataBuilder.completeCV().build()
        _ = try await cvRepository.saveCV(cv)
        
        let updatedPersonalInfo = PersonalInfo(
            name: cv.personalInfo.name,
            title: cv.personalInfo.title,
            location: cv.personalInfo.location,
            email: "new@email.com",
            phone: cv.personalInfo.phone,
            portfolio: cv.personalInfo.portfolio,
            profile: cv.personalInfo.profile
        )
        
        let updatedCV = CVModel(
            id: cv.id,
            name: "New Name",
            personalInfo: updatedPersonalInfo,
            relevant_experience: cv.relevant_experience,
            education: cv.education,
            skills: cv.skills,
            languages: cv.languages,
            certifications: cv.certifications,
            interests: cv.interests,
            social: cv.social
        )
        
        let result = try await useCase.updateCV(updatedCV)
        
        #expect(result.id == updatedCV.id)
        #expect(result.name == "New Name")
        #expect(result.personalInfo.email == "new@email.com")
    }
    
    @Test("UpdateCV handles complex field updates")
    func updateCVHandlesComplexFieldUpdates() async throws {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage)
        let sampleRepository = SampleCVRepository(storageService: mockStorage, categoryService: TemplateCategoryService(), bundleResourceService: MockBundleResourceService(), templateLoader: MockJSONTemplateLoader(), parallelSearchService: MockParallelSearchService())
        
        let useCase = CVManagementUseCase(
            cvRepository: cvRepository,
            sampleRepository: sampleRepository
        )
        
        let originalCV = CVTestDataBuilder.completeCV().build()
        _ = try await cvRepository.saveCV(originalCV)
        
        // Update with new skills and experience
        let newSkills = [
            Skill(name: "Python", level: 4),
            Skill(name: "JavaScript", level: 5)
        ]
        
        let newExperience = [
            Experience(
                title: "Senior Engineer",
                company: "New Company",
                location: "Remote",
                period: "2024-Present",
                description: "Leading development"
            )
        ]
        
        let updatedPersonalInfo = PersonalInfo(
            name: originalCV.personalInfo.name,
            title: "Senior Software Engineer",
            location: originalCV.personalInfo.location,
            email: originalCV.personalInfo.email,
            phone: originalCV.personalInfo.phone,
            portfolio: originalCV.personalInfo.portfolio,
            profile: "Updated profile"
        )
        
        let updatedCV = CVModel(
            id: originalCV.id,
            name: originalCV.name,
            personalInfo: updatedPersonalInfo,
            relevant_experience: newExperience,
            education: originalCV.education,
            skills: newSkills,
            languages: originalCV.languages,
            certifications: originalCV.certifications,
            interests: originalCV.interests,
            social: originalCV.social
        )
        
        let result = try await useCase.updateCV(updatedCV)
        
        #expect(result.personalInfo.title == "Senior Software Engineer")
        #expect(result.personalInfo.profile == "Updated profile")
        #expect(result.skills.count == 2)
        #expect(result.skills.first?.name == "Python")
        #expect(result.relevant_experience.count == 1)
        #expect(result.relevant_experience.first?.company == "New Company")
    }
    
    // MARK: - DeleteCV Tests
    
    @Test("DeleteCV removes CV from repository")
    func deleteCVRemovesCVFromRepository() async throws {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage)
        let sampleRepository = SampleCVRepository(storageService: mockStorage, categoryService: TemplateCategoryService(), bundleResourceService: MockBundleResourceService(), templateLoader: MockJSONTemplateLoader(), parallelSearchService: MockParallelSearchService())
        
        let useCase = CVManagementUseCase(
            cvRepository: cvRepository,
            sampleRepository: sampleRepository
        )
        
        let cv = CVTestDataBuilder.minimalCV().build()
        _ = try await cvRepository.saveCV(cv)
        
        // Verify CV exists before deletion
        let beforeDelete = try await cvRepository.getCV(by: cv.id)
        #expect(beforeDelete != nil)
        
        try await useCase.deleteCV(id: cv.id)
        
        // Verify CV is gone after deletion
        let afterDelete = try await cvRepository.getCV(by: cv.id)
        #expect(afterDelete == nil)
    }
    
    @Test("DeleteCV handles non-existent CV gracefully")
    func deleteCVHandlesNonExistentCV() async throws {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage)
        let sampleRepository = SampleCVRepository(storageService: mockStorage, categoryService: TemplateCategoryService(), bundleResourceService: MockBundleResourceService(), templateLoader: MockJSONTemplateLoader(), parallelSearchService: MockParallelSearchService())
        
        let useCase = CVManagementUseCase(
            cvRepository: cvRepository,
            sampleRepository: sampleRepository
        )
        
        let nonExistentId = UUID()
        
        // Should not throw when deleting non-existent CV
        try await useCase.deleteCV(id: nonExistentId)
    }
    
    @Test("DeleteCV delegates to CV repository")
    func deleteCVDelegatesToCVRepository() async throws {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage)
        let sampleRepository = SampleCVRepository(storageService: mockStorage, categoryService: TemplateCategoryService(), bundleResourceService: MockBundleResourceService(), templateLoader: MockJSONTemplateLoader(), parallelSearchService: MockParallelSearchService())
        
        let useCase = CVManagementUseCase(
            cvRepository: cvRepository,
            sampleRepository: sampleRepository
        )
        
        let cv1 = CVTestDataBuilder.minimalCV().withName("CV 1").build()
        let cv2 = CVTestDataBuilder.minimalCV().withName("CV 2").build()
        
        _ = try await cvRepository.saveCV(cv1)
        _ = try await cvRepository.saveCV(cv2)
        
        try await useCase.deleteCV(id: cv1.id)
        
        // Verify state through both use case and repository
        let useCaseCVs = try await useCase.getAllCVs()
        let repositoryCVs = try await cvRepository.getAllCVs()
        
        #expect(useCaseCVs.count == 1)
        #expect(repositoryCVs.count == 1)
        #expect(useCaseCVs.first?.name == "CV 2")
        #expect(repositoryCVs.first?.name == "CV 2")
    }
    
    // MARK: - DuplicateCV Tests
    
    @Test("DuplicateCV creates copy of existing CV")
    func duplicateCVCreatesExactCopy() async throws {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage)
        let sampleRepository = SampleCVRepository(storageService: mockStorage, categoryService: TemplateCategoryService(), bundleResourceService: MockBundleResourceService(), templateLoader: MockJSONTemplateLoader(), parallelSearchService: MockParallelSearchService())
        
        let useCase = CVManagementUseCase(
            cvRepository: cvRepository,
            sampleRepository: sampleRepository
        )
        
        let originalCV = CVTestDataBuilder.completeCV().withName("Original CV").build()
        _ = try await cvRepository.saveCV(originalCV)
        
        let duplicatedCV = try await useCase.duplicateCV(id: originalCV.id)
        
        // Should have different ID but same content (with modified name)
        #expect(duplicatedCV.id != originalCV.id)
        #expect(duplicatedCV.name == "Original CV action.copy_suffix")
        #expect(duplicatedCV.personalInfo.name == originalCV.personalInfo.name)
        #expect(duplicatedCV.personalInfo.title == originalCV.personalInfo.title)
        #expect(duplicatedCV.personalInfo.email == originalCV.personalInfo.email)
        #expect(duplicatedCV.skills.count == originalCV.skills.count)
        #expect(duplicatedCV.relevant_experience.count == originalCV.relevant_experience.count)
    }
    
    @Test("DuplicateCV saves duplicated CV to repository")
    func duplicateCVSavesDuplicatedCV() async throws {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage)
        let sampleRepository = SampleCVRepository(storageService: mockStorage, categoryService: TemplateCategoryService(), bundleResourceService: MockBundleResourceService(), templateLoader: MockJSONTemplateLoader(), parallelSearchService: MockParallelSearchService())
        
        let useCase = CVManagementUseCase(
            cvRepository: cvRepository,
            sampleRepository: sampleRepository
        )
        
        let originalCV = CVTestDataBuilder.minimalCV().withName("Test CV").build()
        _ = try await cvRepository.saveCV(originalCV)
        
        let duplicatedCV = try await useCase.duplicateCV(id: originalCV.id)
        
        // Verify both CVs exist in repository
        let allCVs = try await cvRepository.getAllCVs()
        #expect(allCVs.count == 2)
        
        let retrievedDuplicate = try await cvRepository.getCV(by: duplicatedCV.id)
        #expect(retrievedDuplicate != nil)
        #expect(retrievedDuplicate?.name == "Test CV action.copy_suffix")
    }
    
    @Test("DuplicateCV appends '(Copy)' to name")
    func duplicateCVAppendsCoypToName() async throws {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage)
        let sampleRepository = SampleCVRepository(storageService: mockStorage, categoryService: TemplateCategoryService(), bundleResourceService: MockBundleResourceService(), templateLoader: MockJSONTemplateLoader(), parallelSearchService: MockParallelSearchService())
        
        let useCase = CVManagementUseCase(
            cvRepository: cvRepository,
            sampleRepository: sampleRepository
        )
        
        let originalCV = CVTestDataBuilder.minimalCV().withName("My Professional CV").build()
        _ = try await cvRepository.saveCV(originalCV)
        
        let duplicatedCV = try await useCase.duplicateCV(id: originalCV.id)
        
        #expect(duplicatedCV.name == "My Professional CV action.copy_suffix")
    }
    
    @Test("DuplicateCV names a copy of an unnamed CV after the name the list shows, Untitled CV", arguments: ["", "   "])
    func duplicateCVHandlesEmptyName(name: String) async throws {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage)
        let sampleRepository = SampleCVRepository(storageService: mockStorage, categoryService: TemplateCategoryService(), bundleResourceService: MockBundleResourceService(), templateLoader: MockJSONTemplateLoader(), parallelSearchService: MockParallelSearchService())
        
        let useCase = CVManagementUseCase(
            cvRepository: cvRepository,
            sampleRepository: sampleRepository
        )
        
        let originalCV = CVTestDataBuilder.minimalCV().withName(name).build()
        _ = try await cvRepository.saveCV(originalCV)
        
        let duplicatedCV = try await useCase.duplicateCV(id: originalCV.id)
        
        // The package has no string catalog, so a text is its key
        #expect(duplicatedCV.name == "cv.untitled action.copy_suffix")
    }
    
    @Test("DuplicateCV throws error for non-existent CV")
    func duplicateCVThrowsErrorForNonExistentCV() async throws {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage)
        let sampleRepository = SampleCVRepository(storageService: mockStorage, categoryService: TemplateCategoryService(), bundleResourceService: MockBundleResourceService(), templateLoader: MockJSONTemplateLoader(), parallelSearchService: MockParallelSearchService())
        
        let useCase = CVManagementUseCase(
            cvRepository: cvRepository,
            sampleRepository: sampleRepository
        )
        
        let nonExistentId = UUID()
        
        await #expect(throws: AppError.self) {
            _ = try await useCase.duplicateCV(id: nonExistentId)
        }
    }
    
    @Test("DuplicateCV copies all fields including collections")
    func duplicateCVCopiesAllFields() async throws {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage)
        let sampleRepository = SampleCVRepository(storageService: mockStorage, categoryService: TemplateCategoryService(), bundleResourceService: MockBundleResourceService(), templateLoader: MockJSONTemplateLoader(), parallelSearchService: MockParallelSearchService())
        
        let useCase = CVManagementUseCase(
            cvRepository: cvRepository,
            sampleRepository: sampleRepository
        )
        
        let originalCV = CVTestDataBuilder.completeCV().build()
        _ = try await cvRepository.saveCV(originalCV)
        
        let duplicatedCV = try await useCase.duplicateCV(id: originalCV.id)
        
        // Verify all fields except name and ID are identical
        #expect(duplicatedCV.personalInfo.name == originalCV.personalInfo.name)
        #expect(duplicatedCV.personalInfo.title == originalCV.personalInfo.title)
        #expect(duplicatedCV.personalInfo.location == originalCV.personalInfo.location)
        #expect(duplicatedCV.personalInfo.email == originalCV.personalInfo.email)
        #expect(duplicatedCV.personalInfo.phone == originalCV.personalInfo.phone)
        #expect(duplicatedCV.personalInfo.portfolio == originalCV.personalInfo.portfolio)
        #expect(duplicatedCV.personalInfo.profile == originalCV.personalInfo.profile)
        
        // Verify collections are copied
        #expect(duplicatedCV.relevant_experience.count == originalCV.relevant_experience.count)
        #expect(duplicatedCV.education.count == originalCV.education.count)
        #expect(duplicatedCV.skills.count == originalCV.skills.count)
        #expect(duplicatedCV.languages.count == originalCV.languages.count)
        #expect(duplicatedCV.certifications.count == originalCV.certifications.count)
        #expect(duplicatedCV.interests.count == originalCV.interests.count)
        #expect(duplicatedCV.social.count == originalCV.social.count)
        
        // Verify collection content is identical
        if let originalSkill = originalCV.skills.first,
           let duplicatedSkill = duplicatedCV.skills.first {
            #expect(duplicatedSkill.name == originalSkill.name)
            #expect(duplicatedSkill.level == originalSkill.level)
            // IDs should be the same for nested objects
            #expect(duplicatedSkill.id == originalSkill.id)
        }
    }
    
    // MARK: - Integration Tests
    
    @Test("CVManagementUseCase full CRUD workflow")
    func cvManagementUseCaseFullCRUDWorkflow() async throws {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage)
        let sampleRepository = SampleCVRepository(storageService: mockStorage, categoryService: TemplateCategoryService(), bundleResourceService: MockBundleResourceService(), templateLoader: MockJSONTemplateLoader(), parallelSearchService: MockParallelSearchService())
        
        let useCase = CVManagementUseCase(
            cvRepository: cvRepository,
            sampleRepository: sampleRepository
        )
        
        // 1. Start with empty state
        var allCVs = try await useCase.getAllCVs()
        #expect(allCVs.isEmpty)
        
        // 2. Create first CV
        let template = CVTestDataBuilder.minimalCV().withName("First CV").build()
        let firstCV = try await useCase.createCV(from: template)
        
        allCVs = try await useCase.getAllCVs()
        #expect(allCVs.count == 1)
        #expect(allCVs.first?.name == "First CV")
        
        // 3. Create second CV
        let template2 = CVTestDataBuilder.minimalCV().withName("Second CV").build()
        let secondCV = try await useCase.createCV(from: template2)
        
        allCVs = try await useCase.getAllCVs()
        #expect(allCVs.count == 2)
        
        // 4. Update first CV
        let updatedPersonalInfo = PersonalInfo(
            name: firstCV.personalInfo.name,
            title: "Updated Title",
            location: firstCV.personalInfo.location,
            email: firstCV.personalInfo.email,
            phone: firstCV.personalInfo.phone,
            portfolio: firstCV.personalInfo.portfolio,
            profile: firstCV.personalInfo.profile
        )
        
        let updatedFirstCV = CVModel(
            id: firstCV.id,
            name: "Updated First CV",
            personalInfo: updatedPersonalInfo,
            relevant_experience: firstCV.relevant_experience,
            education: firstCV.education,
            skills: firstCV.skills,
            languages: firstCV.languages,
            certifications: firstCV.certifications,
            interests: firstCV.interests,
            social: firstCV.social
        )
        
        _ = try await useCase.updateCV(updatedFirstCV)
        
        allCVs = try await useCase.getAllCVs()
        let updatedCV = allCVs.first { $0.id == firstCV.id }
        #expect(updatedCV?.name == "Updated First CV")
        #expect(updatedCV?.personalInfo.title == "Updated Title")
        
        // 5. Duplicate second CV
        let duplicatedCV = try await useCase.duplicateCV(id: secondCV.id)
        
        allCVs = try await useCase.getAllCVs()
        #expect(allCVs.count == 3)
        #expect(duplicatedCV.name == "Second CV action.copy_suffix")
        
        // 6. Delete original second CV
        try await useCase.deleteCV(id: secondCV.id)
        
        allCVs = try await useCase.getAllCVs()
        #expect(allCVs.count == 2)
        
        let remainingNames = allCVs.map { $0.name }.sorted()
        #expect(remainingNames == ["Second CV action.copy_suffix", "Updated First CV"])
        
        // 7. Delete all remaining CVs
        try await useCase.deleteCV(id: firstCV.id)
        try await useCase.deleteCV(id: duplicatedCV.id)
        
        allCVs = try await useCase.getAllCVs()
        #expect(allCVs.isEmpty)
    }
    
    // MARK: - Concurrency Tests
    
    @Test("CVManagementUseCase handles concurrent operations correctly")
    func cvManagementUseCaseHandlesConcurrentOperations() async throws {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage)
        let sampleRepository = SampleCVRepository(storageService: mockStorage, categoryService: TemplateCategoryService(), bundleResourceService: MockBundleResourceService(), templateLoader: MockJSONTemplateLoader(), parallelSearchService: MockParallelSearchService())
        
        let useCase = CVManagementUseCase(
            cvRepository: cvRepository,
            sampleRepository: sampleRepository
        )
        
        let template1 = CVTestDataBuilder.minimalCV().withName("CV 1").build()
        let template2 = CVTestDataBuilder.minimalCV().withName("CV 2").build()
        let template3 = CVTestDataBuilder.minimalCV().withName("CV 3").build()
        
        // Create multiple CVs concurrently
        async let cv1Creation = useCase.createCV(from: template1)
        async let cv2Creation = useCase.createCV(from: template2)
        async let cv3Creation = useCase.createCV(from: template3)
        
        let createdCVs = try await (cv1Creation, cv2Creation, cv3Creation)
        
        // All should succeed with different IDs
        #expect(createdCVs.0.name == "CV 1")
        #expect(createdCVs.1.name == "CV 2")
        #expect(createdCVs.2.name == "CV 3")
        
        #expect(createdCVs.0.id != createdCVs.1.id)
        #expect(createdCVs.1.id != createdCVs.2.id)
        #expect(createdCVs.0.id != createdCVs.2.id)
        
        // Verify all are saved
        let allCVs = try await useCase.getAllCVs()
        #expect(allCVs.count == 3)
    }
    
    // MARK: - Error Handling Tests
    
    @Test("CVManagementUseCase propagates repository errors correctly")
    func cvManagementUseCasePropagatesRepositoryErrors() async throws {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage)
        let sampleRepository = SampleCVRepository(storageService: mockStorage, categoryService: TemplateCategoryService(), bundleResourceService: MockBundleResourceService(), templateLoader: MockJSONTemplateLoader(), parallelSearchService: MockParallelSearchService())
        
        let useCase = CVManagementUseCase(
            cvRepository: cvRepository,
            sampleRepository: sampleRepository
        )
        
        // Test error propagation for duplicate operation on non-existent CV
        let nonExistentId = UUID()
        
        await #expect(throws: AppError.self) {
            _ = try await useCase.duplicateCV(id: nonExistentId)
        }
    }
}