import Testing
import Foundation
@testable import CVPDFExporter

// MARK: - Template Engine Language (headings and the lang attribute follow the document language)

@Suite("TemplateEngine Language")
struct TemplateEngineLanguageTests {

    private func render(_ html: String, language: String?) async throws -> String {
        let template = Template(id: "test", name: "Test", htmlContent: html)
        let metadata = language.map { DocumentMetadata(language: $0) } ?? DocumentMetadata()
        let document = CVDocument(personalInfo: PersonalInfo(name: "Ada", email: "ada@example.com"), metadata: metadata)
        return try await MustacheTemplateEngine().render(template: template, data: document, customization: CustomizationOptions())
    }

    @Test("Headings are printed in the language of the document", arguments: [
        ("de", "Berufserfahrung"), ("it", "Esperienza professionale"), ("es", "Experiencia laboral"),
        ("fr", "Expérience professionnelle"), ("pt", "Experiência profissional"), ("en", "Work experience"),
    ])
    func headingsFollowTheDocumentLanguage(language: String, heading: String) async throws {
        let html = try await render("<h2>{{i18n_work_experience}}</h2>", language: language)

        #expect(html == "<h2>\(heading)</h2>")
    }

    @Test("A document without a language is rendered in English")
    func defaultLanguageIsEnglish() async throws {
        let html = try await render("<h2>{{i18n_skills}}</h2>", language: nil)

        #expect(html == "<h2>Skills</h2>")
    }

    @Test("The document language is available to templates as lang")
    func langIsExposed() async throws {
        let html = try await render("<html lang=\"{{lang}}\">", language: "de")

        #expect(html == "<html lang=\"de\">")
    }

    @Test("A CV text that looks like a heading placeholder is not translated")
    func cvTextIsNotLocalized() async throws {
        let template = Template(id: "test", name: "Test", htmlContent: "<p>{{summary}}</p>")
        let info = PersonalInfo(name: "Ada", email: "ada@example.com", summary: "{{i18n_education}}")
        let document = CVDocument(personalInfo: info, metadata: DocumentMetadata(language: "de"))

        let html = try await MustacheTemplateEngine().render(template: template, data: document, customization: CustomizationOptions())

        #expect(html == "<p>&#123;&#123;i18n_education&#125;&#125;</p>")
    }
}
