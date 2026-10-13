import Testing
import Foundation
@testable import PrestoCVCore

@Suite("CVRepository Tests")
struct CVRepositoryTests {
    
    // MARK: - Initialization Tests
    
    @Test("CVRepository initializes with storage service")
    func repositoryInitialization() {
        let mockStorage = MockStorageService()
        let repository = CVRepository(storageService: mockStorage)
        
        #expect(type(of: repository) == CVRepository.self)
    }
    
    // MARK: - GetAllCVs Tests
    
    @Test("GetAllCVs returns empty array when no CVs exist")
    func getAllCVsEmptyStorage() async throws {
        let mockStorage = MockStorageService()
        let repository = CVRepository(storageService: mockStorage)
        
        let cvs = try await repository.getAllCVs()
        #expect(cvs.isEmpty)
    }
    
    @Test("GetAllCVs returns all stored CVs")
    func getAllCVsWithStoredData() async throws {
        let mockStorage = MockStorageService()
        let repository = CVRepository(storageService: mockStorage)
        
        let cv1 = CVTestDataBuilder.minimalCV().withName("CV 1").build()
        let cv2 = CVTestDataBuilder.minimalCV().withName("CV 2").build()
        
        // Store CVs directly in mock storage
        try await mockStorage.save(cv1, to: "cv_\(cv1.id.uuidString)")
        try await mockStorage.save(cv2, to: "cv_\(cv2.id.uuidString)")
        
        let cvs = try await repository.getAllCVs()
        
        #expect(cvs.count == 2)
        let names = cvs.map { $0.name }.sorted()
        #expect(names == ["CV 1", "CV 2"])
    }
    
