import Testing
import Foundation
@testable import CVPDFExporter

// MARK: - Get Available Templates Use Case Tests (TDD)

@Suite("Get Available Templates Use Case")
struct GetAvailableTemplatesUseCaseTests {

    // MARK: - Single Repository Tests

    @Test("Use case retrieves templates from single repository")
    func useCaseRetrievesTemplatesFromSingleRepository() async throws {
        // Given
        let mockRepo = MockRepositoryForUseCaseTesting()
        mockRepo.mockTemplates = [
            Template(id: "template1", name: "Template 1", description: "Test", htmlContent: "<html>1</html>"),
            Template(id: "template2", name: "Template 2", description: "Test", htmlContent: "<html>2</html>")
        ]
        let useCase = GetAvailableTemplatesUseCase(repositories: [mockRepo])

        // When
        let templates = try await useCase.execute()

        // Then
        #expect(templates.count == 2)
        #expect(templates.contains(where: { $0.id == "template1" }))
        #expect(templates.contains(where: { $0.id == "template2" }))
    }

    @Test("Use case returns empty array when repository is empty")
    func useCaseReturnsEmptyArrayWhenRepositoryEmpty() async throws {
        // Given
        let mockRepo = MockRepositoryForUseCaseTesting()
        mockRepo.mockTemplates = []
        let useCase = GetAvailableTemplatesUseCase(repositories: [mockRepo])

        // When
        let templates = try await useCase.execute()

        // Then
        #expect(templates.isEmpty)
    }

    // MARK: - Multiple Repository Tests

    @Test("Use case combines templates from multiple repositories")
    func useCaseCombinesTemplatesFromMultipleRepositories() async throws {
        // Given
        let bundledRepo = MockRepositoryForUseCaseTesting()
        bundledRepo.mockTemplates = [
            Template(id: "bundled1", name: "Bundled 1", description: "Test", htmlContent: "<html>1</html>"),
            Template(id: "bundled2", name: "Bundled 2", description: "Test", htmlContent: "<html>2</html>")
        ]

        let fileRepo = MockRepositoryForUseCaseTesting()
        fileRepo.mockTemplates = [
            Template(id: "file1", name: "File 1", description: "Test", htmlContent: "<html>3</html>"),
            Template(id: "file2", name: "File 2", description: "Test", htmlContent: "<html>4</html>")
        ]

        let useCase = GetAvailableTemplatesUseCase(repositories: [bundledRepo, fileRepo])

        // When
        let templates = try await useCase.execute()

        // Then
        #expect(templates.count == 4)
        #expect(templates.contains(where: { $0.id == "bundled1" }))
        #expect(templates.contains(where: { $0.id == "bundled2" }))
        #expect(templates.contains(where: { $0.id == "file1" }))
        #expect(templates.contains(where: { $0.id == "file2" }))
    }

    @Test("Use case handles one repository failing gracefully")
    func useCaseHandlesOneRepositoryFailingGracefully() async throws {
        // Given
        let workingRepo = MockRepositoryForUseCaseTesting()
        workingRepo.mockTemplates = [
            Template(id: "template1", name: "Template 1", description: "Test", htmlContent: "<html>1</html>")
        ]

        let failingRepo = MockRepositoryForUseCaseTesting()
        failingRepo.shouldThrowError = true

        let useCase = GetAvailableTemplatesUseCase(repositories: [workingRepo, failingRepo])

        // When
        let templates = try await useCase.execute()

        // Then - Should still return templates from working repository
        #expect(templates.count == 1)
        #expect(templates.first?.id == "template1")
    }

    // MARK: - Duplicate Handling Tests

    @Test("Use case removes duplicate templates by ID")
    func useCaseRemovesDuplicateTemplatesByID() async throws {
        // Given
        let repo1 = MockRepositoryForUseCaseTesting()
        repo1.mockTemplates = [
            Template(id: "modern", name: "Modern V1", description: "Test", htmlContent: "<html>1</html>")
        ]

        let repo2 = MockRepositoryForUseCaseTesting()
        repo2.mockTemplates = [
            Template(id: "modern", name: "Modern V2", description: "Test", htmlContent: "<html>2</html>")
        ]

        let useCase = GetAvailableTemplatesUseCase(repositories: [repo1, repo2])

        // When
        let templates = try await useCase.execute()

        // Then - Should only have one "modern" template
        #expect(templates.count == 1)
        #expect(templates.first?.id == "modern")
    }

    @Test("Use case prioritizes first repository when duplicates exist")
    func useCasePrioritizesFirstRepositoryForDuplicates() async throws {
        // Given
        let bundledRepo = MockRepositoryForUseCaseTesting()
        bundledRepo.mockTemplates = [
            Template(id: "modern", name: "Bundled Modern", description: "Test", htmlContent: "<html>1</html>")
        ]

        let fileRepo = MockRepositoryForUseCaseTesting()
        fileRepo.mockTemplates = [
            Template(id: "modern", name: "File Modern", description: "Test", htmlContent: "<html>2</html>")
        ]

        let useCase = GetAvailableTemplatesUseCase(repositories: [bundledRepo, fileRepo])

        // When
        let templates = try await useCase.execute()

        // Then - Should keep the bundled version (first repository)
        #expect(templates.count == 1)
        #expect(templates.first?.name == "Bundled Modern")
    }

    // MARK: - Error Handling Tests

    @Test("Use case returns empty array when all repositories fail")
    func useCaseReturnsEmptyArrayWhenAllRepositoriesFail() async throws {
        // Given
        let failingRepo1 = MockRepositoryForUseCaseTesting()
        failingRepo1.shouldThrowError = true

        let failingRepo2 = MockRepositoryForUseCaseTesting()
        failingRepo2.shouldThrowError = true

        let useCase = GetAvailableTemplatesUseCase(repositories: [failingRepo1, failingRepo2])

        // When
        let templates = try await useCase.execute()

        // Then - Should return empty array, not throw
        #expect(templates.isEmpty)
    }

    @Test("Use case works with no repositories")
    func useCaseWorksWithNoRepositories() async throws {
        // Given
        let useCase = GetAvailableTemplatesUseCase(repositories: [])

        // When
        let templates = try await useCase.execute()

        // Then
        #expect(templates.isEmpty)
    }
}

// MARK: - Mock Repository for Use Case Testing

/// Mock implementation for testing use cases
final class MockRepositoryForUseCaseTesting: TemplateRepositoryProtocol, @unchecked Sendable {
    var mockTemplates: [Template] = []
    var shouldThrowError = false

    func getTemplates() async throws -> [Template] {
        if shouldThrowError {
            throw TemplateRepositoryError.ioError("Mock repository error")
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
        // No-op for mock
    }
}
