import Foundation

/// Service for localizing i18n placeholders in CV templates
///
/// Replaces Mustache-style i18n placeholders (e.g., `{{i18n_work_experience}}`)
/// with localized strings based on the current locale.
///
/// Usage:
/// ```swift
/// // With main app bundle:
/// let localizer = TemplateLocalizer(bundle: .main, locale: Locale(identifier: "es"))
/// let localizedHTML = localizer.localize(template: htmlTemplate)
///
/// // With fallback strings (for testing):
/// let localizer = TemplateLocalizer(locale: Locale(identifier: "es"))
/// let localizedHTML = localizer.localize(template: htmlTemplate)
/// ```
public struct TemplateLocalizer: Sendable {

    /// The locale to use for localizations
    public let currentLocale: Locale

    /// The bundle to use for loading localized strings
    public let bundle: Bundle?

    /// Initialize with a specific locale and optional bundle
    /// - Parameters:
    ///   - bundle: The bundle containing Localizable.xcstrings (defaults to nil for fallback behavior)
    ///   - locale: The locale to use for localizations (defaults to current locale)
    public init(bundle: Bundle? = nil, locale: Locale = .current) {
        self.bundle = bundle
        self.currentLocale = locale
    }

    /// Localizes a template by replacing i18n placeholders with localized strings
    /// - Parameter template: The template string containing i18n placeholders
    /// - Returns: The template with i18n placeholders replaced by localized strings
    public func localize(template: String) -> String {
        var result = template

        // Replace all i18n placeholders with localized strings
        for (placeholder, key) in Self.i18nMappings {
            let localizedValue = localizedString(for: key)
            result = result.replacingOccurrences(of: placeholder, with: localizedValue)
        }

        return result
    }

    // MARK: - Private Helpers

    /// Mapping of i18n placeholders to localization keys
    private static let i18nMappings: [(placeholder: String, key: String)] = [
        ("{{i18n_work_experience}}", "template.work_experience"),
        ("{{i18n_education}}", "template.education"),
        ("{{i18n_skills}}", "template.skills"),
        ("{{i18n_languages}}", "template.languages"),
        ("{{i18n_certifications}}", "template.certifications"),
        ("{{i18n_social_links}}", "template.social_links"),
        ("{{i18n_interests}}", "template.interests"),
        ("{{i18n_summary}}", "template.summary"),
        ("{{i18n_contact}}", "template.contact"),
        ("{{i18n_projects}}", "template.projects"),
        ("{{i18n_at}}", "template.at"),
        ("{{i18n_present}}", "template.present"),
        ("{{i18n_proficiency}}", "template.proficiency"),
    ]

    /// Fallback localizations for English
    /// In production, these would come from Localizable.strings or .xcstrings
    private static let fallbackLocalizations: [String: String] = [
        "template.work_experience": "Work Experience",
        "template.education": "Education",
        "template.skills": "Skills",
        "template.languages": "Languages",
        "template.certifications": "Certifications",
        "template.social_links": "Social Links",
        "template.interests": "Interests",
        "template.summary": "Summary",
        "template.contact": "Contact",
        "template.projects": "Projects",
        "template.at": "at",
        "template.present": "Present",
        "template.proficiency": "Proficiency",
    ]

    /// Localized strings for Spanish
    private static let spanishLocalizations: [String: String] = [
        "template.work_experience": "Experiencia Laboral",
        "template.education": "Educación",
        "template.skills": "Habilidades",
        "template.languages": "Idiomas",
        "template.certifications": "Certificaciones",
        "template.social_links": "Redes Sociales",
        "template.interests": "Intereses",
        "template.summary": "Resumen",
        "template.contact": "Contacto",
        "template.projects": "Proyectos",
        "template.at": "en",
        "template.present": "Actualidad",
        "template.proficiency": "Dominio",
    ]
}

// MARK: - Locale-Aware Localization

extension TemplateLocalizer {
    /// Gets the localized string for a given key, respecting the current locale
    private func localizedString(for key: String) -> String {
        // Try to use Bundle localization if available
        if let bundle = bundle {
            let localizedValue = NSLocalizedString(
                key,
                tableName: "Localizable",
                bundle: bundle,
                value: "",
                comment: ""
            )

            // If NSLocalizedString returns the key, it means the key wasn't found
            // Fall back to hardcoded localizations
            if localizedValue != key && !localizedValue.isEmpty {
                return localizedValue
            }
        }

        // Fall back to hardcoded localizations for testing or when bundle is unavailable
        let languageCode = currentLocale.language.languageCode?.identifier ?? "en"

        let localizations: [String: String]
        switch languageCode {
        case "es":
            localizations = Self.spanishLocalizations
        case "en":
            localizations = Self.fallbackLocalizations
        default:
            localizations = Self.fallbackLocalizations
        }

        // Get localized string or fall back to key-based default
        let fallback = key.components(separatedBy: ".").last?
            .replacingOccurrences(of: "_", with: " ")
            .capitalized ?? key

        return localizations[key, default: fallback]
    }
}
