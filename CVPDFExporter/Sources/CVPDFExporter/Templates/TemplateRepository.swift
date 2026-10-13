import Foundation

// MARK: - Bundled Template Repository

/// Repository for built-in templates
/// Delegates to FileTemplateRepository, which loads from the registry that the bootstrap service fills
public final class BundledTemplateRepository: TemplateRepositoryProtocol, @unchecked Sendable {

    /// Either the repository in Application Support or the reason it could not be opened.
    /// A failure surfaces as an error when templates are requested, so that the app can tell the user
    /// instead of crashing while it builds its dependencies.
    private let fileRepository: Result<FileTemplateRepository, Error>

    public init() {
        fileRepository = Result {
            try FileTemplateRepository(templatesDirectory: TemplateStorageLocation.templatesDirectory())
        }
    }

    init(opening openRepository: () throws -> FileTemplateRepository) {
        fileRepository = Result(catching: openRepository)
    }

    /// Designated initializer with injected FileTemplateRepository
    public init(fileRepository: FileTemplateRepository) {
        self.fileRepository = .success(fileRepository)
    }

    // MARK: - TemplateRepositoryProtocol

    public func getTemplates() async throws -> [Template] {
        return try await fileRepository.get().getTemplates()
    }

    public func getTemplate(id: String) async throws -> Template? {
        return try await fileRepository.get().getTemplate(id: id)
    }

    public func installTemplate(_ package: TemplatePackage) async throws {
        // Bundled templates are read-only - don't allow installation
        throw TemplateRepositoryError.ioError("Cannot install templates into bundled repository")
    }
}
