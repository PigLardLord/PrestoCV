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
        #expect(result.contains("Work experience"))
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

    // MARK: - Built-in Languages

    private static let allPlaceholders = [
        "{{i18n_work_experience}}", "{{i18n_education}}", "{{i18n_skills}}", "{{i18n_languages}}",
        "{{i18n_certifications}}", "{{i18n_social_links}}", "{{i18n_interests}}", "{{i18n_summary}}",
        "{{i18n_present}}", "{{i18n_native}}", "{{i18n_at}}",
    ]

    private static let expectedHeadings: [(language: String, headings: [String])] = [
        ("en", ["Work experience", "Education", "Skills", "Languages", "Certifications", "Profiles", "Interests", "Profile", "Present", "Native", "at"]),
        ("it", ["Esperienza professionale", "Formazione", "Competenze", "Lingue", "Certificazioni", "Profili", "Interessi", "Profilo professionale", "Oggi", "Madrelingua", "presso"]),
        ("de", ["Berufserfahrung", "Ausbildung", "Kenntnisse", "Sprachen", "Zertifikate", "Profile", "Interessen", "Kurzprofil", "Heute", "Muttersprache", "bei"]),
        ("es", ["Experiencia laboral", "Formación", "Competencias", "Idiomas", "Certificaciones", "Perfiles", "Intereses", "Perfil profesional", "Actualidad", "Lengua materna", "en"]),
        ("fr", ["Expérience professionnelle", "Formation", "Compétences", "Langues", "Certifications", "Profils", "Centres d’intérêt", "Profil professionnel", "Aujourd’hui", "Langue maternelle", "chez"]),
        ("pt", ["Experiência profissional", "Formação", "Competências", "Idiomas", "Certificações", "Perfis", "Interesses", "Perfil profissional", "Presente", "Língua materna", "em"]),
    ]

    @Test("Each built-in language has its own headings for every placeholder", arguments: expectedHeadings.map(\.language))
    func builtInLanguageHeadings(language: String) throws {
        // Given
        let expected = try #require(Self.expectedHeadings.first { $0.language == language }).headings
        let template = Self.allPlaceholders.joined(separator: "|")

        // When
        let result = TemplateLocalizer(locale: Locale(identifier: language)).localize(template: template)

        // Then
        #expect(result == expected.joined(separator: "|"))
    }

    @Test("A regional variant uses the headings of its language")
    func regionalVariantUsesItsLanguage() {
        let template = "{{i18n_education}}"

        #expect(TemplateLocalizer(locale: Locale(identifier: "pt-BR")).localize(template: template) == "Formação")
        #expect(TemplateLocalizer(locale: Locale(identifier: "de_CH")).localize(template: template) == "Ausbildung")
    }

    @Test("A language without headings falls back to English")
    func unsupportedLanguageFallsBackToEnglish() {
        let result = TemplateLocalizer(locale: Locale(identifier: "ja")).localize(template: "{{i18n_education}}")

        #expect(result == "Education")
    }

    @Test("The default locale gives English, whatever the language of the device")
    func defaultLocaleIsEnglish() {
        #expect(TemplateLocalizer().localize(template: "{{i18n_education}}") == "Education")
    }

    @Test("The level of a native speaker is named in each language", arguments: [
        ("en", "Native"), ("it", "Madrelingua"), ("de", "Muttersprache"),
        ("es", "Lengua materna"), ("fr", "Langue maternelle"), ("pt", "Língua materna"),
    ])
    func nativeLevelName(language: String, expected: String) {
        #expect(TemplateLocalizer(locale: Locale(identifier: language)).nativeLevelName == expected)
    }
}
