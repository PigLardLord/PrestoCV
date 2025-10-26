import Foundation

/// Repository for loading and installing templates from the file system
/// Manages .mcvt template packages in a designated directory
/// Uses TemplateRegistryManager for metadata and preview management
public final class FileTemplateRepository: TemplateRepositoryProtocol, @unchecked Sendable {

    public let templatesDirectory: URL
    private let fileManager = FileManager.default
    private let registryManager: TemplateRegistryManager

    // MARK: - Initialization

    public init(templatesDirectory: URL, registryManager: TemplateRegistryManager) {
        self.templatesDirectory = templatesDirectory
        self.registryManager = registryManager
        createTemplatesDirectoryIfNeeded()
    }

    /// Convenience initializer that creates a default registry manager
    public convenience init(templatesDirectory: URL) throws {
        let registryManager = try TemplateRegistryManager()
        self.init(templatesDirectory: templatesDirectory, registryManager: registryManager)
    }

    // MARK: - TemplateRepositoryProtocol

    public func getTemplates() async throws -> [Template] {
        // Load registry entries
        let registryEntries = try await registryManager.getAllTemplates()
        var templates: [Template] = []

        for entry in registryEntries {
            do {
                // Load package from templates directory
                let packageURL = templatesDirectory.appendingPathComponent("\(entry.id).mcvt")
                let package = try loadPackage(from: packageURL)

                // Convert to Template with preview URL from registry
                let template = try convertToTemplate(package, previewPath: entry.previewPath)
                templates.append(template)
            } catch {
                // Skip invalid packages and continue loading others
                continue
            }
        }

        return templates
    }

    public func getTemplate(id: String) async throws -> Template? {
        // Try to get entry from registry first
        guard let entry = try await registryManager.getTemplate(id: id) else {
            return nil
        }

        // Load package
        let packageURL = templatesDirectory.appendingPathComponent("\(entry.id).mcvt")
        do {
            let package = try loadPackage(from: packageURL)
            return try convertToTemplate(package, previewPath: entry.previewPath)
        } catch {
            return nil
        }
    }

    public func installTemplate(_ package: TemplatePackage) async throws {
        // Validate package
        guard package.isValid else {
            throw TemplateRepositoryError.invalidPackage("Package validation failed: invalid manifest or empty CSS")
        }

        // Create package URL based on manifest ID
        let packageURL = templatesDirectory.appendingPathComponent("\(package.manifest.id).mcvt")

        // Encode and write package
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(package)
            try data.write(to: packageURL)
        } catch {
            throw TemplateRepositoryError.ioError("Failed to write package to disk: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Methods

    private func createTemplatesDirectoryIfNeeded() {
        guard !fileManager.fileExists(atPath: templatesDirectory.path) else {
            return
        }

        do {
            try fileManager.createDirectory(
                at: templatesDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            // Directory creation failure will be caught when attempting to read
        }
    }

    private func loadPackage(from url: URL) throws -> TemplatePackage {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let package = try decoder.decode(TemplatePackage.self, from: data)

            guard package.isValid else {
                throw TemplateRepositoryError.invalidPackage("Package at \(url.lastPathComponent) failed validation")
            }

            return package
        } catch let error as DecodingError {
            throw TemplateRepositoryError.invalidPackage("Failed to decode package: \(error.localizedDescription)")
        } catch {
            throw TemplateRepositoryError.ioError("Failed to read package file: \(error.localizedDescription)")
        }
    }

    private func convertToTemplate(_ package: TemplatePackage, previewPath: String) throws -> Template {
        let manifest = package.manifest

        // If package has custom HTML, use it directly
        // Otherwise, we'll use CSS-only approach with base template (to be implemented later)
        let htmlContent = package.htmlContent ?? createBaseHTMLWithCSS(package.cssContent)

        // Convert preview path to URL
        // Preview path is relative to Application Support (e.g., "TemplateCache/professional_preview.png")
        let previewURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(previewPath)

        return Template(
            id: manifest.id,
            name: manifest.name,
            description: manifest.description,
            htmlContent: htmlContent,
            thumbnailURL: previewURL,
            isPremium: !manifest.isFree
        )
    }

    private func createBaseHTMLWithCSS(_ css: String) -> String {
        // TODO: This will be replaced with proper base template + CSS injection
        // For now, create a minimal HTML structure with the CSS embedded
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <style>
            \(css)
            </style>
        </head>
        <body>
            <div class="cv-container">
                <header class="cv-header">
                    <h1>{{name}}</h1>
                    <div class="contact-info">
                        <span>{{email}}</span>
                        {{#hasPhone}}<span>{{phone}}</span>{{/hasPhone}}
                        {{#hasLocation}}<span>{{location}}</span>{{/hasLocation}}
                        {{#hasWebsite}}<a href="{{website}}">{{website}}</a>{{/hasWebsite}}
                    </div>
                    {{#hasSummary}}
                    <div class="summary">
                        <p>{{summary}}</p>
                    </div>
                    {{/hasSummary}}
                </header>

                {{#hasWorkExperience}}
                <section class="work-experience">
                    <h2>Work Experience</h2>
                    {{#workExperience}}
                    <div class="experience-item">
                        <h3>{{title}}</h3>
                        <div class="subtitle">{{subtitle}}</div>
                        <div class="date-location">
                            <span>{{startDate}} - {{endDate}}</span>
                            <span>{{location}}</span>
                        </div>
                        <p>{{description}}</p>
                    </div>
                    {{/workExperience}}
                </section>
                {{/hasWorkExperience}}

                {{#hasEducation}}
                <section class="education">
                    <h2>Education</h2>
                    {{#education}}
                    <div class="education-item">
                        <h3>{{title}}</h3>
                        <div class="subtitle">{{subtitle}}</div>
                        <div class="date">{{startDate}} - {{endDate}}</div>
                    </div>
                    {{/education}}
                </section>
                {{/hasEducation}}

                {{#hasSkills}}
                <section class="skills">
                    <h2>Skills</h2>
                    <div class="skills-list">
                        {{#skills}}
                        <div class="skill-item">
                            <span class="skill-name">{{title}}</span>
                            {{#tags}}
                            <span class="skill-tag">{{.}}</span>
                            {{/tags}}
                        </div>
                        {{/skills}}
                    </div>
                </section>
                {{/hasSkills}}

                {{#hasLanguages}}
                <section class="languages">
                    <h2>Languages</h2>
                    {{#languages}}
                    <div class="language-item">
                        <span>{{title}}</span>
                        <span>{{description}}</span>
                    </div>
                    {{/languages}}
                </section>
                {{/hasLanguages}}

                {{#hasCertifications}}
                <section class="certifications">
                    <h2>Certifications</h2>
                    {{#certifications}}
                    <div class="certification-item">
                        <h3>{{title}}</h3>
                        <div class="subtitle">{{subtitle}}</div>
                        <div class="date">{{startDate}}</div>
                    </div>
                    {{/certifications}}
                </section>
                {{/hasCertifications}}

                {{#hasSocialLinks}}
                <section class="social-links">
                    <h2>Social Links</h2>
                    {{#socialLinks}}
                    <a href="{{url}}">{{title}}</a>
                    {{/socialLinks}}
                </section>
                {{/hasSocialLinks}}

                {{#hasInterests}}
                <section class="interests">
                    <h2>Interests</h2>
                    <div class="interests-list">
                        {{#interests}}
                        <span class="interest-tag">{{title}}</span>
                        {{/interests}}
                    </div>
                </section>
                {{/hasInterests}}
            </div>
        </body>
        </html>
        """
    }
}
