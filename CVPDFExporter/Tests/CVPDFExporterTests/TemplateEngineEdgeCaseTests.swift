import Testing
import Foundation
@testable import CVPDFExporter

@Suite("TemplateEngine Edge Cases")
struct TemplateEngineEdgeCaseTests {

    @Test("Should handle nested skill arrays correctly")
    func test_renderTemplate_withNestedSkills_rendersCorrectly() async throws {
        // Given - This was the bug we fixed!
        let engine = MustacheTemplateEngine()
        let template = Template(
            id: "test",
            name: "Test",
            description: "Test template with skills",
            htmlContent: """
            <div>
            {{#skills}}
                <div class="skill-category">
                    <h3>{{title}}</h3>
                    <div class="tags">
                    {{#tags}}
                        <span>{{.}}</span>
                    {{/tags}}
                    </div>
                </div>
            {{/skills}}
            </div>
            """,
            supportedVariables: ["skills"]
        )

        let document = CVDocument(
            personalInfo: PersonalInfo(name: "John Doe", email: "john@example.com"),
            sections: [
                CVSection(
                    type: .skills,
                    title: "Skills",
                    items: [
                        CVItem(
                            title: "Programming",
                            tags: ["Swift", "SwiftUI", "UIKit"]
                        ),
                        CVItem(
                            title: "Databases",
                            tags: ["PostgreSQL", "Redis", "MongoDB"]
                        )
                    ]
                )
            ]
        )

        // When
        let result = try await engine.render(
            template: template,
            data: document,
            customization: CustomizationOptions()
        )

        // Then - Verify skills are rendered, not the person's name!
        #expect(result.contains("Programming"))
        #expect(result.contains("Swift"))
        #expect(result.contains("SwiftUI"))
        #expect(result.contains("Databases"))
        #expect(result.contains("PostgreSQL"))
        #expect(!result.contains("John Doe")) // Should NOT contain the name in skills section
    }

    @Test("Should handle empty arrays gracefully")
    func test_renderTemplate_withEmptyArrays_rendersCorrectly() async throws {
        // Given
        let engine = MustacheTemplateEngine()
        let template = Template(
            id: "test",
            name: "Test",
            description: "Test template",
            htmlContent: """
            {{#hasSkills}}
            <div>Has skills</div>
            {{/hasSkills}}
            {{^hasSkills}}
            <div>No skills</div>
            {{/hasSkills}}
            """,
            supportedVariables: ["hasSkills"]
        )

        let document = CVDocument(
            personalInfo: PersonalInfo(name: "John", email: "john@example.com"),
            sections: [] // No sections
        )

        // When
        let result = try await engine.render(
            template: template,
            data: document,
            customization: CustomizationOptions()
        )

        // Then
        #expect(result.contains("No skills"))
        #expect(!result.contains("Has skills"))
    }

    @Test("Should handle deeply nested conditionals")
    func test_renderTemplate_withNestedConditionals_rendersCorrectly() async throws {
        // Given
        let engine = MustacheTemplateEngine()
        let template = Template(
            id: "test",
            name: "Test",
            description: "Test nested conditionals",
            htmlContent: """
            {{#hasWorkExperience}}
                {{#workExperience}}
                    <h3>{{title}}</h3>
                    <p>{{description}}</p>
                {{/workExperience}}
            {{/hasWorkExperience}}
            """,
            supportedVariables: ["hasWorkExperience", "workExperience", "title", "description"]
        )

        let document = CVDocument(
            personalInfo: PersonalInfo(name: "John", email: "john@example.com"),
            sections: [
                CVSection(
                    type: .work,
                    title: "Experience",
                    items: [
                        CVItem(
                            title: "Developer",
                            subtitle: "Tech Corp",
                            description: "Built amazing things"
                        )
                    ]
                )
            ]
        )

        // When
        let result = try await engine.render(
            template: template,
            data: document,
            customization: CustomizationOptions()
        )

        // Then
        #expect(result.contains("Developer"))
        #expect(result.contains("Built amazing things"))
    }

    @Test("Should handle special characters in template variables")
    func test_renderTemplate_withSpecialCharacters_escapesCorrectly() async throws {
        // Given
        let engine = MustacheTemplateEngine()
        let template = Template(
            id: "test",
            name: "Test",
            description: "Test special characters",
            htmlContent: "<div>{{summary}}</div>",
            supportedVariables: ["summary"]
        )

        let document = CVDocument(
            personalInfo: PersonalInfo(
                name: "John",
                email: "john@example.com",
                summary: "Expert in <HTML> & \"JavaScript\" with 5+ years' experience"
            )
        )

        // When
        let result = try await engine.render(
            template: template,
            data: document,
            customization: CustomizationOptions()
        )

        // Then
        #expect(result.contains("&lt;HTML&gt;")) // < should be escaped
        #expect(result.contains("&quot;JavaScript&quot;")) // " should be escaped
        #expect(result.contains("&#39;")) // ' should be escaped
    }

