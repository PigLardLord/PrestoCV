import Foundation

/// Outbound port (R3): the heading tables as raw JSON, read where the platform keeps them, so that the rendering reads
/// no bundle (R18, ADR 0026). The catalog decodes and checks what the source returns; the source only reads it.
public protocol HeadingTableSource: Sendable {
    /// The index: a JSON array of the language tags that have a table.
    func index() throws -> Data
    /// The table of one language tag, which the catalog has already matched against BCP 47 and lowercased; nil when the
    /// language has no table.
    func table(_ tag: String) throws -> Data?
}

/// Heading translations, one JSON table per language plus an index, looked up in the document's language with BCP 47
/// matching: the full tag, then the full primary language subtag. An unsupported language is an error, never a silent
/// fallback to English (R13).
public struct HeadingsCatalog: Sendable {
    public enum Failure: Error, Equatable { case unsupportedLanguage(String), incomplete(language: String, key: String), corruptTable(String) }
    static let keys = ["experience", "education", "skills", "languages", "certifications", "profiles", "interests", "summary", "present", "native"]
    let source: any HeadingTableSource

    public init(source: any HeadingTableSource) { self.source = source }

    public func headings(for language: String) throws(Failure) -> Headings {
        guard language.fullyMatches(#"[A-Za-z]{2,3}(-[A-Za-z0-9]{2,8}){0,3}"#) else { throw .unsupportedLanguage(language) }
        let primary = String(language.prefix { $0 != "-" }).lowercased()
        for candidate in [language.lowercased(), primary] {
            if let table = try table(candidate) { return try Self.headings(table, language: candidate) }
        }
        throw .unsupportedLanguage(language)
    }

    /// Languages with a table, from the source's index; used by the completeness test and the UI picker.
    public func supportedLanguages() throws(Failure) -> [String] {
        do { return try JSONDecoder().decode([String].self, from: source.index()) } catch { throw .corruptTable("index") }
    }

    /// nil only when the language has no table; a table that exists but cannot be read is an error (R7).
    func table(_ tag: String) throws(Failure) -> [String: String]? {
        let data: Data?
        do { data = try source.table(tag) } catch { throw .corruptTable(tag) }
        guard let data else { return nil }
        do { return try JSONDecoder().decode([String: String].self, from: data) } catch { throw .corruptTable(tag) }
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
