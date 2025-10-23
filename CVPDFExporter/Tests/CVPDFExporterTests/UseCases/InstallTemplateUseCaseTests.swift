import Testing
import Foundation
@testable import CVPDFExporter

// MARK: - Install Template Use Case Tests (TDD)

@Suite("Install Template Use Case")
struct InstallTemplateUseCaseTests {

    // MARK: - Successful Installation Tests

    @Test("Use case installs valid package to repository")
    func useCaseInstallsValidPackageToRepository() async throws {
        // Given
        let mockRepo = MockInstallableRepository()
        let useCase = InstallTemplateUseCase(repository: mockRepo)

        let manifest = TemplateManifest(
            id: "new-template",
            name: "New Template",
            description: "A new template",
            author: "Test Author",
            version: "1.0.0",
            previewImage: "preview.png",
            price: 0.0
        )
        let package = TemplatePackage(
            manifest: manifest,
            cssContent: "body { color: blue; }",
            htmlContent: nil
        )

        // When
        try await useCase.execute(package: package)

        // Then
        #expect(mockRepo.installedPackages.count == 1)
        #expect(mockRepo.installedPackages.first?.manifest.id == "new-template")
    }

    @Test("Use case validates package before installation")
    func useCaseValidatesPackageBeforeInstallation() async throws {
        // Given
        let mockRepo = MockInstallableRepository()
        let useCase = InstallTemplateUseCase(repository: mockRepo)

        let invalidManifest = TemplateManifest(
            id: "", // Invalid empty ID
            name: "Test",
            description: "Test",
            author: "Test",
            version: "1.0.0",
            previewImage: "preview.png",
            price: 0.0
        )
        let invalidPackage = TemplatePackage(
            manifest: invalidManifest,
            cssContent: "body {}",
            htmlContent: nil
        )

        // When/Then
        await #expect(throws: TemplateInstallationError.self) {
            try await useCase.execute(package: invalidPackage)
        }

