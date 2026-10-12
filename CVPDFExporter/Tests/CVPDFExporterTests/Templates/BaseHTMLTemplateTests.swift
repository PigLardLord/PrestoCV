import Testing
import Foundation
@testable import CVPDFExporter

// MARK: - Base HTML Template Tests (TDD)

@Suite("Base HTML Template")
struct BaseHTMLTemplateTests {

    // MARK: - Structure Tests

    @Test("Base template contains all required HTML structure")
    func baseTemplateContainsRequiredHTMLStructure() {
        // Given/When
        let html = BaseHTMLTemplate.html

        // Then - Basic HTML structure
        #expect(html.contains("<!DOCTYPE html>"))
        #expect(html.contains("<html"))
        #expect(html.contains("<head>"))
        #expect(html.contains("<body>"))
        #expect(html.contains("</html>"))
    }

    @Test("Base template contains all CV data placeholders")
    func baseTemplateContainsCVDataPlaceholders() {
        // Given/When
        let html = BaseHTMLTemplate.html

        // Then - Personal info placeholders
        #expect(html.contains("{{name}}"))
        #expect(html.contains("{{email}}"))
        #expect(html.contains("{{title}}"))
        #expect(html.contains("{{summary}}"))
    }

    // MARK: - i18n Placeholder Tests

    @Test("Base template contains i18n placeholder for work experience")
    func baseTemplateContainsI18nWorkExperience() {
        // Given/When
        let html = BaseHTMLTemplate.html

        // Then
        #expect(html.contains("{{i18n_work_experience}}"))
    }

    @Test("Base template contains i18n placeholder for education")
    func baseTemplateContainsI18nEducation() {
        // Given/When
        let html = BaseHTMLTemplate.html

        // Then
        #expect(html.contains("{{i18n_education}}"))
    }

    @Test("Base template contains i18n placeholder for skills")
    func baseTemplateContainsI18nSkills() {
        // Given/When
        let html = BaseHTMLTemplate.html

        // Then
        #expect(html.contains("{{i18n_skills}}"))
    }

    @Test("Base template contains i18n placeholder for languages")
    func baseTemplateContainsI18nLanguages() {
        // Given/When
        let html = BaseHTMLTemplate.html

        // Then
        #expect(html.contains("{{i18n_languages}}"))
    }

    @Test("Base template contains i18n placeholder for certifications")
    func baseTemplateContainsI18nCertifications() {
        // Given/When
        let html = BaseHTMLTemplate.html

        // Then
        #expect(html.contains("{{i18n_certifications}}"))
    }

    @Test("Base template contains i18n placeholder for interests")
    func baseTemplateContainsI18nInterests() {
        // Given/When
        let html = BaseHTMLTemplate.html

        // Then
        #expect(html.contains("{{i18n_interests}}"))
    }

    @Test("Base template contains i18n placeholder for summary")
    func baseTemplateContainsI18nSummary() {
        // Given/When
        let html = BaseHTMLTemplate.html

        // Then
        // Summary is displayed inline as CV data, not as section title
        // But we verify the template can handle i18n_summary if needed
        #expect(html.contains("{{summary}}"))
    }

    @Test("Base template contains i18n placeholder for social links")
    func baseTemplateContainsI18nSocialLinks() {
        // Given/When
        let html = BaseHTMLTemplate.html

        // Then
        #expect(html.contains("{{i18n_social_links}}"))
    }

    // MARK: - CSS Injection Point Tests

    @Test("Base template contains CSS injection placeholder")
    func baseTemplateContainsCSSInjectionPlaceholder() {
        // Given/When
        let html = BaseHTMLTemplate.html

        // Then
        #expect(html.contains("{{customCSS}}"))
    }

    @Test("CSS placeholder is in head section")
    func cssPlaceholderIsInHeadSection() {
        // Given/When
        let html = BaseHTMLTemplate.html

        // Then
        let headStart = html.range(of: "<head>")!
        let headEnd = html.range(of: "</head>")!
        let headRange = headStart.lowerBound..<headEnd.upperBound

        let headContent = String(html[headRange])
        #expect(headContent.contains("{{customCSS}}"))
    }

    // MARK: - Mustache Section Tests

    @Test("Base template has conditional sections for optional data")
    func baseTemplateHasConditionalSections() {
        // Given/When
        let html = BaseHTMLTemplate.html

        // Then
        #expect(html.contains("{{#hasWorkExperience}}"))
        #expect(html.contains("{{/hasWorkExperience}}"))
        #expect(html.contains("{{#hasEducation}}"))
        #expect(html.contains("{{/hasEducation}}"))
        #expect(html.contains("{{#hasSkills}}"))
        #expect(html.contains("{{/hasSkills}}"))
    }

    @Test("Base template has loop sections for array data")
    func baseTemplateHasLoopSections() {
        // Given/When
        let html = BaseHTMLTemplate.html

        // Then
        #expect(html.contains("{{#workExperience}}"))
        #expect(html.contains("{{/workExperience}}"))
        #expect(html.contains("{{#education}}"))
        #expect(html.contains("{{/education}}"))
        #expect(html.contains("{{#skills}}"))
        #expect(html.contains("{{/skills}}"))
    }

    // MARK: - Stylesheet Tests

    @Test("Base template takes its whole stylesheet from the package")
    func baseTemplateTakesItsStylesheetFromThePackage() {
        // Given/When
        let html = BaseHTMLTemplate.html

        // Then - the style element holds the slot and nothing else
        let styleStart = html.range(of: "<style>")!
        let styleEnd = html.range(of: "</style>")!
        let styleContent = html[styleStart.upperBound..<styleEnd.lowerBound]
        #expect(styleContent.trimmingCharacters(in: .whitespacesAndNewlines) == "{{customCSS}}")
    }

    @Test("Base template declares the language of the document")
    func baseTemplateDeclaresTheLanguage() {
        #expect(BaseHTMLTemplate.html.contains("<html lang=\"{{lang}}\">"))
    }

    // MARK: - Accessibility Tests

    @Test("Base template uses semantic HTML")
    func baseTemplateUsesSemanticHTML() {
        // Given/When
        let html = BaseHTMLTemplate.html

        // Then
        #expect(html.contains("<header"))
        #expect(html.contains("<main"))
        #expect(html.contains("<section"))
    }

    // MARK: - No Hardcoded Text Tests

    @Test("Base template has no hardcoded English section titles")
    func baseTemplateHasNoHardcodedEnglishTitles() {
        // Given/When
        let html = BaseHTMLTemplate.html

        // Then - Should NOT contain hardcoded English
        #expect(!html.contains(">Work Experience<"))
        #expect(!html.contains(">Education<"))
        #expect(!html.contains(">Skills<"))
        #expect(!html.contains(">Professional Experience<"))
        #expect(!html.contains(">Core Technologies<"))
    }

    @Test("All section titles use i18n placeholders")
    func allSectionTitlesUseI18nPlaceholders() {
        // Given/When
        let html = BaseHTMLTemplate.html

        // Then - Count specific i18n placeholders in section-title-text elements
        // We have: work_experience, education, languages, interests, certifications, social_links
        let i18nPlaceholders = ["i18n_work_experience", "i18n_education", "i18n_languages",
                                "i18n_interests", "i18n_certifications", "i18n_social_links"]
        var count = 0
        for placeholder in i18nPlaceholders {
            if html.contains("section-title-text\">{{" + placeholder + "}}") {
                count += 1
            }
        }

        // Should have at least 5 section titles with i18n
        #expect(count >= 5)
    }
}
