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

    public func getAllTemplates() async throws -> [Template] {
        return templates
    }

    public func getTemplate(byId id: String) async throws -> Template? {
        return templates.first { $0.id == id }
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
            ]
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
            ]
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
            ]
        ))

        return templates
    }

    private static func loadProfessionalTemplate() -> String {
        // For now, return the existing Professional.html content
        // In future, this will load from bundled resources
        return ProfessionalHTMLTemplate.html
    }

    private static func loadModernTemplate() -> String {
        return ModernHTMLTemplate.html
    }

    private static func loadMinimalTemplate() -> String {
        return MinimalHTMLTemplate.html
    }
}
