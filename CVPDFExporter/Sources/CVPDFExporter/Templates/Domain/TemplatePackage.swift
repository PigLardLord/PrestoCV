import Foundation

/// Represents a complete template package (.mcvt file)
/// Contains manifest, CSS, and optional HTML content
public struct TemplatePackage: Codable, Equatable, Sendable {
    /// Template metadata
    public let manifest: TemplateManifest

    /// CSS stylesheet content
    /// This is the primary customization for templates sharing a common HTML structure
    public let cssContent: String

    /// Optional HTML content
    /// If nil, the template uses the shared base HTML template
    /// If provided, this HTML will be used instead
    public let htmlContent: String?

    public init(
        manifest: TemplateManifest,
        cssContent: String,
        htmlContent: String? = nil
    ) {
        self.manifest = manifest
        self.cssContent = cssContent
        self.htmlContent = htmlContent
    }

    /// Validates the package has valid manifest and non-empty CSS
    public var isValid: Bool {
        // Manifest must be valid
        guard manifest.isValid else {
            return false
        }

        // CSS content must not be empty
        guard !cssContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        return true
    }

    /// True if this package uses the shared base HTML template (no custom HTML)
    public var usesBaseTemplate: Bool {
        htmlContent == nil
    }
}