        // Repository should not have been called
        #expect(mockRepo.installedPackages.isEmpty)
    }

    // MARK: - Validation Tests

    @Test("Use case rejects package with empty CSS content")
    func useCaseRejectsPackageWithEmptyCSSContent() async throws {
        // Given
        let mockRepo = MockInstallableRepository()
        let useCase = InstallTemplateUseCase(repository: mockRepo)

        let manifest = TemplateManifest(
            id: "test",
            name: "Test",
            description: "Test",
            author: "Test",
            version: "1.0.0",
            previewImage: "preview.png",
            price: 0.0
        )
        let invalidPackage = TemplatePackage(
            manifest: manifest,
            cssContent: "   ", // Empty/whitespace only
            htmlContent: nil
        )

        // When/Then
        await #expect(throws: TemplateInstallationError.self) {
            try await useCase.execute(package: invalidPackage)
        }

        #expect(mockRepo.installedPackages.isEmpty)
    }

    @Test("Use case rejects package with invalid manifest ID")
    func useCaseRejectsPackageWithInvalidManifestID() async throws {
        // Given
        let mockRepo = MockInstallableRepository()
        let useCase = InstallTemplateUseCase(repository: mockRepo)

        let manifest = TemplateManifest(
            id: "  ", // Whitespace only
            name: "Test",
            description: "Test",
            author: "Test",
            version: "1.0.0",
            previewImage: "preview.png",
            price: 0.0
        )
        let package = TemplatePackage(
            manifest: manifest,
            cssContent: "body {}",
            htmlContent: nil
        )

        // When/Then
        await #expect(throws: TemplateInstallationError.self) {
            try await useCase.execute(package: package)
        }
    }

    @Test("Use case rejects package with negative price")
    func useCaseRejectsPackageWithNegativePrice() async throws {
        // Given
        let mockRepo = MockInstallableRepository()
        let useCase = InstallTemplateUseCase(repository: mockRepo)

        let manifest = TemplateManifest(
            id: "test",
            name: "Test",
            description: "Test",
            author: "Test",
            version: "1.0.0",
            previewImage: "preview.png",
            price: -5.0 // Invalid negative price
        )
        let package = TemplatePackage(
            manifest: manifest,
            cssContent: "body {}",
            htmlContent: nil
        )

        // When/Then
        await #expect(throws: TemplateInstallationError.self) {
            try await useCase.execute(package: package)
        }
    }

    // MARK: - Repository Error Handling Tests

    @Test("Use case wraps repository errors")
    func useCaseWrapsRepositoryErrors() async throws {
        // Given
        let failingRepo = MockInstallableRepository()
        failingRepo.shouldThrowError = true
        let useCase = InstallTemplateUseCase(repository: failingRepo)

        let manifest = TemplateManifest(
            id: "test",
            name: "Test",
            description: "Test",
            author: "Test",
            version: "1.0.0",
            previewImage: "preview.png",
            price: 0.0
        )
        let package = TemplatePackage(
            manifest: manifest,
            cssContent: "body {}",
            htmlContent: nil
        )

        // When/Then - Should wrap in TemplateInstallationError
        await #expect(throws: TemplateInstallationError.self) {
            try await useCase.execute(package: package)
        }
    }

    // MARK: - Duplicate Detection Tests

    @Test("Use case checks for existing template with same ID")
    func useCaseChecksForExistingTemplateWithSameID() async throws {
        // Given
        let mockRepo = MockInstallableRepository()
        mockRepo.existingTemplates = [
            Template(id: "existing", name: "Existing", description: "Test", htmlContent: "<html></html>")
        ]
        let useCase = InstallTemplateUseCase(repository: mockRepo)

        let manifest = TemplateManifest(
            id: "existing", // Same ID as existing template
            name: "New Version",
            description: "Test",
            author: "Test",
            version: "2.0.0",
            previewImage: "preview.png",
            price: 0.0
        )
        let package = TemplatePackage(
            manifest: manifest,
            cssContent: "body {}",
            htmlContent: nil
        )

        // When/Then
        await #expect(throws: TemplateInstallationError.self) {
            try await useCase.execute(package: package)
        }

        // Should not have installed
        #expect(mockRepo.installedPackages.isEmpty)
    }

    @Test("Use case allows installation when ID is unique")
    func useCaseAllowsInstallationWhenIDIsUnique() async throws {
        // Given
        let mockRepo = MockInstallableRepository()
        mockRepo.existingTemplates = [
            Template(id: "template1", name: "Template 1", description: "Test", htmlContent: "<html></html>")
        ]
        let useCase = InstallTemplateUseCase(repository: mockRepo)

        let manifest = TemplateManifest(
            id: "template2", // Different ID
            name: "Template 2",
            description: "Test",
            author: "Test",
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
        try await useCase.execute(package: package)

        // Then
        #expect(mockRepo.installedPackages.count == 1)
        #expect(mockRepo.installedPackages.first?.manifest.id == "template2")
    }
}

// MARK: - Mock Repository for Installation Testing

/// Mock repository that supports installation
final class MockInstallableRepository: TemplateRepositoryProtocol, @unchecked Sendable {
    var installedPackages: [TemplatePackage] = []
    var existingTemplates: [Template] = []
    var shouldThrowError = false

    func getTemplates() async throws -> [Template] {
        if shouldThrowError {
            throw TemplateRepositoryError.ioError("Mock error")
        }
        return existingTemplates
    }

    func getTemplate(id: String) async throws -> Template? {
        if shouldThrowError {
            throw TemplateRepositoryError.templateNotFound(id)
        }
        return existingTemplates.first { $0.id == id }
    }

    func installTemplate(_ package: TemplatePackage) async throws {
        if shouldThrowError {
            throw TemplateRepositoryError.ioError("Mock installation error")
        }
        installedPackages.append(package)
    }
}
