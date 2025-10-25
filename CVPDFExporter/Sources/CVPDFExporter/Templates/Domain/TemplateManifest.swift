import Foundation

/// Template manifest containing metadata about a template package
/// Represents the manifest.json file in a .mcvt package
public struct TemplateManifest: Codable, Equatable, Sendable {
    /// Unique identifier for the template
    public let id: String

    /// Display name of the template
    public let name: String

    /// Description of the template's style and features
    public let description: String

    /// Author/creator of the template
    public let author: String

    /// Semantic version string (e.g., "1.0.0")
    public let version: String

    /// Filename of the preview image (PNG) in the package
    public let previewImage: String

    /// Base64-encoded preview image (PNG) embedded in the package
    /// If provided, this allows the preview to be self-contained within the .mcvt file
    /// Optional for backward compatibility with templates that reference external preview files
    public let previewImageBase64: String?

    /// Price in USD (0.0 for free templates)
    public let price: Double

    public init(
        id: String,
        name: String,
        description: String,
        author: String,
        version: String,
        previewImage: String,
        previewImageBase64: String? = nil,
        price: Double
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.author = author
        self.version = version
        self.previewImage = previewImage
        self.previewImageBase64 = previewImageBase64
        self.price = price
    }

    /// Validates the manifest has all required fields properly set
    public var isValid: Bool {
        // ID must not be empty
        guard !id.trimmingCharacters(in: .whitespaces).isEmpty else {
            return false
        }

        // Name must not be empty
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            return false
        }

        // Version must not be empty
        guard !version.trimmingCharacters(in: .whitespaces).isEmpty else {
            return false
        }

        // Price must be non-negative
        guard price >= 0.0 else {
            return false
        }

        return true
    }

    /// True if the template is free (price is 0.0)
    public var isFree: Bool {
        price == 0.0
    }
}
