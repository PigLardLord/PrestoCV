import Foundation
import Testing
@testable import PrestoCVCore

// MARK: - JSONTemplateLoader Tests

@Suite("JSONTemplateLoader Tests")
struct JSONTemplateLoaderTests {
    
    private let testDirectory: URL = {
        let tempDir = FileManager.default.temporaryDirectory
        return tempDir.appendingPathComponent("JSONTemplateLoaderTests", isDirectory: true)
    }()
    
    // MARK: - Setup Helper
    
    private func createTestDirectory() throws {
        if !FileManager.default.fileExists(atPath: testDirectory.path) {
            try FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)
        }
    }
    
    private func cleanupTestDirectory() throws {
        if FileManager.default.fileExists(atPath: testDirectory.path) {
            try? FileManager.default.removeItem(at: testDirectory)
        }
    }
    
    private func createValidJSONFile(name: String, cv: CVModel) throws -> String {
        try createTestDirectory()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(cv)
        let fileURL = testDirectory.appendingPathComponent("\(name).json")
        try data.write(to: fileURL)
        return fileURL.path
    }
    
    private func createInvalidJSONFile(name: String, content: String) throws -> String {
        try createTestDirectory()
        let fileURL = testDirectory.appendingPathComponent("\(name).json")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL.path
    }
    
    // MARK: - Basic Tests
    
    @Test("JSONTemplateLoader initializes correctly")
    func initializesCorrectly() async {
        let loader = JSONTemplateLoader()
        _ = loader
    }
    
    @Test("loadTemplate from path loads valid CV successfully")
    func loadTemplateFromPathLoadsValidCV() async throws {
        let loader = JSONTemplateLoader()
        
        let testCV = CVTestDataBuilder()
            .withPersonalInfo(PersonalInfo(name: "Test Template", email: "test@example.com"))
            .build()
        
        let filePath = try createValidJSONFile(name: "valid_template", cv: testCV)
        
        let loadedCV = await loader.loadTemplate(from: filePath)
        
        #expect(loadedCV != nil)
        #expect(loadedCV?.personalInfo.name == "Test Template")
        #expect(loadedCV?.personalInfo.email == "test@example.com")
    }
    
    @Test("loadTemplate from path returns nil for non-existent file")
    func loadTemplateFromPathReturnsNilForNonExistentFile() async {
        let loader = JSONTemplateLoader()
        
        let nonExistentPath = "/nonexistent/path/file.json"
        let result = await loader.loadTemplate(from: nonExistentPath)
        
        #expect(result == nil)
    }
    
    @Test("loadTemplate from URL loads valid CV successfully")
    func loadTemplateFromURLLoadsValidCV() async throws {
        let loader = JSONTemplateLoader()
        
        let testCV = CVTestDataBuilder()
            .withPersonalInfo(PersonalInfo(name: "URL Test Template", email: "urltest@example.com"))
            .build()
        
        let filePath = try createValidJSONFile(name: "url_template", cv: testCV)
        let fileURL = URL(fileURLWithPath: filePath)
        
        let loadedCV = try await loader.loadTemplate(from: fileURL)
        
        #expect(loadedCV.personalInfo.name == "URL Test Template")
        #expect(loadedCV.personalInfo.email == "urltest@example.com")
    }
    
    @Test("loadTemplate from URL throws error for non-existent file")
    func loadTemplateFromURLThrowsErrorForNonExistentFile() async throws {
        let loader = JSONTemplateLoader()
        
        let nonExistentURL = URL(fileURLWithPath: "/nonexistent/path/file.json")
        
        await #expect(throws: AppError.self) {
            try await loader.loadTemplate(from: nonExistentURL)
        }
    }
    
    @Test("loadTemplates returns empty array for empty paths array")
    func loadTemplatesReturnsEmptyArrayForEmptyPaths() async {
        let loader = JSONTemplateLoader()
        
        let loadedTemplates = await loader.loadTemplates(from: [])
        
        #expect(loadedTemplates.isEmpty)
    }
    
    @Test("loadTemplateIfMatches returns nil when matcher returns false")
    func loadTemplateIfMatchesReturnsNilWhenMatcherFalse() async throws {
        let loader = JSONTemplateLoader()
        
        let testCV = CVTestDataBuilder().withPersonalInfo(PersonalInfo(name: "Non-matching Template")).build()
        let filePath = try createValidJSONFile(name: "nonmatching_template", cv: testCV)
        
        let matcher: @Sendable (String) -> Bool = { fileName in
            return fileName == "different_name"
        }
        
        let result = try await loader.loadTemplateIfMatches(path: filePath, matcher: matcher)
        
        #expect(result == nil)
    }
    
    @Test("loadTemplateIfMatches loads template when matcher returns true")
    func loadTemplateIfMatchesLoadsWhenMatcherTrue() async throws {
        let loader = JSONTemplateLoader()
        
        let testCV = CVTestDataBuilder().withPersonalInfo(PersonalInfo(name: "Matching Template")).build()
        let filePath = try createValidJSONFile(name: "matching_template", cv: testCV)
        
        let matcher: @Sendable (String) -> Bool = { fileName in
            return fileName == "matching_template"
        }
        
        let result = try await loader.loadTemplateIfMatches(path: filePath, matcher: matcher)
        
        #expect(result != nil)
        #expect(result?.personalInfo.name == "Matching Template")
    }
}