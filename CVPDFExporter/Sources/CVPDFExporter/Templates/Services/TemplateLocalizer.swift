import Foundation

/// Service for localizing i18n placeholders in CV templates
///
/// Replaces Mustache-style i18n placeholders (e.g., `{{i18n_work_experience}}`) with the headings of the
/// document's language. The headings are built in for English, Italian, German, Spanish, French and
/// Portuguese, so the language of the device never changes the result; any other language gets English.
///
/// Usage:
/// ```swift
/// let localizer = TemplateLocalizer(locale: Locale(identifier: "it"))
/// let localizedHTML = localizer.localize(template: htmlTemplate)
/// ```
public struct TemplateLocalizer: Sendable {

    /// The locale whose language selects the headings
    public let currentLocale: Locale

    /// Initialize with the locale of the document
    /// - Parameter locale: The locale whose language selects the headings (defaults to English)
    public init(locale: Locale = Locale(identifier: "en")) {
        self.currentLocale = locale
    }

    /// Localizes a template by replacing i18n placeholders with headings
    /// - Parameter template: The template string containing i18n placeholders
    /// - Returns: The template with i18n placeholders replaced by headings
    public func localize(template: String) -> String {
        var result = template

        for (placeholder, heading) in headings.replacements {
            result = result.replacingOccurrences(of: placeholder, with: heading)
        }

        return result
    }

    /// The word for a native speaker, which is printed as the level of a language
    public var nativeLevelName: String {
        headings.native
    }

    // MARK: - Headings

    private var headings: Headings {
        let languageCode = currentLocale.language.languageCode?.identifier ?? Self.defaultLanguage
        return Self.tables[languageCode] ?? Self.english
    }

    private static let defaultLanguage = "en"

    private static let tables: [String: Headings] = [
        "en": english,
        "it": italian,
        "de": german,
        "es": spanish,
        "fr": french,
        "pt": portuguese,
    ]

    /// The words of one language that the templates ask for through `{{i18n_*}}` placeholders
    private struct Headings: Sendable {
        let workExperience: String
        let education: String
        let skills: String
        let languages: String
        let certifications: String
        let socialLinks: String
        let interests: String
        let summary: String
        let present: String
        let native: String
        let at: String

        var replacements: [(placeholder: String, heading: String)] {
            [
                ("{{i18n_work_experience}}", workExperience),
                ("{{i18n_education}}", education),
                ("{{i18n_skills}}", skills),
                ("{{i18n_languages}}", languages),
                ("{{i18n_certifications}}", certifications),
                ("{{i18n_social_links}}", socialLinks),
                ("{{i18n_interests}}", interests),
                ("{{i18n_summary}}", summary),
                ("{{i18n_present}}", present),
                ("{{i18n_native}}", native),
                ("{{i18n_at}}", at),
            ]
        }
    }

    private static let english = Headings(
        workExperience: "Work experience", education: "Education", skills: "Skills", languages: "Languages",
        certifications: "Certifications", socialLinks: "Profiles", interests: "Interests", summary: "Profile",
        present: "Present", native: "Native", at: "at"
    )

    private static let italian = Headings(
        workExperience: "Esperienza professionale", education: "Formazione", skills: "Competenze", languages: "Lingue",
        certifications: "Certificazioni", socialLinks: "Profili", interests: "Interessi", summary: "Profilo professionale",
        present: "Oggi", native: "Madrelingua", at: "presso"
    )

    private static let german = Headings(
        workExperience: "Berufserfahrung", education: "Ausbildung", skills: "Kenntnisse", languages: "Sprachen",
        certifications: "Zertifikate", socialLinks: "Profile", interests: "Interessen", summary: "Kurzprofil",
        present: "Heute", native: "Muttersprache", at: "bei"
    )

    private static let spanish = Headings(
        workExperience: "Experiencia laboral", education: "Formación", skills: "Competencias", languages: "Idiomas",
        certifications: "Certificaciones", socialLinks: "Perfiles", interests: "Intereses", summary: "Perfil profesional",
        present: "Actualidad", native: "Lengua materna", at: "en"
    )

    private static let french = Headings(
        workExperience: "Expérience professionnelle", education: "Formation", skills: "Compétences", languages: "Langues",
        certifications: "Certifications", socialLinks: "Profils", interests: "Centres d’intérêt", summary: "Profil professionnel",
        present: "Aujourd’hui", native: "Langue maternelle", at: "chez"
    )

    private static let portuguese = Headings(
        workExperience: "Experiência profissional", education: "Formação", skills: "Competências", languages: "Idiomas",
        certifications: "Certificações", socialLinks: "Perfis", interests: "Interesses", summary: "Perfil profissional",
        present: "Presente", native: "Língua materna", at: "em"
    )
}
