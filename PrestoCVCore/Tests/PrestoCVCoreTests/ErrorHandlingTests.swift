import Testing
import Foundation
@testable import PrestoCVCore

@Suite("Error Handling Tests")
struct ErrorHandlingTests {
    
    // MARK: - AppError Tests
    
    @Test("AppError provides correct error descriptions")
    func appErrorDescriptions() {
        let templateError = AppError.templateNotFound
        #expect(templateError.errorDescription == "CV template not found")
        
        let invalidDataError = AppError.invalidCVData
        #expect(invalidDataError.errorDescription == "Invalid CV data format")
        
        let storageError = AppError.storageError("Database connection failed")
        #expect(storageError.errorDescription == "Storage error: Database connection failed")
        
        let fileSystemError = AppError.fileSystemError(
            NSError(domain: "TestDomain", code: 404, userInfo: [NSLocalizedDescriptionKey: "File not found"])
        )
        #expect(fileSystemError.errorDescription?.contains("File not found") == true)
        #expect(fileSystemError.errorDescription?.contains("File system error:") == true)
    }
    
    @Test("AppError equality works correctly")
    func appErrorEquality() {
        // Same error types should be equal
        #expect(AppError.templateNotFound == AppError.templateNotFound)
        #expect(AppError.invalidCVData == AppError.invalidCVData)
        
        // Different error types should not be equal
        #expect(AppError.templateNotFound != AppError.invalidCVData)
        
        // Storage errors with same message should be equal
        #expect(AppError.storageError("test") == AppError.storageError("test"))
        #expect(AppError.storageError("test1") != AppError.storageError("test2"))
        
        // File system errors with same description should be equal
        let error1 = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Same message"])
        let error2 = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Same message"])
        let error3 = NSError(domain: "test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Different message"])
        
