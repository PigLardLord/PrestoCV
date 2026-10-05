import Foundation

/// Heading translations are package resources (JSON per language), looked up in the document's
/// language with BCP 47 matching: the full tag, then the full primary language subtag. An unsupported
/// language is an error, never a silent fallback to English (LocalisationAtEdges).
public enum HeadingsCatalog {
    /// The language has no table, a table lacks a key or holds an empty value, or a table cannot be read.
    public enum Failure: Error, Equatable { case unsupportedLanguage(String), incomplete(language: String, key: String), corruptTable(String) }
    static let keys = ["experience", "education", "skills", "languages", "certifications", "profiles", "interests", "summary", "present", "native"]

    /// The headings for a document language, such as `it` or `pt-BR`.
    ///
    /// - Throws: `Failure.unsupportedLanguage` when the language is malformed or has no table, never a fallback to English.
    public static func headings(for language: String) throws(Failure) -> Headings {
        guard LanguageTag.isWellFormed(language) else { throw .unsupportedLanguage(language) }
        let primary = String(language.prefix { $0 != "-" }).lowercased()
        for candidate in [language.lowercased(), primary] {
            if let table = try table(candidate) { return try headings(table, language: candidate) }
        }
        throw .unsupportedLanguage(language)
    }

    /// Languages with a table, from the package's own index; used by the completeness test and the UI picker.
    ///
    /// - Throws: `Failure.corruptTable` when the index cannot be read.
    public static func supportedLanguages() throws(Failure) -> [String] {
        guard let url = Bundle.module.url(forResource: "Resources/Headings/index", withExtension: "json") else { throw .corruptTable("index") }
        do { return try JSONDecoder().decode([String].self, from: Data(contentsOf: url)) } catch { throw .corruptTable("index") }
    }

    /// nil only when the language has no table; a table that exists but cannot be read is an error (CleanErrors).
    static func table(_ tag: String) throws(Failure) -> [String: String]? {
        guard let url = Bundle.module.url(forResource: "Resources/Headings/\(tag)", withExtension: "json") else { return nil }
        do { return try JSONDecoder().decode([String: String].self, from: Data(contentsOf: url)) } catch { throw .corruptTable(tag) }
    }

    static func headings(_ table: [String: String], language: String) throws(Failure) -> Headings {
        func value(for key: String) throws(Failure) -> String {
            guard let text = table[key], !text.isEmpty else { throw .incomplete(language: language, key: key) }
            return text
        }
        return Headings(experience: try value(for: "experience"), education: try value(for: "education"), skills: try value(for: "skills"),
                        languages: try value(for: "languages"), certifications: try value(for: "certifications"),
                        profiles: try value(for: "profiles"), interests: try value(for: "interests"),
                        summary: try value(for: "summary"), present: try value(for: "present"), native: try value(for: "native"))
    }
}
