import Testing
import Foundation
@testable import PrestoCVCore

@Suite("FileStorageService Tests")
struct FileStorageServiceTests {
    
    // MARK: - Initialization Tests
    
    @Test("FileStorageService initializes with valid directory")
    func initializationWithValidDirectory() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_storage_\(UUID().uuidString)")
        
        let service = try FileStorageService(baseDirectory: tempDir)
        
        #expect(type(of: service) == FileStorageService.self)
        
        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }
    
    @Test("FileStorageService creates base directory if it doesn't exist")
    func createsBaseDirectoryIfNeeded() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_new_dir_\(UUID().uuidString)")
        
        // Verify directory doesn't exist
        #expect(!FileManager.default.fileExists(atPath: tempDir.path))
        
        _ = try FileStorageService(baseDirectory: tempDir)
        
        // Verify directory was created
        #expect(FileManager.default.fileExists(atPath: tempDir.path))
        
        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }
    
    // MARK: - Save Operation Tests
    
    @Test("Save operation stores object correctly")
    func saveOperation() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_save_\(UUID().uuidString)")
        let service = try FileStorageService(baseDirectory: tempDir)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let cv = CVTestDataBuilder.minimalCV().build()
        try await service.save(cv, to: "test_cv")
        
        let fileURL = tempDir.appendingPathComponent("test_cv.json")
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
        
        // Verify file contains valid JSON
        let data = try Data(contentsOf: fileURL)
        let decodedCV = try JSONDecoder().decode(CVModel.self, from: data)
        #expect(decodedCV.name == cv.name)
    }
    
    @Test("Save operation overwrites existing file")
    func saveOperationOverwrite() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_overwrite_\(UUID().uuidString)")
        let service = try FileStorageService(baseDirectory: tempDir)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let cv1 = CVTestDataBuilder.minimalCV().withName("First CV").build()
        let cv2 = CVTestDataBuilder.minimalCV().withName("Second CV").build()
        
        try await service.save(cv1, to: "overwrite_test")
        try await service.save(cv2, to: "overwrite_test")
        
        let loadedCV = try await service.load(CVModel.self, from: "overwrite_test")
        #expect(loadedCV?.name == "Second CV")
    }
    
    // MARK: - Load Operation Tests
    
    @Test("Load operation retrieves stored object")
    func loadOperation() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_load_\(UUID().uuidString)")
        let service = try FileStorageService(baseDirectory: tempDir)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let originalCV = CVTestDataBuilder.completeCV().build()
        try await service.save(originalCV, to: "load_test")
        
        let loadedCV = try await service.load(CVModel.self, from: "load_test")
        
        #expect(loadedCV != nil)
        #expect(loadedCV?.id == originalCV.id)
        #expect(loadedCV?.name == originalCV.name)
        #expect(loadedCV?.personalInfo.email == originalCV.personalInfo.email)
    }
    
    @Test("Load operation returns nil for non-existent file")
    func loadNonExistentFile() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_load_nil_\(UUID().uuidString)")
        let service = try FileStorageService(baseDirectory: tempDir)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let result = try await service.load(CVModel.self, from: "non_existent")
        #expect(result == nil)
    }
    
    @Test("Load operation handles corrupted JSON gracefully")
    func loadCorruptedJSON() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_corrupted_\(UUID().uuidString)")
        let service = try FileStorageService(baseDirectory: tempDir)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        // Write invalid JSON directly to file
        let fileURL = tempDir.appendingPathComponent("corrupted.json")
        try "invalid json {".data(using: .utf8)?.write(to: fileURL)
        
        await #expect(throws: DecodingError.self) {
            _ = try await service.load(CVModel.self, from: "corrupted")
        }
    }
    
    // MARK: - LoadAll Operation Tests
    
    @Test("LoadAll operation retrieves all stored objects")
    func loadAllOperation() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_load_all_\(UUID().uuidString)")
        let service = try FileStorageService(baseDirectory: tempDir)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let cv1 = CVTestDataBuilder.minimalCV().withName("CV 1").build()
        let cv2 = CVTestDataBuilder.minimalCV().withName("CV 2").build()
        let cv3 = CVTestDataBuilder.minimalCV().withName("CV 3").build()
        
        try await service.save(cv1, to: "cv1")
        try await service.save(cv2, to: "cv2")
        try await service.save(cv3, to: "cv3")
        
        let allCVs = try await service.loadAll(CVModel.self)
        
        #expect(allCVs.count == 3)
        let names = allCVs.map { $0.name }.sorted()
        #expect(names == ["CV 1", "CV 2", "CV 3"])
    }
    
    @Test("LoadAll operation returns empty array when no files exist")
    func loadAllEmptyDirectory() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_empty_\(UUID().uuidString)")
        let service = try FileStorageService(baseDirectory: tempDir)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let result = try await service.loadAll(CVModel.self)
        #expect(result.isEmpty)
    }
    
    @Test("LoadAll operation skips invalid files and continues loading")
    func loadAllSkipsInvalidFiles() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_skip_invalid_\(UUID().uuidString)")
        let service = try FileStorageService(baseDirectory: tempDir)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        // Save one valid CV
        let validCV = CVTestDataBuilder.minimalCV().build()
        try await service.save(validCV, to: "valid")
        
        // Write an invalid JSON file directly
        let invalidFileURL = tempDir.appendingPathComponent("invalid.json")
        try "invalid json".data(using: .utf8)?.write(to: invalidFileURL)
        
        // Write a non-JSON file that should be ignored
        let textFileURL = tempDir.appendingPathComponent("readme.txt")
        try "This is a text file".data(using: .utf8)?.write(to: textFileURL)
        
        let allCVs = try await service.loadAll(CVModel.self)
        
        // Should only return the valid CV, skipping the invalid JSON and ignoring non-JSON files
        #expect(allCVs.count == 1)
        #expect(allCVs.first?.name == validCV.name)
    }
    
    // MARK: - Delete Operation Tests
    
    @Test("Delete operation removes existing file")
    func deleteOperation() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_delete_\(UUID().uuidString)")
        let service = try FileStorageService(baseDirectory: tempDir)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let cv = CVTestDataBuilder.minimalCV().build()
        try await service.save(cv, to: "delete_test")
        
        let fileURL = tempDir.appendingPathComponent("delete_test.json")
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
        
        try await service.delete(identifier: "delete_test")
        
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    }
    
    @Test("Delete operation handles non-existent file gracefully")
    func deleteNonExistentFile() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_delete_none_\(UUID().uuidString)")
        let service = try FileStorageService(baseDirectory: tempDir)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        // Should not throw when deleting non-existent file
        try await service.delete(identifier: "non_existent")
    }
    
    // MARK: - Exists Operation Tests
    
    @Test("Exists operation returns true for existing files")
    func existsReturnsTrueForExistingFile() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_exists_true_\(UUID().uuidString)")
        let service = try FileStorageService(baseDirectory: tempDir)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let cv = CVTestDataBuilder.minimalCV().build()
        try await service.save(cv, to: "exists_test")
        
        let exists = await service.exists(identifier: "exists_test")
        #expect(exists == true)
    }
    
    @Test("Exists operation returns false for non-existent files")
    func existsReturnsFalseForNonExistentFile() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_exists_false_\(UUID().uuidString)")
        let service = try FileStorageService(baseDirectory: tempDir)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let exists = await service.exists(identifier: "non_existent")
        #expect(exists == false)
    }
    
    // MARK: - GetAllIdentifiers Operation Tests
    
    @Test("GetAllIdentifiers returns all stored identifiers")
    func getAllIdentifiersOperation() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_identifiers_\(UUID().uuidString)")
        let service = try FileStorageService(baseDirectory: tempDir)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let cv1 = CVTestDataBuilder.minimalCV().build()
        let cv2 = CVTestDataBuilder.minimalCV().build()
        
        try await service.save(cv1, to: "identifier1")
        try await service.save(cv2, to: "identifier2")
        
        let identifiers = try await service.getAllIdentifiers()
        
        #expect(identifiers.count == 2)
        #expect(identifiers.contains("identifier1"))
        #expect(identifiers.contains("identifier2"))
    }
    
    @Test("GetAllIdentifiers returns empty array for empty directory")
    func getAllIdentifiersEmptyDirectory() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_identifiers_empty_\(UUID().uuidString)")
        let service = try FileStorageService(baseDirectory: tempDir)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let identifiers = try await service.getAllIdentifiers()
        #expect(identifiers.isEmpty)
    }
    
    @Test("GetAllIdentifiers ignores non-JSON files")
    func getAllIdentifiersIgnoresNonJSONFiles() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_identifiers_filter_\(UUID().uuidString)")
        let service = try FileStorageService(baseDirectory: tempDir)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        // Save a valid JSON file
        let cv = CVTestDataBuilder.minimalCV().build()
        try await service.save(cv, to: "valid_cv")
        
        // Create non-JSON files directly
        let textFileURL = tempDir.appendingPathComponent("readme.txt")
        try "Text file".data(using: .utf8)?.write(to: textFileURL)
        
        let xmlFileURL = tempDir.appendingPathComponent("config.xml")
        try "<config></config>".data(using: .utf8)?.write(to: xmlFileURL)
        
        let identifiers = try await service.getAllIdentifiers()
        
        #expect(identifiers.count == 1)
        #expect(identifiers.contains("valid_cv"))
        #expect(!identifiers.contains("readme"))
        #expect(!identifiers.contains("config"))
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Save operation throws error for invalid directory permissions")
    func saveThrowsForInvalidPermissions() async throws {
        // This test simulates permission errors by trying to write to an invalid path
        let invalidDir = URL(fileURLWithPath: "/invalid/path/that/does/not/exist")
        
        #expect(throws: Error.self) {
            _ = try FileStorageService(baseDirectory: invalidDir)
        }
    }
    
    // MARK: - Actor Isolation Tests
    
    @Test("FileStorageService handles concurrent operations correctly")
    func actorHandlesConcurrentOperations() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_concurrent_\(UUID().uuidString)")
        let service = try FileStorageService(baseDirectory: tempDir)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        // Test concurrent save operations
        let cv1 = CVTestDataBuilder.minimalCV().withName("CV 1").build()
        let cv2 = CVTestDataBuilder.minimalCV().withName("CV 2").build()
        let cv3 = CVTestDataBuilder.minimalCV().withName("CV 3").build()
        
        // These operations should be serialized by the actor
        _ = await withTaskGroup(of: Void.self) { group in
            group.addTask { try? await service.save(cv1, to: "cv1") }
            group.addTask { try? await service.save(cv2, to: "cv2") }
            group.addTask { try? await service.save(cv3, to: "cv3") }
        }
        
        // Verify all files were saved
        let exists1 = await service.exists(identifier: "cv1")
        let exists2 = await service.exists(identifier: "cv2") 
        let exists3 = await service.exists(identifier: "cv3")
        
        #expect(exists1 && exists2 && exists3)
        
        // Verify content integrity
        let allCVs = try await service.loadAll(CVModel.self)
        #expect(allCVs.count == 3)
        
        let names = Set(allCVs.map { $0.name })
        #expect(names == Set(["CV 1", "CV 2", "CV 3"]))
    }
    
    @Test("FileStorageService maintains data consistency under concurrent access")
    func actorMaintainsDataConsistency() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_consistency_\(UUID().uuidString)")
        let service = try FileStorageService(baseDirectory: tempDir)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let baseCV = CVTestDataBuilder.minimalCV().withName("Base CV").build()
        try await service.save(baseCV, to: "test_cv")
        
        // Simulate concurrent read/write/delete operations
        let results = await withTaskGroup(of: Bool.self, returning: [Bool].self) { group in
            // Read operations
            group.addTask {
                if let cv = try? await service.load(CVModel.self, from: "test_cv") {
                    return cv.name == "Base CV"
                }
                return false
            }
            
            group.addTask {
                return await service.exists(identifier: "test_cv")
            }
            
            // Update operation
            group.addTask {
                let updatedCV = CVTestDataBuilder.minimalCV().withName("Updated CV").build()
                try? await service.save(updatedCV, to: "test_cv")
                return true
            }
            
            // Another read operation
            group.addTask {
                let identifiers = try? await service.getAllIdentifiers()
                return identifiers?.contains("test_cv") ?? false
            }
            
            var results: [Bool] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
        
        // All operations should have succeeded
        #expect(results.allSatisfy { $0 })
        
        // Final state should be consistent
        let finalCV = try await service.load(CVModel.self, from: "test_cv")
        #expect(finalCV != nil)
    }
    
    // MARK: - JSON Encoding Configuration Tests
    
    @Test("FileStorageService uses ISO8601 date strategy")
    func jsonEncodingUsesISO8601() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_date_encoding_\(UUID().uuidString)")
        let service = try FileStorageService(baseDirectory: tempDir)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        // Create a model with a date field that we can test
        struct DateModel: Codable {
            let date: Date
        }
        
        let testDate = Date()
        let model = DateModel(date: testDate)
        
        try await service.save(model, to: "date_test")
        
        // Read the raw JSON to verify ISO8601 format
        let fileURL = tempDir.appendingPathComponent("date_test.json")
        let jsonData = try Data(contentsOf: fileURL)
        let jsonString = String(data: jsonData, encoding: .utf8)!
        
        // ISO8601 format should contain 'T' and 'Z'
        #expect(jsonString.contains("T"))
        #expect(jsonString.contains("Z"))
        
        // Verify it can be decoded back correctly
        let loadedModel = try await service.load(DateModel.self, from: "date_test")
        #expect(abs((loadedModel?.date.timeIntervalSince1970 ?? 0) - testDate.timeIntervalSince1970) < 1.0)
    }
    
    @Test("FileStorageService uses pretty printed JSON")
    func jsonEncodingUsesPrettyPrinting() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_pretty_json_\(UUID().uuidString)")
        let service = try FileStorageService(baseDirectory: tempDir)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let cv = CVTestDataBuilder.completeCV().build()
        try await service.save(cv, to: "pretty_test")
        
        let fileURL = tempDir.appendingPathComponent("pretty_test.json")
        let jsonData = try Data(contentsOf: fileURL)
        let jsonString = String(data: jsonData, encoding: .utf8)!
        
        // Pretty printed JSON should contain newlines and indentation
        #expect(jsonString.contains("\n"))
        #expect(jsonString.contains("  ")) // Indentation spaces
    }
    
    // MARK: - Edge Case Tests
    
    @Test("FileStorageService handles special characters in identifiers")
    func handlesSpecialCharactersInIdentifiers() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_special_chars_\(UUID().uuidString)")
        let service = try FileStorageService(baseDirectory: tempDir)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let cv = CVTestDataBuilder.minimalCV().build()
        
        // Test various identifier formats that might be used
        let identifiers = ["test-cv", "test_cv", "test.cv", "123abc", "cv-2024"]
        
        for identifier in identifiers {
            try await service.save(cv, to: identifier)
            let exists = await service.exists(identifier: identifier)
            #expect(exists)
            
            let loaded = try await service.load(CVModel.self, from: identifier)
            #expect(loaded != nil)
        }
        
        let allIdentifiers = try await service.getAllIdentifiers()
        #expect(allIdentifiers.count == identifiers.count)
        
        for identifier in identifiers {
            #expect(allIdentifiers.contains(identifier))
        }
    }
    
    @Test("FileStorageService handles large data objects")
    func handlesLargeDataObjects() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_large_data_\(UUID().uuidString)")
        let service = try FileStorageService(baseDirectory: tempDir)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        // Create a CV with lots of data
        let largeCV = CVTestDataBuilder.completeCV()
            .withName("Large CV with Extensive Experience")
            .withTitle("Senior Software Architect with 20+ years of experience in multiple domains")
            .build()
        
        // Add many experiences, skills, etc to make it large
        var experiences: [Experience] = []
        for i in 1...50 {
            experiences.append(Experience(
                title: "Software Engineer \(i)",
                company: "Tech Company \(i)",
                location: "City \(i), Country",
                period: "2020-202\(i % 10)",
                description: String(repeating: "This is a detailed description of the role and responsibilities. ", count: 10)
            ))
        }
        
        var skills: [Skill] = []
        for i in 1...100 {
            skills.append(Skill(name: "Technology \(i)", level: i % 5 + 1))
        }
        
        let complexCV = CVModel(
            id: largeCV.id,
            name: largeCV.name,
            personalInfo: PersonalInfo(
                name: largeCV.personalInfo.name,
                title: largeCV.personalInfo.title,
                location: largeCV.personalInfo.location,
                email: largeCV.personalInfo.email,
                phone: largeCV.personalInfo.phone,
                portfolio: largeCV.personalInfo.portfolio,
                profile: largeCV.personalInfo.profile
            ),
            relevant_experience: experiences,
            education: largeCV.education,
            skills: skills,
            languages: largeCV.languages,
            certifications: largeCV.certifications,
            interests: largeCV.interests,
            social: largeCV.social
        )
        
        try await service.save(complexCV, to: "large_cv")
        
        let loaded = try await service.load(CVModel.self, from: "large_cv")
        #expect(loaded != nil)
        #expect(loaded?.relevant_experience.count == 50)
        #expect(loaded?.skills.count == 100)
        #expect(loaded?.name == complexCV.name)
    }
    
    @Test("FileStorageService handles rapid sequential operations")
    func handlesRapidSequentialOperations() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_rapid_ops_\(UUID().uuidString)")
        let service = try FileStorageService(baseDirectory: tempDir)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let baseCV = CVTestDataBuilder.minimalCV().build()
        
        // Perform rapid save/load/update operations
        for i in 1...20 {
            let cv = CVModel(
                id: baseCV.id,
                name: "CV Version \(i)",
                personalInfo: PersonalInfo(
                    name: baseCV.personalInfo.name,
                    title: baseCV.personalInfo.title,
                    location: baseCV.personalInfo.location,
                    email: baseCV.personalInfo.email,
                    phone: baseCV.personalInfo.phone,
                    portfolio: baseCV.personalInfo.portfolio,
                    profile: "Profile updated in iteration \(i)"
                ),
                relevant_experience: baseCV.relevant_experience,
                education: baseCV.education,
                skills: baseCV.skills,
                languages: baseCV.languages,
                certifications: baseCV.certifications,
                interests: baseCV.interests,
                social: baseCV.social
            )
            
            try await service.save(cv, to: "rapid_test")
            let loaded = try await service.load(CVModel.self, from: "rapid_test")
            #expect(loaded?.name == "CV Version \(i)")
            #expect(loaded?.personalInfo.profile == "Profile updated in iteration \(i)")
        }
        
        // Verify final state
        let finalCV = try await service.load(CVModel.self, from: "rapid_test")
        #expect(finalCV?.name == "CV Version 20")
    }
    
    @Test("FileStorageService handles delete and recreate cycles")
    func handlesDeleteAndRecreateCycles() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("test_delete_recreate_\(UUID().uuidString)")
        let service = try FileStorageService(baseDirectory: tempDir)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let cv1 = CVTestDataBuilder.minimalCV().withName("Original CV").build()
        let cv2 = CVTestDataBuilder.minimalCV().withName("Replacement CV").build()
        
        // Save, delete, save cycle
        for _ in 1...5 {
            // Save original
            try await service.save(cv1, to: "cycle_test")
            let exists1 = await service.exists(identifier: "cycle_test")
            #expect(exists1)
            
            // Delete
            try await service.delete(identifier: "cycle_test")
            let exists2 = await service.exists(identifier: "cycle_test")
            #expect(!exists2)
            
            // Save replacement
            try await service.save(cv2, to: "cycle_test")
            let loaded = try await service.load(CVModel.self, from: "cycle_test")
            #expect(loaded?.name == "Replacement CV")
        }
        
        // Final verification
        let finalCV = try await service.load(CVModel.self, from: "cycle_test")
        #expect(finalCV?.name == "Replacement CV")
    }
}