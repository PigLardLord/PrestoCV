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
        let templateRepository = TemplateRepository(storageService: mockStorage)
        
        let useCase = CVManagementUseCase(
            cvRepository: cvRepository,
            templateRepository: templateRepository
        )
        
        #expect(type(of: useCase) == CVManagementUseCase.self)
    }
    
    // MARK: - GetAllCVs Tests
    
    @Test("GetAllCVs returns empty array when no CVs exist")
    func getAllCVsReturnsEmptyWhenNoCVs() async throws {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage)
        let templateRepository = TemplateRepository(storageService: mockStorage)
        
        let useCase = CVManagementUseCase(
            cvRepository: cvRepository,
            templateRepository: templateRepository
        )
        
        let cvs = try await useCase.getAllCVs()
        #expect(cvs.isEmpty)
    }
    
    @Test("GetAllCVs returns all stored CVs")
    func getAllCVsReturnsAllStoredCVs() async throws {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage)
        let templateRepository = TemplateRepository(storageService: mockStorage)
        
        let useCase = CVManagementUseCase(
            cvRepository: cvRepository,
            templateRepository: templateRepository
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
        let templateRepository = TemplateRepository(storageService: mockStorage)
        
        let useCase = CVManagementUseCase(
            cvRepository: cvRepository,
            templateRepository: templateRepository
        )
        
        let cv = CVTestDataBuilder.completeCV().build()
        _ = try await cvRepository.saveCV(cv)
        
        let useCaseCVs = try await useCase.getAllCVs()
        let repositoryCVs = try await cvRepository.getAllCVs()
        
        #expect(useCaseCVs.count == repositoryCVs.count)
        #expect(useCaseCVs.first?.id == repositoryCVs.first?.id)
    }
    
    // MARK: - CreateCV Tests
    
    @Test("CreateCV creates new CV from template")
    func createCVCreatesNewCVFromTemplate() async throws {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage)
        let templateRepository = TemplateRepository(storageService: mockStorage)
        
        let useCase = CVManagementUseCase(
            cvRepository: cvRepository,
            templateRepository: templateRepository
        )
        
        let template = CVTestDataBuilder.completeCV().build()
        let createdCV = try await useCase.createCV(from: template)
        
        // New CV should have different ID but same content
        #expect(createdCV.id != template.id)
        #expect(createdCV.name == template.name)
        #expect(createdCV.title == template.title)
        #expect(createdCV.email == template.email)
        #expect(createdCV.skills.count == template.skills.count)
    }
    
    @Test("CreateCV saves CV to repository")
    func createCVSavesCVToRepository() async throws {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage)
        let templateRepository = TemplateRepository(storageService: mockStorage)
        
        let useCase = CVManagementUseCase(
            cvRepository: cvRepository,
            templateRepository: templateRepository
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
        let templateRepository = TemplateRepository(storageService: mockStorage)
        
        let useCase = CVManagementUseCase(
            cvRepository: cvRepository,
            templateRepository: templateRepository
        )
        
        let template = CVTestDataBuilder.completeCV().build()
        let createdCV = try await useCase.createCV(from: template)
        
        // Verify all fields are copied
        #expect(createdCV.name == template.name)
        #expect(createdCV.title == template.title)
        #expect(createdCV.location == template.location)
        #expect(createdCV.email == template.email)
        #expect(createdCV.phone == template.phone)
        #expect(createdCV.portfolio == template.portfolio)
        #expect(createdCV.profile == template.profile)
        
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
        let templateRepository = TemplateRepository(storageService: mockStorage)
        
        let useCase = CVManagementUseCase(
            cvRepository: cvRepository,
            templateRepository: templateRepository
        )
        
        // Create initial CV
        let originalCV = CVTestDataBuilder.minimalCV().withName("Original Name").build()
        _ = try await cvRepository.saveCV(originalCV)
        
        // Update CV
        let updatedCV = CVModel(
            id: originalCV.id,
            name: "Updated Name",
            title: originalCV.title,
            location: originalCV.location,
            email: originalCV.email,
            phone: originalCV.phone,
            portfolio: originalCV.portfolio,
            profile: originalCV.profile,
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
        
        // Verify update was persisted
        let retrievedCV = try await cvRepository.getCV(by: originalCV.id)
        #expect(retrievedCV?.name == "Updated Name")
    }
    
    @Test("UpdateCV returns the updated CV")
    func updateCVReturnsUpdatedCV() async throws {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage)
        let templateRepository = TemplateRepository(storageService: mockStorage)
        
        let useCase = CVManagementUseCase(
            cvRepository: cvRepository,
            templateRepository: templateRepository
        )
        
        let cv = CVTestDataBuilder.completeCV().build()
        _ = try await cvRepository.saveCV(cv)
        
        let updatedCV = CVTestDataBuilder.completeCV()
            .withName("New Name")
            .withEmail("new@email.com")
            .build(id: cv.id)
        
        let result = try await useCase.updateCV(updatedCV)
        
        #expect(result.id == updatedCV.id)
        #expect(result.name == "New Name")
        #expect(result.email == "new@email.com")
    }
    
    @Test("UpdateCV handles complex field updates")
    func updateCVHandlesComplexFieldUpdates() async throws {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage)
        let templateRepository = TemplateRepository(storageService: mockStorage)
        
        let useCase = CVManagementUseCase(
            cvRepository: cvRepository,
            templateRepository: templateRepository
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
        
        let updatedCV = CVModel(
            id: originalCV.id,
            name: originalCV.name,
            title: "Senior Software Engineer",
            location: originalCV.location,
            email: originalCV.email,
            phone: originalCV.phone,
            portfolio: originalCV.portfolio,
            profile: "Updated profile",
            relevant_experience: newExperience,
            education: originalCV.education,
            skills: newSkills,
            languages: originalCV.languages,
            certifications: originalCV.certifications,
            interests: originalCV.interests,
            social: originalCV.social
        )
        
        let result = try await useCase.updateCV(updatedCV)
        
        #expect(result.title == "Senior Software Engineer")
        #expect(result.profile == "Updated profile")
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
        let templateRepository = TemplateRepository(storageService: mockStorage)
        
        let useCase = CVManagementUseCase(
            cvRepository: cvRepository,
            templateRepository: templateRepository
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
        let templateRepository = TemplateRepository(storageService: mockStorage)
        
        let useCase = CVManagementUseCase(
            cvRepository: cvRepository,
            templateRepository: templateRepository
        )
        
        let nonExistentId = UUID()
        
        // Should not throw when deleting non-existent CV
        try await useCase.deleteCV(id: nonExistentId)
    }
    
    @Test("DeleteCV delegates to CV repository")
    func deleteCVDelegatesToCVRepository() async throws {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage)
        let templateRepository = TemplateRepository(storageService: mockStorage)
        
        let useCase = CVManagementUseCase(
            cvRepository: cvRepository,
            templateRepository: templateRepository
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
        let templateRepository = TemplateRepository(storageService: mockStorage)
        
        let useCase = CVManagementUseCase(
            cvRepository: cvRepository,
            templateRepository: templateRepository
        )
        
        let originalCV = CVTestDataBuilder.completeCV().withName("Original CV").build()
        _ = try await cvRepository.saveCV(originalCV)
        
        let duplicatedCV = try await useCase.duplicateCV(id: originalCV.id)
        
        // Should have different ID but same content (with modified name)
        #expect(duplicatedCV.id != originalCV.id)
        #expect(duplicatedCV.name == "Original CV (Copy)")
        #expect(duplicatedCV.title == originalCV.title)
        #expect(duplicatedCV.email == originalCV.email)
        #expect(duplicatedCV.skills.count == originalCV.skills.count)
        #expect(duplicatedCV.relevant_experience.count == originalCV.relevant_experience.count)
    }
    
    @Test("DuplicateCV saves duplicated CV to repository")
    func duplicateCVSavesDuplicatedCV() async throws {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage)
        let templateRepository = TemplateRepository(storageService: mockStorage)
        
        let useCase = CVManagementUseCase(
            cvRepository: cvRepository,
            templateRepository: templateRepository
        )
        
        let originalCV = CVTestDataBuilder.minimalCV().withName("Test CV").build()
        _ = try await cvRepository.saveCV(originalCV)
        
        let duplicatedCV = try await useCase.duplicateCV(id: originalCV.id)
        
        // Verify both CVs exist in repository
        let allCVs = try await cvRepository.getAllCVs()
        #expect(allCVs.count == 2)
        
        let retrievedDuplicate = try await cvRepository.getCV(by: duplicatedCV.id)
        #expect(retrievedDuplicate != nil)
        #expect(retrievedDuplicate?.name == "Test CV (Copy)")
    }
    
    @Test("DuplicateCV appends '(Copy)' to name")
    func duplicateCVAppendsCoypToName() async throws {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage)
        let templateRepository = TemplateRepository(storageService: mockStorage)
        
        let useCase = CVManagementUseCase(
            cvRepository: cvRepository,
            templateRepository: templateRepository
        )
        
        let originalCV = CVTestDataBuilder.minimalCV().withName("My Professional CV").build()
        _ = try await cvRepository.saveCV(originalCV)
        
        let duplicatedCV = try await useCase.duplicateCV(id: originalCV.id)
        
        #expect(duplicatedCV.name == "My Professional CV (Copy)")
    }
    
    @Test("DuplicateCV handles empty name correctly")
    func duplicateCVHandlesEmptyName() async throws {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage)
        let templateRepository = TemplateRepository(storageService: mockStorage)
        
        let useCase = CVManagementUseCase(
            cvRepository: cvRepository,
            templateRepository: templateRepository
        )
        
        let originalCV = CVTestDataBuilder.minimalCV().withName("").build()
        _ = try await cvRepository.saveCV(originalCV)
        
        let duplicatedCV = try await useCase.duplicateCV(id: originalCV.id)
        
        #expect(duplicatedCV.name == " (Copy)")
    }
    
    @Test("DuplicateCV throws error for non-existent CV")
    func duplicateCVThrowsErrorForNonExistentCV() async throws {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage)
        let templateRepository = TemplateRepository(storageService: mockStorage)
        
        let useCase = CVManagementUseCase(
            cvRepository: cvRepository,
            templateRepository: templateRepository
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
        let templateRepository = TemplateRepository(storageService: mockStorage)
        
        let useCase = CVManagementUseCase(
            cvRepository: cvRepository,
            templateRepository: templateRepository
        )
        
        let originalCV = CVTestDataBuilder.completeCV().build()
        _ = try await cvRepository.saveCV(originalCV)
        
        let duplicatedCV = try await useCase.duplicateCV(id: originalCV.id)
        
        // Verify all fields except name and ID are identical
        #expect(duplicatedCV.title == originalCV.title)
        #expect(duplicatedCV.location == originalCV.location)
        #expect(duplicatedCV.email == originalCV.email)
        #expect(duplicatedCV.phone == originalCV.phone)
        #expect(duplicatedCV.portfolio == originalCV.portfolio)
        #expect(duplicatedCV.profile == originalCV.profile)
        
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
        let templateRepository = TemplateRepository(storageService: mockStorage)
        
        let useCase = CVManagementUseCase(
            cvRepository: cvRepository,
            templateRepository: templateRepository
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
        let updatedFirstCV = CVModel(
            id: firstCV.id,
            name: "Updated First CV",
            title: firstCV.title,
            location: firstCV.location,
            email: firstCV.email,
            phone: firstCV.phone,
            portfolio: firstCV.portfolio,
            profile: firstCV.profile,
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
        
        // 5. Duplicate second CV
        let duplicatedCV = try await useCase.duplicateCV(id: secondCV.id)
        
        allCVs = try await useCase.getAllCVs()
        #expect(allCVs.count == 3)
        #expect(duplicatedCV.name == "Second CV (Copy)")
        
        // 6. Delete original second CV
        try await useCase.deleteCV(id: secondCV.id)
        
        allCVs = try await useCase.getAllCVs()
        #expect(allCVs.count == 2)
        
        let remainingNames = allCVs.map { $0.name }.sorted()
        #expect(remainingNames == ["Second CV (Copy)", "Updated First CV"])
        
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
        let templateRepository = TemplateRepository(storageService: mockStorage)
        
        let useCase = CVManagementUseCase(
            cvRepository: cvRepository,
            templateRepository: templateRepository
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
        let templateRepository = TemplateRepository(storageService: mockStorage)
        
        let useCase = CVManagementUseCase(
            cvRepository: cvRepository,
            templateRepository: templateRepository
        )
        
        // Test error propagation for duplicate operation on non-existent CV
        let nonExistentId = UUID()
        
        await #expect(throws: AppError.self) {
            _ = try await useCase.duplicateCV(id: nonExistentId)
        }
    }
}