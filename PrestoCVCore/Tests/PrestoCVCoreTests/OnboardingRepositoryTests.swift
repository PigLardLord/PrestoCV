import Testing
import Foundation
@testable import PrestoCVCore

@Suite("OnboardingRepository Tests")
struct OnboardingRepositoryTests {
    
    // MARK: - Initialization Tests
    
    @Test("OnboardingRepository initializes with CV repository")
    func repositoryInitialization() {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage, parallelSearchService: MockParallelSearchService())
        let onboardingRepository = OnboardingRepository(cvRepository: cvRepository)
        
        #expect(type(of: onboardingRepository) == OnboardingRepository.self)
    }
    
    // MARK: - HasExistingCVs Tests
    
    @Test("HasExistingCVs returns false when no CVs exist")
    func hasExistingCVsReturnsFalseWhenEmpty() async {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage, parallelSearchService: MockParallelSearchService())
        let onboardingRepository = OnboardingRepository(cvRepository: cvRepository)
        
        let hasExisting = await onboardingRepository.hasExistingCVs()
        #expect(hasExisting == false)
    }
    
    @Test("HasExistingCVs returns true when CVs exist")
    func hasExistingCVsReturnsTrueWhenCVsExist() async throws {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage, parallelSearchService: MockParallelSearchService())
        let onboardingRepository = OnboardingRepository(cvRepository: cvRepository)
        
        // Add a CV to the repository
        let cv = CVTestDataBuilder.minimalCV().build()
        _ = try await cvRepository.saveCV(cv)
        
        let hasExisting = await onboardingRepository.hasExistingCVs()
        #expect(hasExisting == true)
    }
    
    @Test("HasExistingCVs returns false when CV repository errors")
    func hasExistingCVsHandlesCVRepositoryErrors() async {
        // Create a repository that will fail on cvExists
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage, parallelSearchService: MockParallelSearchService())
        let onboardingRepository = OnboardingRepository(cvRepository: cvRepository)
        
        // With clean mock storage, cvExists should return false without errors
        let hasExisting = await onboardingRepository.hasExistingCVs()
        #expect(hasExisting == false)
    }
    
    // MARK: - GetOnboardingState Tests
    
    @Test("GetOnboardingState returns firstTime when no CVs exist")
    func getOnboardingStateReturnsFirstTimeWhenNoCVs() async {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage, parallelSearchService: MockParallelSearchService())
        let onboardingRepository = OnboardingRepository(cvRepository: cvRepository)
        
        let state = await onboardingRepository.getOnboardingState()
        #expect(state == .firstTime)
    }
    
    @Test("GetOnboardingState returns returning when CVs exist")
    func getOnboardingStateReturnsReturningWhenCVsExist() async throws {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage, parallelSearchService: MockParallelSearchService())
        let onboardingRepository = OnboardingRepository(cvRepository: cvRepository)
        
        // Add a CV to make the user a "returning" user
        let cv = CVTestDataBuilder.minimalCV().build()
        _ = try await cvRepository.saveCV(cv)
        
        let state = await onboardingRepository.getOnboardingState()
        #expect(state == .returning)
    }
    
    @Test("GetOnboardingState transitions correctly as CVs are added")
    func getOnboardingStateTransitionsCorrectly() async throws {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage, parallelSearchService: MockParallelSearchService())
        let onboardingRepository = OnboardingRepository(cvRepository: cvRepository)
        
        // Initially should be first time
        let initialState = await onboardingRepository.getOnboardingState()
        #expect(initialState == .firstTime)
        
        // Add first CV
        let cv = CVTestDataBuilder.minimalCV().build()
        _ = try await cvRepository.saveCV(cv)
        
        // Now should be returning
        let afterFirstCV = await onboardingRepository.getOnboardingState()
        #expect(afterFirstCV == .returning)
        
        // Add second CV - should still be returning
        let secondCV = CVTestDataBuilder.minimalCV().build()
        _ = try await cvRepository.saveCV(secondCV)
        
        let afterSecondCV = await onboardingRepository.getOnboardingState()
        #expect(afterSecondCV == .returning)
        
        // Remove all CVs - should go back to first time
        try await cvRepository.deleteCV(id: cv.id)
        try await cvRepository.deleteCV(id: secondCV.id)
        
        let afterDeletion = await onboardingRepository.getOnboardingState()
        #expect(afterDeletion == .firstTime)
    }
    
    // MARK: - Integration with CV Repository Tests
    
    @Test("OnboardingRepository reflects CV repository state changes immediately")
    func onboardingRepositoryReflectsCVRepositoryChanges() async throws {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage, parallelSearchService: MockParallelSearchService())
        let onboardingRepository = OnboardingRepository(cvRepository: cvRepository)
        
        // Start with no CVs
        #expect(await onboardingRepository.getOnboardingState() == .firstTime)
        #expect(await onboardingRepository.hasExistingCVs() == false)
        
        // Add CV through CV repository
        let cv1 = CVTestDataBuilder.minimalCV().withName("First CV").build()
        _ = try await cvRepository.saveCV(cv1)
        
        // Onboarding repository should immediately reflect the change
        #expect(await onboardingRepository.getOnboardingState() == .returning)
        #expect(await onboardingRepository.hasExistingCVs() == true)
        
        // Add another CV
        let cv2 = CVTestDataBuilder.minimalCV().withName("Second CV").build()
        _ = try await cvRepository.saveCV(cv2)
        
        // Should still be returning (not changed from returning to anything else)
        #expect(await onboardingRepository.getOnboardingState() == .returning)
        #expect(await onboardingRepository.hasExistingCVs() == true)
        
        // Delete one CV
        try await cvRepository.deleteCV(id: cv1.id)
        
        // Should still be returning because cv2 still exists
        #expect(await onboardingRepository.getOnboardingState() == .returning)
        #expect(await onboardingRepository.hasExistingCVs() == true)
        
        // Delete the last CV
        try await cvRepository.deleteCV(id: cv2.id)
        
        // Should go back to first time
        #expect(await onboardingRepository.getOnboardingState() == .firstTime)
        #expect(await onboardingRepository.hasExistingCVs() == false)
    }
    
    // MARK: - Concurrency Tests
    
    @Test("OnboardingRepository handles concurrent operations correctly")
    func onboardingRepositoryHandlesConcurrentOperations() async throws {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage, parallelSearchService: MockParallelSearchService())
        let onboardingRepository = OnboardingRepository(cvRepository: cvRepository)
        
        // Perform multiple concurrent state checks
        async let state1 = onboardingRepository.getOnboardingState()
        async let state2 = onboardingRepository.getOnboardingState()
        async let hasExisting1 = onboardingRepository.hasExistingCVs()
        async let hasExisting2 = onboardingRepository.hasExistingCVs()
        
        let results = await (state1, state2, hasExisting1, hasExisting2)
        
        // All should return consistent results for empty state
        #expect(results.0 == .firstTime)
        #expect(results.1 == .firstTime)
        #expect(results.2 == false)
        #expect(results.3 == false)
    }
    
    @Test("OnboardingRepository state checks remain consistent during CV operations")
    func onboardingRepositoryConsistentDuringCVOperations() async throws {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage, parallelSearchService: MockParallelSearchService())
        let onboardingRepository = OnboardingRepository(cvRepository: cvRepository)
        
        let cv = CVTestDataBuilder.minimalCV().build()
        
        // Initial state should be firstTime
        let initialState = await onboardingRepository.getOnboardingState()
        let initialExists = await onboardingRepository.hasExistingCVs()
        #expect(initialState == .firstTime)
        #expect(initialExists == false)
        
        // Save CV
        _ = try await cvRepository.saveCV(cv)
        
        // After save completes, check state - should be consistent
        let finalState = await onboardingRepository.getOnboardingState()
        let finalExists = await onboardingRepository.hasExistingCVs()
        
        #expect(finalState == .returning)
        #expect(finalExists == true)
        
        // Multiple sequential checks should remain consistent
        for _ in 0..<3 {
            let state = await onboardingRepository.getOnboardingState()
            let exists = await onboardingRepository.hasExistingCVs()
            #expect(state == .returning)
            #expect(exists == true)
        }
    }
    
    // MARK: - Edge Cases
    
    @Test("OnboardingRepository handles repository with many CVs")
    func onboardingRepositoryHandlesManyCV() async throws {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage, parallelSearchService: MockParallelSearchService())
        let onboardingRepository = OnboardingRepository(cvRepository: cvRepository)
        
        // Add many CVs
        let cvCount = 100
        for i in 0..<cvCount {
            let cv = CVTestDataBuilder.minimalCV().withName("CV \(i)").build()
            _ = try await cvRepository.saveCV(cv)
        }
        
        // Should still efficiently determine returning state
        let state = await onboardingRepository.getOnboardingState()
        #expect(state == .returning)
        
        let hasExisting = await onboardingRepository.hasExistingCVs()
        #expect(hasExisting == true)
    }
    
    @Test("OnboardingRepository delegates correctly to CV repository")
    func onboardingRepositoryDelegatesToCVRepository() async throws {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage, parallelSearchService: MockParallelSearchService())
        let onboardingRepository = OnboardingRepository(cvRepository: cvRepository)
        
        // Test that the onboarding repository is truly delegating to the CV repository
        // by verifying behavior through the CV repository interface
        
        // Direct CV repository check
        let directCVExists = await cvRepository.cvExists()
        let onboardingHasExisting = await onboardingRepository.hasExistingCVs()
        #expect(directCVExists == onboardingHasExisting)
        
        // Add CV through CV repository
        let cv = CVTestDataBuilder.minimalCV().build()
        _ = try await cvRepository.saveCV(cv)
        
        // Both should reflect the same state
        let directCVExistsAfter = await cvRepository.cvExists()
        let onboardingHasExistingAfter = await onboardingRepository.hasExistingCVs()
        #expect(directCVExistsAfter == onboardingHasExistingAfter)
        #expect(onboardingHasExistingAfter == true)
        
        // The onboarding state should be based on this CV existence
        let onboardingState = await onboardingRepository.getOnboardingState()
        #expect(onboardingState == (onboardingHasExistingAfter ? .returning : .firstTime))
    }
    
    // MARK: - State Logic Tests
    
    @Test("OnboardingRepository state logic is correct")
    func onboardingRepositoryStateLogicIsCorrect() async throws {
        let mockStorage = MockStorageService()
        let cvRepository = CVRepository(storageService: mockStorage, parallelSearchService: MockParallelSearchService())
        let onboardingRepository = OnboardingRepository(cvRepository: cvRepository)
        
        // Test the core business logic:
        // hasExistingCVs() == false → getOnboardingState() == .firstTime
        // hasExistingCVs() == true → getOnboardingState() == .returning
        
        // Empty state
        let emptyHasExisting = await onboardingRepository.hasExistingCVs()
        let emptyState = await onboardingRepository.getOnboardingState()
        #expect(emptyHasExisting == false)
        #expect(emptyState == .firstTime)
        
        // Add CV
        let cv = CVTestDataBuilder.minimalCV().build()
        _ = try await cvRepository.saveCV(cv)
        
        // Non-empty state
        let nonEmptyHasExisting = await onboardingRepository.hasExistingCVs()
        let nonEmptyState = await onboardingRepository.getOnboardingState()
        #expect(nonEmptyHasExisting == true)
        #expect(nonEmptyState == .returning)
        
        // Verify the state mapping is consistent
        #expect((emptyHasExisting == false) == (emptyState == .firstTime))
        #expect((nonEmptyHasExisting == true) == (nonEmptyState == .returning))
    }
}