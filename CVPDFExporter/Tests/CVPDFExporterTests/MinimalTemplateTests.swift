import Testing
import Foundation
@testable import CVPDFExporter

// MARK: - Minimal Template Tests (Sprint 3)

@Suite("Minimal Template")
struct MinimalTemplateTests {

    @Test("Minimal template loads successfully")
    func minimalTemplateLoads() throws {
        // Given
        let repository = BundledTemplateRepository()

        // When
        let template = try repository.loadTemplate(id: "minimal")

        // Then
        #expect(template.id == "minimal")
        #expect(template.name == "Minimal")
        #expect(template.description.contains("Simple"))
    }

    @Test("Minimal template has clean structure")
    func minimalTemplateStructure() throws {
        // Given
        let repository = BundledTemplateRepository()
        let template = try repository.loadTemplate(id: "minimal")

        // Then
        #expect(template.htmlContent.contains("<!DOCTYPE html>"))
        #expect(template.htmlContent.contains("<style>"))
        #expect(template.htmlContent.contains("{{name}}"))
        #expect(template.htmlContent.contains("{{email}}"))
        // Minimal template should have simple, clean styling
        #expect(!template.htmlContent.contains("gradient"))  // No fancy gradients
    }

    @Test("Minimal template renders personal info")
    func minimalTemplateRendersPersonalInfo() async throws {
        // Given
        let engine = MustacheTemplateEngine()
        let repository = BundledTemplateRepository()
        let template = try repository.loadTemplate(id: "minimal")

        let document = CVDocument(
            personalInfo: PersonalInfo(
                name: "John Minimalist",
                email: "john@simple.com",
                phone: "+1 234 567 890",
                location: "New York, NY",
                summary: "Clean and focused professional"
            ),
            sections: [],
            metadata: DocumentMetadata()
        )

        let customization = CustomizationOptions(colorPalette: .minimal, fontScheme: .serif)

        // When
        let rendered = try await engine.render(template: template, data: document, customization: customization)

        // Then
        #expect(rendered.contains("John Minimalist"))
        #expect(rendered.contains("john@simple.com"))
        #expect(rendered.contains("+1 234 567 890"))
        #expect(rendered.contains("New York, NY"))
        #expect(rendered.contains("Clean and focused"))
    }

    @Test("Minimal template renders work experience")
    func minimalTemplateRendersWorkExperience() async throws {
        // Given
        let engine = MustacheTemplateEngine()
        let repository = BundledTemplateRepository()
        let template = try repository.loadTemplate(id: "minimal")

        let document = CVDocument(
            personalInfo: PersonalInfo(name: "John Minimalist", email: "john@simple.com"),
            sections: [
                CVSection(
                    id: "work",
                    type: .work,
                    title: "Experience",
                    items: [
                        CVItem(
                            title: "Software Engineer",
                            subtitle: "Simple Corp",
                            description: "Built clean software",
                            startDate: "2020",
                            endDate: "2023"
                        )
                    ]
                )
            ],
            metadata: DocumentMetadata()
        )

        let customization = CustomizationOptions()

        // When
        let rendered = try await engine.render(template: template, data: document, customization: customization)

        // Then
        #expect(rendered.contains("Software Engineer"))
        #expect(rendered.contains("Simple Corp"))
        #expect(rendered.contains("2020"))
        #expect(rendered.contains("2023"))
    }

    @Test("Minimal template applies customization")
    func minimalTemplateAppliesCustomization() async throws {
        // Given
        let engine = MustacheTemplateEngine()
        let repository = BundledTemplateRepository()
        let template = try repository.loadTemplate(id: "minimal")

        let document = CVDocument(
            personalInfo: PersonalInfo(name: "John Minimalist", email: "john@simple.com"),
            sections: [],
            metadata: DocumentMetadata()
        )

        let customization = CustomizationOptions(
            colorPalette: .minimal,
            fontScheme: .serif
        )

        // When
        let rendered = try await engine.render(template: template, data: document, customization: customization)

        // Then
        // Check minimal palette colors (black and white)
        #expect(rendered.contains("#000000"))  // Minimal primary/text
        #expect(rendered.contains("#FFFFFF"))  // Minimal background

        // Check serif font scheme
        #expect(rendered.contains("Georgia") || rendered.contains("serif"))
    }

    @Test("Minimal template has clean typography")
    func minimalTemplateHasCleanTypography() throws {
        // Given
        let repository = BundledTemplateRepository()
        let template = try repository.loadTemplate(id: "minimal")

        // Then
        // Should have minimal decorations
        #expect(!template.htmlContent.contains("text-transform: uppercase"))
        #expect(template.htmlContent.contains("border-bottom") || template.htmlContent.contains("border-top"))
    }

    @Test("Minimal template supports all sections")
    func minimalTemplateSupportsAllSections() async throws {
        // Given
        let engine = MustacheTemplateEngine()
        let repository = BundledTemplateRepository()
        let template = try repository.loadTemplate(id: "minimal")

        let document = CVDocument(
            personalInfo: PersonalInfo(name: "John Minimalist", email: "john@simple.com"),
            sections: [
                CVSection(
                    id: "work",
                    type: .work,
                    title: "Experience",
                    items: [CVItem(title: "Engineer", subtitle: "Company")]
                ),
                CVSection(
                    id: "edu",
                    type: .education,
                    title: "Education",
                    items: [CVItem(title: "BS Computer Science", subtitle: "University")]
                ),
                CVSection(
                    id: "skills",
                    type: .skills,
                    title: "Skills",
                    items: [CVItem(title: "Programming", tags: ["Swift", "Python"])]
                )
            ],
            metadata: DocumentMetadata()
        )

        let customization = CustomizationOptions()

        // When
        let rendered = try await engine.render(template: template, data: document, customization: customization)

        // Then
        #expect(rendered.contains("Experience"))
        #expect(rendered.contains("Education"))
        #expect(rendered.contains("Skills") || rendered.contains("Programming"))
    }
}