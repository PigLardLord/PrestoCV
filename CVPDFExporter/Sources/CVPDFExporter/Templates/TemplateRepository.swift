import Foundation

// MARK: - Template Repository Protocol

/// Protocol for loading and managing templates
public protocol TemplateRepository: Sendable {
    func loadTemplate(id: String) throws -> Template
    func availableTemplates() -> [Template]
}

// MARK: - Bundled Template Repository

/// Repository for built-in templates
public final class BundledTemplateRepository: TemplateRepository, TemplateRepositoryProtocol, @unchecked Sendable {
    private let templates: [Template]

    public init() {
        self.templates = Self.loadBundledTemplates()
    }

    public func loadTemplate(id: String) throws -> Template {
        guard let template = templates.first(where: { $0.id == id }) else {
            throw TemplateError.templateNotFound(id)
        }
        return template
    }

    public func availableTemplates() -> [Template] {
        return templates
    }

    // MARK: - TemplateRepositoryProtocol

    public func getTemplates() async throws -> [Template] {
        return templates
    }

    public func getTemplate(id: String) async throws -> Template? {
        return templates.first { $0.id == id }
    }

    public func installTemplate(_ package: TemplatePackage) async throws {
        // Bundled templates are read-only
        throw TemplateRepositoryError.ioError("Cannot install templates into bundled repository")
    }

    // MARK: - Private Methods

    private static func loadBundledTemplates() -> [Template] {
        var templates: [Template] = []

        // Professional Template
        templates.append(Template(
            id: "professional",
            name: "Professional",
            description: "Clean and professional template suitable for corporate positions",
            htmlContent: loadProfessionalTemplate(),
            supportedVariables: [
                "name", "email", "phone", "location", "website", "summary",
                "hasSummary", "hasPhone", "hasLocation", "hasWebsite",
                "workExperience", "hasWorkExperience",
                "education", "hasEducation",
                "skills", "hasSkills",
                "colorPrimary", "colorSecondary", "colorAccent", "colorBackground", "colorText",
                "fontHeading", "fontBody", "fontSize"
            ],
            thumbnailURL: loadThumbnailURL(for: "professional")
        ))

        // Modern Template
        templates.append(Template(
            id: "modern",
            name: "Modern",
            description: "Contemporary design with clean lines and modern typography",
            htmlContent: loadModernTemplate(),
            supportedVariables: [
                "name", "email", "phone", "location", "website", "summary",
                "hasSummary", "hasPhone", "hasLocation", "hasWebsite",
                "workExperience", "hasWorkExperience",
                "education", "hasEducation",
                "skills", "hasSkills",
                "colorPrimary", "colorSecondary", "colorAccent", "colorBackground", "colorText",
                "fontHeading", "fontBody", "fontSize"
            ],
            thumbnailURL: loadThumbnailURL(for: "modern")
        ))

        // Minimal Template
        templates.append(Template(
            id: "minimal",
            name: "Minimal",
            description: "Simple and clean design focusing on content",
            htmlContent: loadMinimalTemplate(),
            supportedVariables: [
                "name", "email", "phone", "location", "summary",
                "hasSummary", "hasPhone", "hasLocation",
                "workExperience", "hasWorkExperience",
                "education", "hasEducation",
                "skills", "hasSkills"
            ],
            thumbnailURL: loadThumbnailURL(for: "minimal")
        ))

        return templates
    }

    private static func loadProfessionalTemplate() -> String {
        return ProfessionalHTMLTemplate.html
    }

    private static func loadModernTemplate() -> String {
        return ModernHTMLTemplate.html
    }

    private static func loadMinimalTemplate() -> String {
        return MinimalHTMLTemplate.html
    }

    /// Loads the thumbnail URL for a template from the bundle resources
    /// - Parameter templateId: The ID of the template (e.g., "professional", "modern", "minimal")
    /// - Returns: URL to the template's preview image, or nil if not found
    private static func loadThumbnailURL(for templateId: String) -> URL? {
        let filename = "\(templateId)_preview"

        // Get the bundle for this class/module
        let bundle = Bundle(for: BundledTemplateRepository.self)

        // Try to find the preview PNG in the bundle - try Resources/Templates subdirectory first
        if let url = bundle.url(forResource: filename, withExtension: "png", subdirectory: "Resources/Templates") {
            return url
        }

        // Fallback: try just Templates subdirectory
        if let url = bundle.url(forResource: filename, withExtension: "png", subdirectory: "Templates") {
            return url
        }

        // Fallback: try without subdirectory
        if let url = bundle.url(forResource: filename, withExtension: "png") {
            return url
        }

        // Final fallback: construct absolute path directly
        let resourcesPath = "/Users/dev/PrestoCV/CVPDFExporter/Resources/Templates/\(filename).png"
        if FileManager.default.fileExists(atPath: resourcesPath) {
            return URL(fileURLWithPath: resourcesPath)
        }

        // Log warning if not found (visible during development)
        print("⚠️ Warning: Thumbnail not found for template '\(templateId)' (looking for '\(filename).png')")
        return nil
    }
}
