import Foundation

// MARK: - Template Repository Protocol

/// Protocol for loading and managing templates
public protocol TemplateRepository: Sendable {
    func loadTemplate(id: String) throws -> Template
    func availableTemplates() -> [Template]
}

// MARK: - Bundled Template Repository

/// Repository for built-in templates
/// Now delegates to FileTemplateRepository which loads from registry
/// Maintains backward compatibility with TemplateRepository protocol
public final class BundledTemplateRepository: TemplateRepository, TemplateRepositoryProtocol, @unchecked Sendable {
    private let fileRepository: FileTemplateRepository

    public init() {
        // Initialize with default Application Support directory
        let templatesDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("PrestoCV/Templates")

        do {
            self.fileRepository = try FileTemplateRepository(templatesDirectory: templatesDir)
        } catch {
            // Fatal error - registry initialization failed
            fatalError("Failed to initialize BundledTemplateRepository: \(error)")
        }
    }

    /// Designated initializer with injected FileTemplateRepository
    public init(fileRepository: FileTemplateRepository) {
        self.fileRepository = fileRepository
    }

    // MARK: - TemplateRepository (Legacy Protocol)

    public func loadTemplate(id: String) throws -> Template {
        // Synchronous wrapper for async method - for backward compatibility
        // Use Task.detached to avoid Sendable warnings
        let box = ResultBox<Template>()
        let repo = fileRepository
        let templateId = id

        Task.detached {
            do {
                guard let template = try await repo.getTemplate(id: templateId) else {
                    box.set(result: .failure(TemplateError.templateNotFound(templateId)))
                    return
                }
                box.set(result: .success(template))
            } catch {
                box.set(result: .failure(error))
            }
        }

        switch box.wait() {
        case .success(let template):
            return template
        case .failure(let error):
            throw error
        }
    }

    public func availableTemplates() -> [Template] {
        // Synchronous wrapper for async method - for backward compatibility
        let box = ResultBox<[Template]>()
        let repo = fileRepository

        Task.detached {
            do {
                let templates = try await repo.getTemplates()
                box.set(result: .success(templates))
            } catch {
                box.set(result: .success([]))
            }
        }

        return (try? box.wait().get()) ?? []
    }

    // MARK: - TemplateRepositoryProtocol (Modern Async Interface)

    public func getTemplates() async throws -> [Template] {
        return try await fileRepository.getTemplates()
    }

    public func getTemplate(id: String) async throws -> Template? {
        return try await fileRepository.getTemplate(id: id)
    }

    public func installTemplate(_ package: TemplatePackage) async throws {
        // Bundled templates are read-only - don't allow installation
        throw TemplateRepositoryError.ioError("Cannot install templates into bundled repository")
    }
}

// MARK: - ResultBox Helper

/// Thread-safe result box for bridging async/await to synchronous code
/// Used by BundledTemplateRepository for backward compatibility
private final class ResultBox<T>: @unchecked Sendable {
    private var result: Result<T, Error>?
    private let semaphore = DispatchSemaphore(value: 0)
    private let lock = NSLock()

    func set(result: Result<T, Error>) {
        lock.lock()
        self.result = result
        lock.unlock()
        semaphore.signal()
    }

    func wait() -> Result<T, Error> {
        semaphore.wait()
        lock.lock()
        defer { lock.unlock() }
        return result!
    }
}
