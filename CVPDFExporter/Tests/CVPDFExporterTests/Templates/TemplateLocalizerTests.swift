import Testing
import Foundation
@testable import CVPDFExporter

// MARK: - Template Localizer Tests (TDD)

@Suite("Template Localizer")
struct TemplateLocalizerTests {

    // MARK: - Initialization Tests

    @Test("Localizer initializes with default locale")
    func localizerInitializesWithDefaultLocale() {
        // Given/When
        let localizer = TemplateLocalizer()

        // Then
        #expect(localizer.currentLocale != nil)
    }

    @Test("Localizer can be initialized with custom locale")
    func localizerInitializesWithCustomLocale() {
        // Given
        let spanishLocale = Locale(identifier: "es")

        // When
        let localizer = TemplateLocalizer(locale: spanishLocale)

        // Then
        #expect(localizer.currentLocale.identifier == "es")
    }

    // MARK: - Basic Replacement Tests

    @Test("Localizes template with i18n placeholders")
    func localizesTemplateWithI18nPlaceholders() {
        // Given
        let localizer = TemplateLocalizer(locale: Locale(identifier: "en"))
        let template = """
        <h2>{{i18n_work_experience}}</h2>
        <p>{{i18n_education}}</p>
        """

        // When
        let result = localizer.localize(template: template)

        // Then
        #expect(!result.contains("{{i18n_work_experience}}"))
        #expect(!result.contains("{{i18n_education}}"))
        #expect(result.contains("Work Experience") || result.contains("work"))
        #expect(result.contains("Education") || result.contains("education"))
    }

    @Test("Preserves non-i18n placeholders")
    func preservesNonI18nPlaceholders() {
        // Given
        let localizer = TemplateLocalizer()
        let template = """
        <h1>{{name}}</h1>
        <p>{{i18n_work_experience}}</p>
        <p>{{email}}</p>
        """

        // When
        let result = localizer.localize(template: template)

        // Then
        #expect(result.contains("{{name}}"))
        #expect(result.contains("{{email}}"))
        #expect(!result.contains("{{i18n_work_experience}}"))
    }

    // MARK: - All CV Section Tests

    @Test("Localizes work experience section")
    func localizesWorkExperienceSection() {
        // Given
        let localizer = TemplateLocalizer()
        let template = "<h2>{{i18n_work_experience}}</h2>"

        // When
        let result = localizer.localize(template: template)

        // Then
        #expect(!result.contains("{{i18n_work_experience}}"))
    }

    @Test("Localizes education section")
    func localizesEducationSection() {
        // Given
        let localizer = TemplateLocalizer()
        let template = "<h2>{{i18n_education}}</h2>"

        // When
        let result = localizer.localize(template: template)

        // Then
        #expect(!result.contains("{{i18n_education}}"))
    }

    @Test("Localizes skills section")
    func localizesSkillsSection() {
        // Given
        let localizer = TemplateLocalizer()
        let template = "<h2>{{i18n_skills}}</h2>"

        // When
        let result = localizer.localize(template: template)

        // Then
        #expect(!result.contains("{{i18n_skills}}"))
    }

    @Test("Localizes languages section")
    func localizesLanguagesSection() {
        // Given
        let localizer = TemplateLocalizer()
        let template = "<h2>{{i18n_languages}}</h2>"

        // When
        let result = localizer.localize(template: template)

        // Then
        #expect(!result.contains("{{i18n_languages}}"))
    }

    @Test("Localizes certifications section")
    func localizesCertificationsSection() {
        // Given
        let localizer = TemplateLocalizer()
        let template = "<h2>{{i18n_certifications}}</h2>"

        // When
        let result = localizer.localize(template: template)

        // Then
        #expect(!result.contains("{{i18n_certifications}}"))
    }

    @Test("Localizes social links section")
    func localizesSocialLinksSection() {
        // Given
        let localizer = TemplateLocalizer()
        let template = "<h2>{{i18n_social_links}}</h2>"

        // When
        let result = localizer.localize(template: template)

        // Then
        #expect(!result.contains("{{i18n_social_links}}"))
    }

    @Test("Localizes interests section")
    func localizesInterestsSection() {
        // Given
        let localizer = TemplateLocalizer()
        let template = "<h2>{{i18n_interests}}</h2>"

        // When
        let result = localizer.localize(template: template)

        // Then
        #expect(!result.contains("{{i18n_interests}}"))
    }

    @Test("Localizes summary section")
    func localizesSummarySection() {
        // Given
        let localizer = TemplateLocalizer()
        let template = "<h2>{{i18n_summary}}</h2>"

        // When
        let result = localizer.localize(template: template)

        // Then
        #expect(!result.contains("{{i18n_summary}}"))
    }

    // MARK: - Multiple Placeholder Tests

