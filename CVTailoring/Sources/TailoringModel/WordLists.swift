import Foundation

/// The word lists of every supported language (ADR 0013), read and validated once. The supported languages are the
/// ones the index names, each with its file, so adding a language adds a file and an index entry and changes no code.
///
/// A composition root loads the lists once and injects the value (R4).
public struct WordLists: Hashable, Sendable {
    /// The languages that have a file, in the order of the index.
    public let languages: [TailoringLanguage]
    private let lists: [TailoringLanguage: LanguageWordLists]

    /// Reads the index, then the file of each language it names. `files` returns the bytes of a language's file, or
    /// nil when it has none, which for a listed language is an error.
    init(index: Data, files: (TailoringLanguage) throws(TailoringModelError) -> Data?) throws(TailoringModelError) {
        let languages = try Self.languages(in: index)
        var lists: [TailoringLanguage: LanguageWordLists] = [:]
        for language in languages {
            guard let data = try files(language) else { throw .corruptWordList(.language(language)) }
            lists[language] = try LanguageWordLists(decoding: data, language: language)
        }
        self.languages = languages
        self.lists = lists
    }

    /// The lists of one language, or `unsupportedLanguage` when it has no file. It never falls back to another (R13).
    public func forLanguage(_ language: TailoringLanguage) throws(TailoringModelError) -> LanguageWordLists {
        guard let found = lists[language] else { throw .unsupportedLanguage }
        return found
    }

    /// The codes of the index, each one of the six and none twice.
    private static func languages(in index: Data) throws(TailoringModelError) -> [TailoringLanguage] {
        guard index.count <= WordListFormat.maxFileBytes else { throw .corruptWordList(.index) }
        let codes: [String]
        do { codes = try JSONDecoder().decode([String].self, from: index) } catch { throw .corruptWordList(.index) }
        let languages = codes.compactMap(TailoringLanguage.init(rawValue:))
        guard !codes.isEmpty, languages.count == codes.count, Set(languages).count == languages.count else { throw .corruptWordList(.index) }
        return languages
    }
}
