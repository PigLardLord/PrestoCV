import Foundation

/// Errors that can occur when working with template repositories
public enum TemplateRepositoryError: Error, Equatable {
    /// Template with specified ID was not found
    case templateNotFound(String)

    /// Template package is invalid (corrupt manifest, missing files, etc.)
    case invalidPackage(String)

    /// I/O error occurred (file system, network, etc.)
    case ioError(String)
}