    @Test("Localizes template with multiple i18n placeholders")
    func localizesTemplateWithMultiplePlaceholders() {
        // Given
        let localizer = TemplateLocalizer()
        let template = """
        <section>
            <h2>{{i18n_work_experience}}</h2>
            <h2>{{i18n_education}}</h2>
            <h2>{{i18n_skills}}</h2>
        </section>
        """

        // When
        let result = localizer.localize(template: template)

        // Then
        #expect(!result.contains("{{i18n_"))
    }

    @Test("Localizes same placeholder multiple times")
    func localizesSamePlaceholderMultipleTimes() {
        // Given
        let localizer = TemplateLocalizer()
        let template = """
        <h2>{{i18n_work_experience}}</h2>
        <p>Details about {{i18n_work_experience}}</p>
        """

        // When
        let result = localizer.localize(template: template)

        // Then
        #expect(!result.contains("{{i18n_work_experience}}"))
        // Count occurrences should be 2
        let components = result.components(separatedBy: "Work")
        #expect(components.count >= 2) // At least 2 occurrences of localized text
    }

    // MARK: - Complex Template Tests

    @Test("Localizes complete HTML template")
    func localizesCompleteHTMLTemplate() {
        // Given
        let localizer = TemplateLocalizer()
        let template = """
        <html>
        <body>
            <h1>{{name}}</h1>
            <section>
                <h2>{{i18n_work_experience}}</h2>
                {{#workExperience}}
                <div>{{title}}</div>
                {{/workExperience}}
            </section>
            <section>
                <h2>{{i18n_education}}</h2>
                {{#education}}
                <div>{{degree}}</div>
                {{/education}}
            </section>
        </body>
        </html>
        """

        // When
        let result = localizer.localize(template: template)

        // Then
        #expect(result.contains("{{name}}")) // Preserved
        #expect(result.contains("{{title}}")) // Preserved
        #expect(!result.contains("{{i18n_")) // All i18n replaced
    }

    // MARK: - Edge Case Tests

    @Test("Returns original template if no i18n placeholders")
    func returnsOriginalTemplateIfNoI18nPlaceholders() {
        // Given
        let localizer = TemplateLocalizer()
        let template = """
        <h1>{{name}}</h1>
        <p>{{email}}</p>
        """

        // When
        let result = localizer.localize(template: template)

        // Then
        #expect(result == template)
    }

    @Test("Handles empty template")
    func handlesEmptyTemplate() {
        // Given
        let localizer = TemplateLocalizer()
        let template = ""

        // When
        let result = localizer.localize(template: template)

        // Then
        #expect(result.isEmpty)
    }

    @Test("Handles template with only i18n placeholders")
    func handlesTemplateWithOnlyI18nPlaceholders() {
        // Given
        let localizer = TemplateLocalizer()
        let template = "{{i18n_work_experience}}{{i18n_education}}"

        // When
        let result = localizer.localize(template: template)

        // Then
        #expect(!result.contains("{{i18n_"))
        #expect(!result.isEmpty)
    }

    @Test("Handles malformed i18n placeholders")
    func handlesMalformedI18nPlaceholders() {
        // Given
        let localizer = TemplateLocalizer()
        let template = """
        {{i18n_work_experience}}
        {{i18n_invalid_key}}
        {{i18n_}}
        """

        // When
        let result = localizer.localize(template: template)

        // Then
        #expect(!result.contains("{{i18n_work_experience}}"))
        // Invalid keys should either remain or be removed gracefully
    }

    // MARK: - Locale-Specific Tests

    @Test("Returns different text for different locales")
    func returnsDifferentTextForDifferentLocales() {
        // Given
        let englishLocalizer = TemplateLocalizer(locale: Locale(identifier: "en"))
        let spanishLocalizer = TemplateLocalizer(locale: Locale(identifier: "es"))
        let template = "<h2>{{i18n_work_experience}}</h2>"

        // When
        let englishResult = englishLocalizer.localize(template: template)
        let spanishResult = spanishLocalizer.localize(template: template)

        // Then
        #expect(englishResult != spanishResult)
        #expect(englishResult.contains("Work") || englishResult.contains("Experience"))
        #expect(spanishResult.contains("Experiencia") || spanishResult.contains("Trabajo"))
    }

    // MARK: - Performance Tests

    @Test("Localizes large template efficiently")
    func localizesLargeTemplateEfficiently() {
        // Given
        let localizer = TemplateLocalizer()
        var largeTemplate = ""
        for _ in 0..<1000 {
            largeTemplate += "<section><h2>{{i18n_work_experience}}</h2><p>{{name}}</p></section>\n"
        }

        // When
        let result = localizer.localize(template: largeTemplate)

        // Then
        #expect(!result.contains("{{i18n_work_experience}}"))
        #expect(result.contains("{{name}}"))
    }
}
