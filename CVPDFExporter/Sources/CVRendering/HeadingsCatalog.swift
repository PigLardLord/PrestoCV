import Foundation

/// Heading translations are package resources (JSON per language), looked up in the document's
/// language with BCP 47 matching: the full tag, then the full primary language subtag. An unsupported
/// language is an error, never a silent fallback to English (R13).
public enum HeadingsCatalog {
    public enum Failure: Error, Equatable { case unsupportedLanguage(String), incomplete(language: String, key: String), corruptTable(String) }
    static let keys = ["experience", "education", "skills", "languages", "certifications", "profiles", "interests", "summary", "present", "native"]

    public static func headings(for language: String) throws(Failure) -> Headings {
        guard language.fullyMatches(#"[A-Za-z]{2,3}(-[A-Za-z0-9]{2,8}){0,3}"#) else { throw .unsupportedLanguage(language) }
        let primary = String(language.prefix { $0 != "-" }).lowercased()
        for candidate in [language.lowercased(), primary] {
            if let table = try table(candidate) { return try headings(table, language: candidate) }
        }
        throw .unsupportedLanguage(language)
    }

    /// Languages with a table, from the package's own index; used by the completeness test and the UI picker.
    public static func supportedLanguages() throws(Failure) -> [String] {
        guard let url = Bundle.module.url(forResource: "Headings/index", withExtension: "json") else { throw .corruptTable("index") }
        do { return try JSONDecoder().decode([String].self, from: Data(contentsOf: url)) } catch { throw .corruptTable("index") }
    }

    /// nil only when the language has no table; a table that exists but cannot be read is an error (R7).
    static func table(_ tag: String) throws(Failure) -> [String: String]? {
        guard let url = Bundle.module.url(forResource: "Headings/\(tag)", withExtension: "json") else { return nil }
        do { return try JSONDecoder().decode([String: String].self, from: Data(contentsOf: url)) } catch { throw .corruptTable(tag) }
    }

    static func headings(_ d: [String: String], language: String) throws(Failure) -> Headings {
        func v(_ k: String) throws(Failure) -> String {
            guard let s = d[k], !s.isEmpty else { throw .incomplete(language: language, key: k) }
            return s
        }
        return Headings(experience: try v("experience"), education: try v("education"), skills: try v("skills"),
                        languages: try v("languages"), certifications: try v("certifications"), profiles: try v("profiles"), interests: try v("interests"),
                        summary: try v("summary"), present: try v("present"), native: try v("native"))
    }
}