    @Test("Should handle missing template variables gracefully")
    func test_renderTemplate_withMissingVariables_rendersEmpty() async throws {
        // Given
        let engine = MustacheTemplateEngine()
        let template = Template(
            id: "test",
            name: "Test",
            description: "Test missing variables",
            htmlContent: """
            <div>
                Name: {{name}}
                Missing: {{nonExistentVariable}}
                Email: {{email}}
            </div>
            """,
            supportedVariables: ["name", "email", "nonExistentVariable"]
        )

        let document = CVDocument(
            personalInfo: PersonalInfo(name: "John", email: "john@example.com")
        )

        // When
        let result = try await engine.render(
            template: template,
            data: document,
            customization: CustomizationOptions()
        )

        // Then
        #expect(result.contains("Name: John"))
        #expect(result.contains("Email: john@example.com"))
        #expect(!result.contains("{{nonExistentVariable}}")) // Should be removed
        #expect(result.contains("Missing:")) // Text remains but variable is empty
    }

    @Test("Should handle array iteration with index")
    func test_renderTemplate_withArrayIndex_rendersWithNumbers() async throws {
        // Given
        let engine = MustacheTemplateEngine()
        let template = Template(
            id: "test",
            name: "Test",
            description: "Test array with index",
            htmlContent: """
            {{#workExperience}}
            <div>{{title}}</div>
            {{/workExperience}}
            """,
            supportedVariables: ["workExperience"]
        )

        let document = CVDocument(
            personalInfo: PersonalInfo(name: "John", email: "john@example.com"),
            sections: [
                CVSection(
                    type: .work,
                    title: "Experience",
                    items: [
                        CVItem(title: "First Job"),
                        CVItem(title: "Second Job"),
                        CVItem(title: "Third Job")
                    ]
                )
            ]
        )

        // When
        let result = try await engine.render(
            template: template,
            data: document,
            customization: CustomizationOptions()
        )

        // Then
        #expect(result.contains("First Job"))
        #expect(result.contains("Second Job"))
        #expect(result.contains("Third Job"))
    }

    @Test("Should handle customization options correctly")
    func test_renderTemplate_withCustomization_appliesStyles() async throws {
        // Given
        let engine = MustacheTemplateEngine()
        let template = Template(
            id: "test",
            name: "Test",
            description: "Test customization",
            htmlContent: """
            <style>
                .primary { color: {{colorPrimary}}; }
                body { font-family: {{fontBody}}; }
            </style>
            """,
            supportedVariables: ["colorPrimary", "fontBody"]
        )

        let document = CVDocument(
            personalInfo: PersonalInfo(name: "John", email: "john@example.com")
        )

        let customization = CustomizationOptions(
            colorPalette: .modern,
            fontScheme: .serif
        )

        // When
        let result = try await engine.render(
            template: template,
            data: document,
            customization: customization
        )

        // Then
        #expect(result.contains("#1E293B")) // Modern primary color (dark slate)
        #expect(result.contains("Georgia")) // Serif font
    }

    @Test("Should handle boolean flags correctly")
    func test_renderTemplate_withBooleanFlags_showsConditionalContent() async throws {
        // Given
        let engine = MustacheTemplateEngine()
        let template = Template(
            id: "test",
            name: "Test",
            description: "Test boolean flags",
            htmlContent: """
            {{#hasPhone}}<div>Phone: {{phone}}</div>{{/hasPhone}}
            {{#hasWebsite}}<div>Website: {{website}}</div>{{/hasWebsite}}
            {{#hasLocation}}<div>Location: {{location}}</div>{{/hasLocation}}
            """,
            supportedVariables: ["hasPhone", "phone", "hasWebsite", "website", "hasLocation", "location"]
        )

        let document = CVDocument(
            personalInfo: PersonalInfo(
                name: "John",
                email: "john@example.com",
                phone: "+1234567890",
                location: "San Francisco",
                website: nil // No website
            )
        )

        // When
        let result = try await engine.render(
            template: template,
            data: document,
            customization: CustomizationOptions()
        )

        // Then
        #expect(result.contains("Phone: +1234567890"))
        #expect(result.contains("Location: San Francisco"))
        #expect(!result.contains("Website:")) // No website section
    }
}