    @Test("GetAllCVs propagates storage errors")
    func getAllCVsPropagatesStorageErrors() async {
        let mockStorage = MockStorageService()
        mockStorage.listingError = AppError.fileSystemError("disk")
        let repository = CVRepository(storageService: mockStorage)
        
        await #expect(throws: AppError.fileSystemError("disk")) {
            _ = try await repository.getAllCVs()
        }
    }
    
    @Test("GetCVListing returns the CVs and the number of files that could not be opened")
    func getCVListingReportsUnreadableFiles() async throws {
        let mockStorage = MockStorageService()
        mockStorage.unreadableCount = 3
        let repository = CVRepository(storageService: mockStorage)
        let cv = CVTestDataBuilder.minimalCV().build()
        _ = try await repository.saveCV(cv)
        
        let listing = try await repository.getCVListing()
        
        #expect(listing == CVListing(cvs: [cv], unreadableCount: 3))
    }
    
    @Test("CVExists is true when the only stored files are ones that could not be opened")
    func cvExistsIsTrueForUnreadableFilesOnly() async throws {
        let mockStorage = MockStorageService()
        mockStorage.unreadableCount = 2
        let repository = CVRepository(storageService: mockStorage)
        
        #expect(try await repository.cvExists() == true)
        #expect(try await repository.getCVsCount() == 0)
    }
    
    @Test("AcknowledgeUnreadableCVs asks the storage to acknowledge the files set aside")
    func acknowledgeUnreadableCVsDelegatesToStorage() async throws {
        let mockStorage = MockStorageService()
        mockStorage.unreadableCount = 2
        let repository = CVRepository(storageService: mockStorage)
        
        try await repository.acknowledgeUnreadableCVs()
        
        #expect(mockStorage.acknowledgeCount == 1)
        #expect(try await repository.getCVListing().unreadableCount == 0)
    }
    
    @Test("GetCVListing propagates storage errors")
    func getCVListingPropagatesStorageErrors() async {
        let mockStorage = MockStorageService()
        mockStorage.listingError = AppError.fileSystemError("disk")
        let repository = CVRepository(storageService: mockStorage)
        
        await #expect(throws: AppError.fileSystemError("disk")) {
            _ = try await repository.getCVListing()
        }
    }
    
    // MARK: - GetCV Tests
    
    @Test("GetCV returns CV when found by ID with standard identifier")
    func getCVByIdStandardIdentifier() async throws {
        let mockStorage = MockStorageService()
        let repository = CVRepository(storageService: mockStorage)
        
        let originalCV = CVTestDataBuilder.completeCV().build()
        let standardIdentifier = "cv_\(originalCV.id.uuidString)"
        
        try await mockStorage.save(originalCV, to: standardIdentifier)
        
        let foundCV = try await repository.getCV(by: originalCV.id)
        
        #expect(foundCV != nil)
        #expect(foundCV?.id == originalCV.id)
        #expect(foundCV?.name == originalCV.name)
    }
    
    @Test("GetCV does not look at files stored under a non-standard identifier")
    func getCVByIdIgnoresNonStandardIdentifier() async throws {
        let mockStorage = MockStorageService()
        let repository = CVRepository(storageService: mockStorage)
        
        let cv = CVTestDataBuilder.completeCV().build()
        try await mockStorage.save(cv, to: "legacy_cv_\(cv.id.uuidString)")
        
        let foundCV = try await repository.getCV(by: cv.id)
        
        #expect(foundCV == nil)
    }
    
    @Test("GetCV returns nil when CV not found")
    func getCVByIdNotFound() async throws {
        let mockStorage = MockStorageService()
        let repository = CVRepository(storageService: mockStorage)
        
        let nonExistentId = UUID()
        let foundCV = try await repository.getCV(by: nonExistentId)
        
        #expect(foundCV == nil)
    }
    
    @Test("GetCV handles multiple CVs and returns correct one")
    func getCVByIdFromMultipleCVs() async throws {
        let mockStorage = MockStorageService()
        let repository = CVRepository(storageService: mockStorage)
        
        let cv1 = CVTestDataBuilder.minimalCV().withName("First CV").build()
        let cv2 = CVTestDataBuilder.minimalCV().withName("Second CV").build()
        let cv3 = CVTestDataBuilder.minimalCV().withName("Third CV").build()
        
        try await mockStorage.save(cv1, to: "cv_\(cv1.id.uuidString)")
        try await mockStorage.save(cv2, to: "cv_\(cv2.id.uuidString)")
        try await mockStorage.save(cv3, to: "cv_\(cv3.id.uuidString)")
        
        let foundCV = try await repository.getCV(by: cv2.id)
        
        #expect(foundCV != nil)
        #expect(foundCV?.name == "Second CV")
        #expect(foundCV?.id == cv2.id)
    }
    
    // MARK: - SaveCV Tests
    
    @Test("SaveCV stores CV with standard identifier format")
    func saveCVUsesStandardIdentifier() async throws {
        let mockStorage = MockStorageService()
        let repository = CVRepository(storageService: mockStorage)
        
        let originalCV = CVTestDataBuilder.minimalCV().build()
        let savedCV = try await repository.saveCV(originalCV)
        
        #expect(savedCV.id == originalCV.id)
        #expect(savedCV.name == originalCV.name)
        
        // Verify it was stored with the correct identifier
        let standardIdentifier = "cv_\(originalCV.id.uuidString)"
        let storedCV = try await mockStorage.load(CVModel.self, from: standardIdentifier)
        #expect(storedCV != nil)
        #expect(storedCV?.id == originalCV.id)
    }
    
    @Test("SaveCV returns the same CV that was saved")
    func saveCVReturnsCorrectCV() async throws {
        let mockStorage = MockStorageService()
        let repository = CVRepository(storageService: mockStorage)
        
        let originalCV = CVTestDataBuilder.completeCV().build()
        let savedCV = try await repository.saveCV(originalCV)
        
        #expect(savedCV.id == originalCV.id)
        #expect(savedCV.name == originalCV.name)
        #expect(savedCV.personalInfo.email == originalCV.personalInfo.email)
        #expect(savedCV.skills.count == originalCV.skills.count)
    }
    
    @Test("SaveCV overwrites existing CV")
    func saveCVOverwritesExisting() async throws {
        let mockStorage = MockStorageService()
        let repository = CVRepository(storageService: mockStorage)
        
        let cvId = UUID()
        let originalCV = CVTestDataBuilder.minimalCV().withName("Original Name").build(id: cvId)
        let updatedCV = CVTestDataBuilder.minimalCV().withName("Updated Name").build(id: cvId)
        
        _ = try await repository.saveCV(originalCV)
        _ = try await repository.saveCV(updatedCV)
        
        let retrievedCV = try await repository.getCV(by: cvId)
        #expect(retrievedCV?.name == "Updated Name")
    }
    
    // MARK: - Timestamp Tests
    
    @Test("SaveCV stamps the creation and update time in whole seconds")
    func saveCVStampsTimesInWholeSeconds() async throws {
        let mockStorage = MockStorageService()
        let clock = ManualClock(Date(timeIntervalSince1970: 1_700_000_000.75))
        let repository = CVRepository(storageService: mockStorage, now: { clock.now() })
        let cv = CVTestDataBuilder.minimalCV().build()
        
        _ = try await repository.saveCV(cv)
        
        let stored = try await mockStorage.load(StoredCV.self, from: "cv_\(cv.id.uuidString)")
        #expect(stored?.createdAt == Date(timeIntervalSince1970: 1_700_000_000))
        #expect(stored?.updatedAt == Date(timeIntervalSince1970: 1_700_000_000))
    }
    
    @Test("SaveCV keeps the creation time and refreshes the update time")
    func saveCVKeepsCreationTime() async throws {
        let mockStorage = MockStorageService()
        let clock = ManualClock()
        let repository = CVRepository(storageService: mockStorage, now: { clock.now() })
        let cv = CVTestDataBuilder.minimalCV().build()
        let created = clock.now()
        
        _ = try await repository.saveCV(cv)
        clock.advance(by: 90)
        _ = try await repository.saveCV(cv)
        
        let stored = try await mockStorage.load(StoredCV.self, from: "cv_\(cv.id.uuidString)")
        #expect(stored?.createdAt == created)
        #expect(stored?.updatedAt == created.addingTimeInterval(90))
    }
    
    // MARK: - Order Tests
    
    @Test("GetAllCVs lists the most recently saved CV first")
    func getAllCVsListsMostRecentFirst() async throws {
        let mockStorage = MockStorageService()
        let clock = ManualClock()
        let repository = CVRepository(storageService: mockStorage, now: { clock.now() })
        
        let first = CVTestDataBuilder.minimalCV().withName("A first").build()
        let second = CVTestDataBuilder.minimalCV().withName("B second").build()
        let third = CVTestDataBuilder.minimalCV().withName("C third").build()
        for cv in [first, second, third] {
            _ = try await repository.saveCV(cv)
            clock.advance(by: 1)
        }
        clock.advance(by: 1)
        _ = try await repository.saveCV(first)
        
        let names = try await repository.getAllCVs().map(\.name)
        
        #expect(names == ["A first", "C third", "B second"])
    }
    
    @Test("GetAllCVs breaks ties by name and then by id")
    func getAllCVsBreaksTiesByNameThenId() async throws {
        let mockStorage = MockStorageService()
        let clock = ManualClock()
        let repository = CVRepository(storageService: mockStorage, now: { clock.now() })
        
        let lowId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let highId = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let cvs = [
            CVTestDataBuilder.minimalCV().withName("beta").build(),
            CVTestDataBuilder.minimalCV().withName("Same").build(id: highId),
            CVTestDataBuilder.minimalCV().withName("alpha").build(),
            CVTestDataBuilder.minimalCV().withName("Same").build(id: lowId),
        ]
        for cv in cvs {
            _ = try await repository.saveCV(cv)
        }
        
        let listed = try await repository.getAllCVs()
        
        #expect(listed.map(\.name) == ["alpha", "beta", "Same", "Same"])
        #expect(listed.suffix(2).map(\.id) == [lowId, highId])
    }
    
    @Test("GetAllCVs lists CVs without a time after the stamped ones, by name")
    func getAllCVsListsUnstampedCVsLast() async throws {
        let mockStorage = MockStorageService()
        let repository = CVRepository(storageService: mockStorage)
        
        let unstampedB = CVTestDataBuilder.minimalCV().withName("B").build()
        let unstampedA = CVTestDataBuilder.minimalCV().withName("A").build()
        let stamped = CVTestDataBuilder.minimalCV().withName("Z stamped").build()
        // Written without times, as files saved before the times existed
        try await mockStorage.save(unstampedB, to: "cv_\(unstampedB.id.uuidString)")
        try await mockStorage.save(unstampedA, to: "cv_\(unstampedA.id.uuidString)")
        _ = try await repository.saveCV(stamped)
        
        let names = try await repository.getAllCVs().map(\.name)
        
        #expect(names == ["Z stamped", "A", "B"])
    }
    
    // MARK: - DeleteCV Tests
    
    @Test("DeleteCV removes CV from storage")
    func deleteCVRemovesFromStorage() async throws {
        let mockStorage = MockStorageService()
        let repository = CVRepository(storageService: mockStorage)
        
        let cv = CVTestDataBuilder.minimalCV().build()
        _ = try await repository.saveCV(cv)
        
        // Verify CV exists before deletion
        let beforeDelete = try await repository.getCV(by: cv.id)
        #expect(beforeDelete != nil)
        
        try await repository.deleteCV(id: cv.id)
        
        // Verify CV is gone after deletion
        let afterDelete = try await repository.getCV(by: cv.id)
        #expect(afterDelete == nil)
    }
    
    @Test("DeleteCV handles non-existent CV gracefully")
    func deleteCVHandlesNonExistent() async throws {
        let mockStorage = MockStorageService()
        let repository = CVRepository(storageService: mockStorage)
        
        let nonExistentId = UUID()
        
        // Should not throw when deleting non-existent CV
        try await repository.deleteCV(id: nonExistentId)
    }
    
    // MARK: - CVExists Tests
    
    @Test("CVExists returns false when no CVs exist")
    func cvExistsReturnsFalseWhenEmpty() async throws {
        let mockStorage = MockStorageService()
        let repository = CVRepository(storageService: mockStorage)
        
        // Ensure storage is completely empty
        #expect(mockStorage.isEmpty())
        
        // Verify getAllCVs returns empty array first
        do {
            let cvs = try await repository.getAllCVs()
            #expect(cvs.isEmpty)
            #expect(cvs.count == 0)
        } catch {
            #expect(Bool(false), "getAllCVs should not throw with empty storage")
        }
        
        // Now test cvExists which should return false for empty array
        let exists = try await repository.cvExists()
        #expect(exists == false)
    }
    
    @Test("CVExists returns true when CVs exist")
    func cvExistsReturnsTrueWhenCVsExist() async throws {
        let mockStorage = MockStorageService()
        let repository = CVRepository(storageService: mockStorage)
        
        let cv = CVTestDataBuilder.minimalCV().build()
        _ = try await repository.saveCV(cv)
        
        let exists = try await repository.cvExists()
        #expect(exists == true)
    }
    
    @Test("CVExists throws on storage error")
    func cvExistsThrowsOnStorageError() async {
        let mockStorage = MockStorageService()
        mockStorage.listingError = AppError.fileSystemError("disk")
        let repository = CVRepository(storageService: mockStorage)
        
        await #expect(throws: AppError.fileSystemError("disk")) {
            _ = try await repository.cvExists()
        }
    }
    
    // MARK: - GetCVsCount Tests
    
    @Test("GetCVsCount returns zero when no CVs exist")
    func getCVsCountReturnsZeroWhenEmpty() async throws {
        let mockStorage = MockStorageService()
        let repository = CVRepository(storageService: mockStorage)
        
        // Ensure storage is completely empty
        #expect(mockStorage.isEmpty())
        
        // Verify getAllCVs returns empty array first
        do {
            let cvs = try await repository.getAllCVs()
            #expect(cvs.isEmpty)
            #expect(cvs.count == 0)
        } catch {
            #expect(Bool(false), "getAllCVs should not throw with empty storage")
        }
        
        // Now test getCVsCount which should return 0
        let count = try await repository.getCVsCount()
        #expect(count == 0)
    }
    
    @Test("GetCVsCount returns correct count when CVs exist")
    func getCVsCountReturnsCorrectCount() async throws {
        let mockStorage = MockStorageService()
        let repository = CVRepository(storageService: mockStorage)
        
        let cv1 = CVTestDataBuilder.minimalCV().withName("CV 1").build()
        let cv2 = CVTestDataBuilder.minimalCV().withName("CV 2").build()
        let cv3 = CVTestDataBuilder.minimalCV().withName("CV 3").build()
        
        _ = try await repository.saveCV(cv1)
        _ = try await repository.saveCV(cv2)
        _ = try await repository.saveCV(cv3)
        
        let count = try await repository.getCVsCount()
        #expect(count == 3)
    }
    
    @Test("GetCVsCount throws on storage error")
    func getCVsCountThrowsOnStorageError() async {
        let mockStorage = MockStorageService()
        mockStorage.listingError = AppError.fileSystemError("disk")
        let repository = CVRepository(storageService: mockStorage)
        
        await #expect(throws: AppError.fileSystemError("disk")) {
            _ = try await repository.getCVsCount()
        }
    }
    
    // MARK: - Integration Tests
    
    @Test("Repository operations work together correctly")
    func repositoryOperationsIntegration() async throws {
        let mockStorage = MockStorageService()
        let repository = CVRepository(storageService: mockStorage)
        
        // Initially empty
        #expect(try await repository.getCVsCount() == 0)
        #expect(try await repository.cvExists() == false)
        
        // Add first CV
        let cv1 = CVTestDataBuilder.minimalCV().withName("First CV").build()
        _ = try await repository.saveCV(cv1)
        
        #expect(try await repository.getCVsCount() == 1)
        #expect(try await repository.cvExists() == true)
        
        // Add second CV
        let cv2 = CVTestDataBuilder.minimalCV().withName("Second CV").build()
        _ = try await repository.saveCV(cv2)
        
        #expect(try await repository.getCVsCount() == 2)
        
        // Get specific CV
        let foundCV1 = try await repository.getCV(by: cv1.id)
        #expect(foundCV1?.name == "First CV")
        
        // Get all CVs
        let allCVs = try await repository.getAllCVs()
        #expect(allCVs.count == 2)
        
        // Delete one CV
        try await repository.deleteCV(id: cv1.id)
        
        #expect(try await repository.getCVsCount() == 1)
        #expect(try await repository.cvExists() == true)
        
        // Verify deleted CV is gone
        let deletedCV = try await repository.getCV(by: cv1.id)
        #expect(deletedCV == nil)
        
        // Verify remaining CV still exists
        let remainingCV = try await repository.getCV(by: cv2.id)
        #expect(remainingCV?.name == "Second CV")
        
        // Delete last CV
        try await repository.deleteCV(id: cv2.id)
        
        #expect(try await repository.getCVsCount() == 0)
        #expect(try await repository.cvExists() == false)
    }
    
    // MARK: - Edge Cases
    
    @Test("Repository handles CV with complex nested data")
    func repositoryHandlesComplexCVData() async throws {
        let mockStorage = MockStorageService()
        let repository = CVRepository(storageService: mockStorage)
        
        let complexCV = CVTestDataBuilder.completeCV().build()
        _ = try await repository.saveCV(complexCV)
        
        let retrievedCV = try await repository.getCV(by: complexCV.id)
        
        #expect(retrievedCV != nil)
        #expect(retrievedCV?.skills.count == complexCV.skills.count)
        #expect(retrievedCV?.relevant_experience.count == complexCV.relevant_experience.count)
        #expect(retrievedCV?.education.count == complexCV.education.count)
        #expect(retrievedCV?.languages.count == complexCV.languages.count)
        #expect(retrievedCV?.certifications.count == complexCV.certifications.count)
        #expect(retrievedCV?.interests.count == complexCV.interests.count)
        #expect(retrievedCV?.social.count == complexCV.social.count)
    }
    
    @Test("Repository handles UUID edge cases correctly")
    func repositoryHandlesUUIDEdgeCases() async throws {
        let mockStorage = MockStorageService()
        let repository = CVRepository(storageService: mockStorage)
        
        // Test with known UUID patterns
        let knownUUID = UUID(uuidString: "12345678-1234-1234-1234-123456789ABC")!
        let cv = CVTestDataBuilder.minimalCV().build(id: knownUUID)
        
        _ = try await repository.saveCV(cv)
        
        let retrievedCV = try await repository.getCV(by: knownUUID)
        #expect(retrievedCV != nil)
        #expect(retrievedCV?.id == knownUUID)
    }
}