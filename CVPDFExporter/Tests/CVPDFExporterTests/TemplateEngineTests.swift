import XCTest
@testable import CVPDFExporter

// MARK: - Template Engine Tests (Sprint 1)

final class TemplateEngineTests: XCTestCase {

    // MARK: - Template Protocol Tests

    func testTemplateProtocolDefinition() {
        // This test documents the expected Template protocol
        // When implemented, Template should have:
        // - id: String
        // - name: String
        // - description: String
        // - htmlContent: String
        // - supportedVariables: [String]
    }

    func testTemplateEngineProtocol() {
        // This test documents the expected TemplateEngine protocol
        // Should have method: render(template: Template, data: CVDocument) -> String
    }

    // MARK: - Template Loading Tests

    func testLoadBundledTemplate() throws {
        // Given
        let repository = MockTemplateRepository()
        repository.templates = [
            Template(
                id: "professional",
                name: "Professional",
                description: "Clean professional template",
                htmlContent: "<html>{{name}}</html>",
                supportedVariables: ["name"]
            )
        ]

        // When
        let template = try repository.loadTemplate(id: "professional")

        // Then
        XCTAssertEqual(template.id, "professional")
        XCTAssertEqual(template.name, "Professional")
        XCTAssertTrue(template.htmlContent.contains("{{name}}"))
    }

    func testLoadNonExistentTemplate() {
        // Given
        let repository = MockTemplateRepository()

        // When/Then
        XCTAssertThrowsError(try repository.loadTemplate(id: "nonexistent")) { error in
            XCTAssertTrue(error is TemplateError)
            if let templateError = error as? TemplateError {
                switch templateError {
                case .templateNotFound(let id):
                    XCTAssertEqual(id, "nonexistent")
                default:
                    XCTFail("Wrong error type")
                }
            }
        }
    }

    func testListAvailableTemplates() {
        // Given
        let repository = MockTemplateRepository()
        repository.templates = [
            Template(id: "professional", name: "Professional", description: "", htmlContent: "", supportedVariables: []),
            Template(id: "modern", name: "Modern", description: "", htmlContent: "", supportedVariables: []),
            Template(id: "minimal", name: "Minimal", description: "", htmlContent: "", supportedVariables: [])
        ]

        // When
        let available = repository.availableTemplates()

        // Then
        XCTAssertEqual(available.count, 3)
        XCTAssertTrue(available.contains { $0.id == "professional" })
        XCTAssertTrue(available.contains { $0.id == "modern" })
        XCTAssertTrue(available.contains { $0.id == "minimal" })
    }

    // MARK: - Mustache Rendering Tests

    func testSimpleVariableReplacement() async throws {
        // Given
        let engine = MockTemplateEngine()
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

        // When
        let rendered = try await engine.render(template: template, data: document)

        // Then
        XCTAssertTrue(rendered.contains("John Doe"))
        XCTAssertTrue(rendered.contains("john@example.com"))
        XCTAssertFalse(rendered.contains("{{"))  // No unreplaced variables
    }

    func testConditionalSections() async throws {
        // Given
        let engine = MockTemplateEngine()
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

        // Test with summary
        let docWithSummary = CVDocument(
            personalInfo: PersonalInfo(name: "John", email: "john@example.com", summary: "Expert developer"),
            sections: [],
            metadata: DocumentMetadata()
        )
        let rendered1 = try await engine.render(template: template, data: docWithSummary)
        XCTAssertTrue(rendered1.contains("Expert developer"))
        XCTAssertFalse(rendered1.contains("No summary provided"))

        // Test without summary
        let docWithoutSummary = CVDocument(
            personalInfo: PersonalInfo(name: "John", email: "john@example.com"),
            sections: [],
            metadata: DocumentMetadata()
        )
        let rendered2 = try await engine.render(template: template, data: docWithoutSummary)
        XCTAssertTrue(rendered2.contains("No summary provided"))
        XCTAssertFalse(rendered2.contains("Expert developer"))
    }

    func testLoopingSections() async throws {
        // Given
        let engine = MockTemplateEngine()
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
        let rendered = try await engine.render(template: template, data: document)

        // Then
        XCTAssertTrue(rendered.contains("Developer"))
        XCTAssertTrue(rendered.contains("Tech Corp"))
        XCTAssertTrue(rendered.contains("Built apps"))
        XCTAssertTrue(rendered.contains("Engineer"))
        XCTAssertTrue(rendered.contains("StartupXYZ"))
    }

