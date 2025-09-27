import Testing
import Foundation
@testable import CVPDFExporter

// MARK: - Template Engine Tests (Sprint 1)

@Suite("Template Engine")
struct TemplateEngineTests {

    // MARK: - Template Loading Tests

    @Test("Load bundled template")
    func loadBundledTemplate() throws {
        // Given
        let repository = BundledTemplateRepository()

        // When
        let template = try repository.loadTemplate(id: "professional")

        // Then
        #expect(template.id == "professional")
        #expect(template.name == "Professional")
        #expect(template.htmlContent.contains("<!DOCTYPE html>"))
    }

    @Test("Load non-existent template throws error")
    func loadNonExistentTemplate() {
        // Given
        let repository = BundledTemplateRepository()

        // When/Then
        #expect(throws: TemplateError.self) {
            _ = try repository.loadTemplate(id: "nonexistent")
        }
    }

    @Test("List available templates")
    func listAvailableTemplates() {
        // Given
        let repository = BundledTemplateRepository()

        // When
        let available = repository.availableTemplates()

        // Then
        #expect(available.count >= 3)
        #expect(available.contains { $0.id == "professional" })
        #expect(available.contains { $0.id == "modern" })
        #expect(available.contains { $0.id == "minimal" })
    }

    // MARK: - Mustache Rendering Tests

    @Test("Simple variable replacement")
    func simpleVariableReplacement() async throws {
        // Given
        let engine = MustacheTemplateEngine()
        let template = Template(
            id: "test",
            name: "Test",
            description: "",
            htmlContent: "<h1>{{name}}</h1><p>{{email}}</p>",
            supportedVariables: ["name", "email"]
        )
        let document = CVDocument(
            personalInfo: PersonalInfo(name: "John Doe", email: "john@example.com"),
            sections: [],
            metadata: DocumentMetadata()
        )
        let customization = CustomizationOptions()

        // When
        let rendered = try await engine.render(template: template, data: document, customization: customization)

        // Then
        #expect(rendered.contains("John Doe"))
        #expect(rendered.contains("john@example.com"))
        #expect(!rendered.contains("{{"))  // No unreplaced variables
    }

    @Test("Conditional sections")
    func conditionalSections() async throws {
        // Given
        let engine = MustacheTemplateEngine()
        let template = Template(
            id: "test",
            name: "Test",
            description: "",
            htmlContent: """
            {{#hasSummary}}
            <p>{{summary}}</p>
            {{/hasSummary}}
            {{^hasSummary}}
            <p>No summary provided</p>
            {{/hasSummary}}
            """,
            supportedVariables: ["hasSummary", "summary"]
        )
        let customization = CustomizationOptions()

        // Test with summary
        let docWithSummary = CVDocument(
            personalInfo: PersonalInfo(name: "John", email: "john@example.com", summary: "Expert developer"),
            sections: [],
            metadata: DocumentMetadata()
        )
        let rendered1 = try await engine.render(template: template, data: docWithSummary, customization: customization)
        #expect(rendered1.contains("Expert developer"))
        #expect(!rendered1.contains("No summary provided"))

        // Test without summary
        let docWithoutSummary = CVDocument(
            personalInfo: PersonalInfo(name: "John", email: "john@example.com"),
            sections: [],
            metadata: DocumentMetadata()
        )
        let rendered2 = try await engine.render(template: template, data: docWithoutSummary, customization: customization)
        #expect(rendered2.contains("No summary provided"))
        #expect(!rendered2.contains("Expert developer"))
    }

    @Test("Looping sections")
    func loopingSections() async throws {
        // Given
        let engine = MustacheTemplateEngine()
        let template = Template(
            id: "test",
            name: "Test",
            description: "",
            htmlContent: """
            {{#workExperience}}
            <div class="job">
                <h3>{{title}} at {{company}}</h3>
                <p>{{description}}</p>
            </div>
            {{/workExperience}}
            """,
            supportedVariables: ["workExperience"]
        )
        let customization = CustomizationOptions()

        let document = CVDocument(
            personalInfo: PersonalInfo(name: "John", email: "john@example.com"),
            sections: [
                CVSection(
                    id: "work",
                    type: .work,
                    title: "Experience",
                    items: [
                        CVItem(title: "Developer", subtitle: "Tech Corp", description: "Built apps"),
                        CVItem(title: "Engineer", subtitle: "StartupXYZ", description: "Created products")
                    ]
                )
            ],
            metadata: DocumentMetadata()
        )

        // When
        let rendered = try await engine.render(template: template, data: document, customization: customization)

        // Then
        #expect(rendered.contains("Developer"))
        #expect(rendered.contains("Tech Corp"))
        #expect(rendered.contains("Built apps"))
        #expect(rendered.contains("Engineer"))
        #expect(rendered.contains("StartupXYZ"))
    }

    @Test("HTML escaping")
    func htmlEscaping() async throws {
        // Given
        let engine = MustacheTemplateEngine()
        let template = Template(
            id: "test",
            name: "Test",
            description: "",
            htmlContent: "<p>{{summary}}</p>",
            supportedVariables: ["summary"]
        )
        let customization = CustomizationOptions()

        let document = CVDocument(
            personalInfo: PersonalInfo(
                name: "John",
                email: "john@example.com",
                summary: "Expert in <script> & HTML"
            ),
            sections: [],
            metadata: DocumentMetadata()
        )

        // When
        let rendered = try await engine.render(template: template, data: document, customization: customization)

        // Then
        // Normal variable should be escaped
        #expect(rendered.contains("&lt;script&gt;"))
        #expect(rendered.contains("&amp;"))
    }

    @Test("Customization colors are applied")
    func customizationColorsApplied() async throws {
        // Given
        let engine = MustacheTemplateEngine()
        let template = Template(
            id: "test",
            name: "Test",
            description: "",
            htmlContent: """
            <style>
                :root {
                    --color-primary: {{colorPrimary}};
                    --color-accent: {{colorAccent}};
                }
            </style>
            """,
            supportedVariables: ["colorPrimary", "colorAccent"]
        )
        let document = CVDocument(
            personalInfo: PersonalInfo(name: "John", email: "john@example.com"),
            sections: [],
            metadata: DocumentMetadata()
        )
        let customization = CustomizationOptions(colorPalette: .modern)

        // When
        let rendered = try await engine.render(template: template, data: document, customization: customization)

        // Then
        #expect(rendered.contains("#1E293B"))  // Modern primary color
        #expect(rendered.contains("#0EA5E9"))  // Modern accent color
    }

    @Test("Customization fonts are applied")
    func customizationFontsApplied() async throws {
        // Given
        let engine = MustacheTemplateEngine()
        let template = Template(
            id: "test",
            name: "Test",
            description: "",
            htmlContent: """
            <style>
                body {
                    font-family: {{fontBody}};
                    font-size: {{fontSize}};
                }
                h1 {
                    font-family: {{fontHeading}};
                }
            </style>
            """,
            supportedVariables: ["fontBody", "fontHeading", "fontSize"]
        )
        let document = CVDocument(
            personalInfo: PersonalInfo(name: "John", email: "john@example.com"),
            sections: [],
            metadata: DocumentMetadata()
        )
        let customization = CustomizationOptions(fontScheme: .serif)

        // When
        let rendered = try await engine.render(template: template, data: document, customization: customization)

        // Then
        #expect(rendered.contains("Georgia"))  // Serif font
        #expect(rendered.contains("12pt"))     // Serif font size
    }
}