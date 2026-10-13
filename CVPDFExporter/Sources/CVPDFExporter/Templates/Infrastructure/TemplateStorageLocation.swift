import Foundation

/// Where the installed template packages live on disk.
/// The registry and the preview images are kept next to them by `TemplateRegistryManager`.
enum TemplateStorageLocation {

    /// Application Support/PrestoCV/Templates
    /// - Throws: TemplateRepositoryError.ioError if the system has no Application Support directory
    static func templatesDirectory() throws -> URL {
        guard let applicationSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first else {
            throw TemplateRepositoryError.ioError("Application Support directory not found")
        }

        return applicationSupport.appendingPathComponent("PrestoCV/Templates")
    }
}