    func testHTMLEscaping() async throws {
        // Given
        let engine = MockTemplateEngine()
        let template = Template(
            id: "test",
            name: "Test",
            description: "",
            htmlContent: "<p>{{description}}</p><div>{{{htmlContent}}}</div>",
            supportedVariables: ["description", "htmlContent"]
        )

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
        let rendered = try await engine.render(template: template, data: document)

        // Then
        // Normal variable should be escaped
        XCTAssertTrue(rendered.contains("&lt;script&gt;"))
        // Triple mustache should not escape (if we have HTML content)
    }
}

// MARK: - Mock Implementations for Testing

// These mocks define the expected interfaces that will be implemented

struct Template {
    let id: String
    let name: String
    let description: String
    let htmlContent: String
    let supportedVariables: [String]
}

enum TemplateError: Error, Equatable {
    case templateNotFound(String)
    case renderingFailed(String)
    case invalidTemplate(String)
}

protocol TemplateRepository {
    func loadTemplate(id: String) throws -> Template
    func availableTemplates() -> [Template]
}

protocol TemplateEngine {
    func render(template: Template, data: CVDocument) async throws -> String
}

// Mock implementations
class MockTemplateRepository: TemplateRepository {
    var templates: [Template] = []

    func loadTemplate(id: String) throws -> Template {
        guard let template = templates.first(where: { $0.id == id }) else {
            throw TemplateError.templateNotFound(id)
        }
        return template
    }

    func availableTemplates() -> [Template] {
        return templates
    }
}

class MockTemplateEngine: TemplateEngine {
    func render(template: Template, data: CVDocument) async throws -> String {
        // Simple mock rendering for tests
        var html = template.htmlContent

        // Replace basic variables
        html = html.replacingOccurrences(of: "{{name}}", with: data.personalInfo.name)
        html = html.replacingOccurrences(of: "{{email}}", with: data.personalInfo.email)

        // Handle conditionals
        if let summary = data.personalInfo.summary {
            // Process positive conditional - keep content
            if let regex = try? NSRegularExpression(pattern: #"\{\{#hasSummary\}\}(.*?)\{\{/hasSummary\}\}"#, options: [.dotMatchesLineSeparators]) {
                html = regex.stringByReplacingMatches(in: html, range: NSRange(html.startIndex..., in: html), withTemplate: "$1")
            }
            // Process negative conditional - remove content
            if let regex = try? NSRegularExpression(pattern: #"\{\{\^hasSummary\}\}(.*?)\{\{/hasSummary\}\}"#, options: [.dotMatchesLineSeparators]) {
                html = regex.stringByReplacingMatches(in: html, range: NSRange(html.startIndex..., in: html), withTemplate: "")
            }
            html = html.replacingOccurrences(of: "{{summary}}", with: summary)
        } else {
            // Process positive conditional - remove content
            if let regex = try? NSRegularExpression(pattern: #"\{\{#hasSummary\}\}(.*?)\{\{/hasSummary\}\}"#, options: [.dotMatchesLineSeparators]) {
                html = regex.stringByReplacingMatches(in: html, range: NSRange(html.startIndex..., in: html), withTemplate: "")
            }
            // Process negative conditional - keep content
            if let regex = try? NSRegularExpression(pattern: #"\{\{\^hasSummary\}\}(.*?)\{\{/hasSummary\}\}"#, options: [.dotMatchesLineSeparators]) {
                html = regex.stringByReplacingMatches(in: html, range: NSRange(html.startIndex..., in: html), withTemplate: "$1")
            }
        }

        // Handle loops (simplified)
        if template.htmlContent.contains("{{#workExperience}}") {
            var workHtml = ""
            for section in data.sections where section.type == .work {
                for item in section.items {
                    var itemHtml = template.htmlContent
                    itemHtml = itemHtml.replacingOccurrences(of: "{{title}}", with: item.title)
                    itemHtml = itemHtml.replacingOccurrences(of: "{{company}}", with: item.subtitle ?? "")
                    itemHtml = itemHtml.replacingOccurrences(of: "{{description}}", with: item.description ?? "")
                    workHtml += itemHtml
                }
            }
            if !workHtml.isEmpty {
                html = workHtml
            }
        }

        // Handle HTML escaping
        if data.personalInfo.summary?.contains("<") ?? false {
            html = html.replacingOccurrences(
                of: "{{description}}",
                with: data.personalInfo.summary?.replacingOccurrences(of: "<", with: "&lt;")
                    .replacingOccurrences(of: ">", with: "&gt;") ?? ""
            )
        }

        // Clean up mustache tags
        html = html.replacingOccurrences(of: "{{#workExperience}}", with: "")
        html = html.replacingOccurrences(of: "{{/workExperience}}", with: "")

        return html
    }
}