        #expect(AppError.fileSystemError(error1) == AppError.fileSystemError(error2))
        #expect(AppError.fileSystemError(error1) != AppError.fileSystemError(error3))
    }
    
    @Test("AppError integrates with OnboardingState")
    func appErrorOnboardingStateIntegration() {
        let templateError = AppError.templateNotFound
        let storageError = AppError.storageError("Connection failed")
        
        let errorState1 = OnboardingState.error(templateError)
        let errorState2 = OnboardingState.error(templateError)
        let errorState3 = OnboardingState.error(storageError)
        
        #expect(errorState1 == errorState2)
        #expect(errorState1 != errorState3)
        #expect(errorState1 != .loading)
        #expect(errorState1 != .firstTime)
        #expect(errorState1 != .returning)
    }
    
    // MARK: - DependencyError Tests
    
    @Test("DependencyError provides meaningful error descriptions")
    func dependencyErrorDescriptions() {
        let underlyingError = NSError(domain: "TestDomain", code: 500, userInfo: [NSLocalizedDescriptionKey: "Service unavailable"])
        let dependencyError = DependencyError.serviceCreationFailed("StorageService", underlyingError)
        
        let description = dependencyError.errorDescription
        #expect(description?.contains("Failed to create StorageService") == true)
        #expect(description?.contains("Service unavailable") == true)
    }
    
    @Test("DependencyContainer error handling")
    func dependencyContainerErrorHandling() throws {
        let container = DependencyContainer()
        
        // In normal operation, these should not throw with the default implementation
        // This test verifies the error handling pattern is in place
        let onboardingUseCase = try container.makeOnboardingUseCase()
        let cvManagementUseCase = try container.makeCVManagementUseCase()
        
        #expect(type(of: onboardingUseCase) == OnboardingUseCase.self)
        #expect(type(of: cvManagementUseCase) == CVManagementUseCase.self)
    }
    
    // MARK: - Use Case Error Propagation Tests
    
    @Test("CVManagementUseCase propagates duplicate CV errors")
    func cvManagementUseCaseDuplicateErrors() async throws {
        await TestHelpers.withCVManagementUseCase { useCase in
            let nonExistentId = UUID()
            
            await #expect(throws: AppError.self) {
                _ = try await useCase.duplicateCV(id: nonExistentId)
            }
            
            // Specifically test for invalidCVData error
            do {
                _ = try await useCase.duplicateCV(id: nonExistentId)
                #expect(Bool(false), "Should have thrown an error")
            } catch {
                #expect(error is AppError)
                if let appError = error as? AppError {
                    #expect(appError == AppError.invalidCVData)
                }
            }
        }
    }
    
    @Test("Error handling doesn't corrupt system state")
    func errorHandlingDoesNotCorruptSystemState() async throws {
        try await TestHelpers.withUseCases { onboardingUseCase, cvManagementUseCase in
            
            // 1. Establish known good state
            let template = CVTestDataBuilder.minimalCV().withName("Good CV").build()
            let goodCV = try await onboardingUseCase.createFirstCV(from: template)
            
            let initialCVs = try await cvManagementUseCase.getAllCVs()
            #expect(initialCVs.count == 1)
            
            let initialState = await onboardingUseCase.checkOnboardingRequired()
            #expect(initialState == .returning)
            
            // 2. Attempt operation that should fail
            let nonExistentId = UUID()
            
            await #expect(throws: AppError.self) {
                _ = try await cvManagementUseCase.duplicateCV(id: nonExistentId)
            }
            
            // 3. Verify system state is unchanged after error
            let postErrorCVs = try await cvManagementUseCase.getAllCVs()
            #expect(postErrorCVs.count == 1)
            #expect(postErrorCVs.first?.id == goodCV.id)
            
            let postErrorState = await onboardingUseCase.checkOnboardingRequired()
            #expect(postErrorState == .returning)
            
            // 4. Verify system can continue normal operations after error
            let duplicatedCV = try await cvManagementUseCase.duplicateCV(id: goodCV.id)
            #expect(duplicatedCV.name == "Good CV (Copy)")
            
            let finalCVs = try await cvManagementUseCase.getAllCVs()
            #expect(finalCVs.count == 2)
        }
    }
    
    // MARK: - Storage Error Handling Tests
    
    @Test("FileStorageService handles file system errors gracefully")
    func fileStorageServiceFileSystemErrors() async throws {
        // Test with invalid directory path
        let invalidPath = URL(fileURLWithPath: "/invalid/path/that/cannot/exist")
        
        #expect(throws: Error.self) {
            _ = try FileStorageService(baseDirectory: invalidPath)
        }
    }
    
    @Test("FileStorageService handles corrupted data gracefully")
    func fileStorageServiceCorruptedDataHandling() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_error_handling_\(UUID().uuidString)")
        let service = try FileStorageService(baseDirectory: tempDir)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        // Write corrupted JSON data directly
        let corruptedFileURL = tempDir.appendingPathComponent("corrupted.json")
        try "{ invalid json structure".data(using: .utf8)?.write(to: corruptedFileURL)
        
        // loadAll should skip corrupted files and continue
        let cvs = try await service.loadAll(CVModel.self)
        #expect(cvs.isEmpty) // Should return empty array, not crash
        
        // load should throw for corrupted specific file
        await #expect(throws: DecodingError.self) {
            _ = try await service.load(CVModel.self, from: "corrupted")
        }
    }
    
    @Test("Repository error handling with storage failures")
    func repositoryErrorHandlingWithStorageFailures() async {
        let mockStorage = MockStorageService()
        let repository = CVRepository(storageService: mockStorage)
        
        // Test cvExists error handling
        let exists = await repository.cvExists()
        #expect(exists == false) // Should handle errors gracefully and return false
        
        // Test getCVsCount error handling
        let count = await repository.getCVsCount()
        #expect(count == 0) // Should handle errors gracefully and return 0
    }
    
    // MARK: - Concurrent Error Handling Tests
    
    @Test("Operations handle errors independently")
    func operationsHandleErrorsIndependently() async throws {
        try await TestHelpers.withUseCases { onboardingUseCase, cvManagementUseCase in
            
            // Setup: Create a valid CV
            let template = CVTestDataBuilder.minimalCV().build()
            let validCV = try await onboardingUseCase.createFirstCV(from: template)
            
            // Test valid operation
            let nonExistentId = UUID()
            let validResult = try await cvManagementUseCase.duplicateCV(id: validCV.id)
            #expect(validResult.id != validCV.id)
            #expect(validResult.name == "\(validCV.name) (Copy)")
            
            // Test invalid operation should fail
            do {
                _ = try await cvManagementUseCase.duplicateCV(id: nonExistentId)
                #expect(Bool(false), "Should have thrown an error")
            } catch {
                #expect(error is AppError)
            }
            
            // System should be in consistent state
            let finalCVs = try await cvManagementUseCase.getAllCVs()
            #expect(finalCVs.count == 2) // Original + valid duplicate only
        }
    }
    
    // MARK: - Error Recovery Tests
    
    @Test("System recovers correctly after errors")
    func systemRecoveryAfterErrors() async throws {
        try await TestHelpers.withUseCases { onboardingUseCase, cvManagementUseCase in
            
            // 1. Normal operation
            let template = CVTestDataBuilder.minimalCV().withName("Recovery Test").build()
            let cv = try await onboardingUseCase.createFirstCV(from: template)
            
            // 2. Error scenario
            await #expect(throws: AppError.self) {
                _ = try await cvManagementUseCase.duplicateCV(id: UUID())
            }
            
            // 3. Recovery - normal operations should work
            let updatedCV = CVModel(
                id: cv.id,
                name: "Recovered CV",
                title: cv.title,
                location: cv.location,
                email: cv.email,
                phone: cv.phone,
                portfolio: cv.portfolio,
                profile: cv.profile,
                relevant_experience: cv.relevant_experience,
                education: cv.education,
                skills: cv.skills,
                languages: cv.languages,
                certifications: cv.certifications,
                interests: cv.interests,
                social: cv.social
            )
            
            let result = try await cvManagementUseCase.updateCV(updatedCV)
            #expect(result.name == "Recovered CV")
            
            let duplicated = try await cvManagementUseCase.duplicateCV(id: cv.id)
            #expect(duplicated.name == "Recovered CV (Copy)")
            
            let state = await onboardingUseCase.checkOnboardingRequired()
            #expect(state == .returning)
        }
    }
    
    // MARK: - Edge Case Error Handling
    
    @Test("Error handling for edge case scenarios")
    func errorHandlingForEdgeCases() async throws {
        try await TestHelpers.withUseCases { onboardingUseCase, cvManagementUseCase in
            
            // Test with extreme data
            let extremeTemplate = CVTestDataBuilder()
                .withName(String(repeating: "A", count: 10000)) // Very long name
                .withEmail("a@b.c") // Minimal email
                .withSkills(Array(repeating: Skill(name: "Test", level: 1), count: 1000)) // Many skills
                .build()
            
            // Should handle extreme data without crashing
            let extremeCV = try await onboardingUseCase.createFirstCV(from: extremeTemplate)
            #expect(extremeCV.name.count == 10000)
            #expect(extremeCV.skills.count == 1000)
            
            // Duplicate should also handle extreme data
            let duplicatedExtreme = try await cvManagementUseCase.duplicateCV(id: extremeCV.id)
            #expect(duplicatedExtreme.name.hasSuffix(" (Copy)"))
            #expect(duplicatedExtreme.skills.count == 1000)
            
            // System should remain responsive
            let state = await onboardingUseCase.checkOnboardingRequired()
            #expect(state == .returning)
        }
    }
    
    // MARK: - Error Message Consistency Tests
    
    @Test("Error messages are consistent across components")
    func errorMessagesConsistentAcrossComponents() async throws {
        await TestHelpers.withUseCases { onboardingUseCase, cvManagementUseCase in
            
            let nonExistentId = UUID()
            
            // Error from CV management should be consistent
            do {
                _ = try await cvManagementUseCase.duplicateCV(id: nonExistentId)
                #expect(Bool(false), "Should have thrown")
            } catch {
                #expect(error is AppError)
                if let appError = error as? AppError {
                    #expect(appError == AppError.invalidCVData)
                    #expect(appError.errorDescription == "Invalid CV data format")
                }
            }
        }
    }
    
    // MARK: - Resource Cleanup on Errors
    
    @Test("Resources are properly cleaned up on errors")
    func resourcesCleanedUpOnErrors() async throws {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage)
        let templateRepository = TemplateRepository(storageService: mockStorage)
        
        let useCase = CVManagementUseCase(
            cvRepository: cvRepository,
            templateRepository: templateRepository
        )
        
        // Create a CV
        let cv = CVTestDataBuilder.minimalCV().build()
        _ = try await cvRepository.saveCV(cv)
        
        #expect(mockStorage.isEmpty() == false)
        
        // Attempt invalid operation
        await #expect(throws: AppError.self) {
            _ = try await useCase.duplicateCV(id: UUID())
        }
        
        // Storage should still contain original CV (no corruption)
        #expect(mockStorage.isEmpty() == false)
        let allCVs = try await cvRepository.getAllCVs()
        #expect(allCVs.count == 1)
        #expect(allCVs.first?.id == cv.id)
    }
}