import Testing
import Foundation
@testable import CVPDFExporter

// MARK: - Bundled Template Repository Failure Tests

/// A repository that cannot open its storage reports it when templates are requested; it never crashes
@Suite("Bundled Template Repository Failures")
struct BundledTemplateRepositoryFailureTests {

    private struct StorageUnavailable: Error, Equatable {}

    private func makeUnavailableRepository() -> BundledTemplateRepository {
        BundledTemplateRepository(opening: { throw StorageUnavailable() })
    }

    @Test("getTemplates throws the reason the storage could not be opened")
    func getTemplatesThrowsOpeningError() async {
        let repository = makeUnavailableRepository()

        await #expect(throws: StorageUnavailable.self) {
            _ = try await repository.getTemplates()
        }
    }

    @Test("getTemplate throws the reason the storage could not be opened")
    func getTemplateThrowsOpeningError() async {
        let repository = makeUnavailableRepository()

        await #expect(throws: StorageUnavailable.self) {
            _ = try await repository.getTemplate(id: "professional")
        }
    }

    @Test("loadTemplate throws the reason the storage could not be opened")
    func loadTemplateThrowsOpeningError() async {
        let repository = makeUnavailableRepository()

        await #expect(throws: StorageUnavailable.self) {
            _ = try await repository.loadTemplate(id: "professional")
        }
    }

    @Test("a repository that opened its storage serves it")
    func openedRepositoryServesTemplates() async throws {
        // Given
        let storage = try TemplateTestStorage()
        defer { storage.cleanUp() }
        try await storage.fileRepository.installTemplate(TemplatePackageFixtures.makePackage(id: "ready", name: "Ready"))
        let repository = BundledTemplateRepository(opening: { storage.fileRepository })

        // When
        let template = try await repository.loadTemplate(id: "ready")

        // Then
        #expect(template.name == "Ready")
    }
}
