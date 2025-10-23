import Testing
import Foundation
@testable import CVPDFExporter

// MARK: - Template Repository Protocol Tests (TDD)

@Suite("Template Repository Protocol")
struct TemplateRepositoryProtocolTests {

    // MARK: - Protocol Conformance Tests

    @Test("MockRepository conforms to TemplateRepositoryProtocol")
    func mockRepositoryConformsToProtocol() {
        // Given
        let repository: any TemplateRepositoryProtocol = MockTemplateRepositoryForProtocolTests()

        // When/Then - Should compile and be assignable to protocol type
        #expect(repository is MockTemplateRepositoryForProtocolTests)
    }

    @Test("MockRepository returns templates asynchronously")
    func mockRepositoryReturnsTemplatesAsync() async throws {
        // Given
        let repository = MockTemplateRepositoryForProtocolTests()

        // When
        let templates = try await repository.getTemplates()

        // Then
        #expect(templates.count >= 0) // Should return array (even if empty)
    }

    @Test("MockRepository can retrieve template by ID")
    func mockRepositoryRetrievesTemplateByID() async throws {
        // Given
        let repository = MockTemplateRepositoryForProtocolTests()
        let testTemplate = Template(
            id: "test-modern",
            name: "Test Modern",
            description: "Test template",
            htmlContent: "<html></html>"
        )

        repository.mockTemplates = [testTemplate]

        // When
        let retrieved = try await repository.getTemplate(id: "test-modern")

        // Then
        #expect(retrieved != nil)
        #expect(retrieved?.id == "test-modern")
    }

    @Test("MockRepository returns nil for non-existent template")
    func mockRepositoryReturnsNilForNonExistentTemplate() async throws {
        // Given
        let repository = MockTemplateRepositoryForProtocolTests()

        // When
        let retrieved = try await repository.getTemplate(id: "non-existent")

        // Then
        #expect(retrieved == nil)
    }

    @Test("MockRepository can install template package")
    func mockRepositoryCanInstallTemplate() async throws {
        // Given
        let repository = MockTemplateRepositoryForProtocolTests()
        let manifest = TemplateManifest(
            id: "new-template",
            name: "New Template",
            description: "Test",
            author: "Author",
            version: "1.0.0",
            previewImage: "preview.png",
            price: 0.0
        )
        let package = TemplatePackage(
            manifest: manifest,
            cssContent: "body {}",
            htmlContent: nil
        )

        // When
        try await repository.installTemplate(package)

        // Then - Should not throw
        #expect(repository.installedPackages.contains(where: { $0.manifest.id == "new-template" }))
    }

    // MARK: - Error Handling Tests

    @Test("Repository protocol supports error throwing")
    func repositoryProtocolSupportsErrorThrowing() async {
        // Given
        let repository = MockTemplateRepositoryForProtocolTests()
        repository.shouldThrowError = true

        // When/Then
        await #expect(throws: TemplateRepositoryError.self) {
            try await repository.getTemplates()
        }
    }

    @Test("Repository defines TemplateRepositoryError")
    func repositoryDefinesTemplateRepositoryError() {
        // Given/When
        let notFoundError = TemplateRepositoryError.templateNotFound("test-id")
        let invalidError = TemplateRepositoryError.invalidPackage("Invalid manifest")
        let ioError = TemplateRepositoryError.ioError("File not found")

        // Then
        switch notFoundError {
        case .templateNotFound(let id):
            #expect(id == "test-id")
        default:
            Issue.record("Expected templateNotFound error")
        }

        switch invalidError {
        case .invalidPackage(let message):
            #expect(message == "Invalid manifest")
        default:
            Issue.record("Expected invalidPackage error")
        }

        switch ioError {
        case .ioError(let message):
            #expect(message == "File not found")
        default:
            Issue.record("Expected ioError error")
        }
    }
}

// MARK: - Mock Repository for Protocol Testing

/// Mock implementation of TemplateRepositoryProtocol for protocol testing
final class MockTemplateRepositoryForProtocolTests: TemplateRepositoryProtocol, @unchecked Sendable {
    var mockTemplates: [Template] = []
    var installedPackages: [TemplatePackage] = []
    var shouldThrowError = false

    func getTemplates() async throws -> [Template] {
        if shouldThrowError {
            throw TemplateRepositoryError.ioError("Mock error")
        }
        return mockTemplates
    }

    func getTemplate(id: String) async throws -> Template? {
        if shouldThrowError {
            throw TemplateRepositoryError.templateNotFound(id)
        }
        return mockTemplates.first { $0.id == id }
    }

    func installTemplate(_ package: TemplatePackage) async throws {
        if shouldThrowError {
            throw TemplateRepositoryError.invalidPackage("Mock error")
        }
        installedPackages.append(package)
    }
}
