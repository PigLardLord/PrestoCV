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
            guard let data = try files(language) else { throw .corruptWordList(.language(language), nil) }
            lists[language] = try LanguageWordLists(decoding: data, language: language)
        }
        self.languages = languages
        self.lists = lists
    }

    /// Reads the index and the files of this package's resources. The caller loads once and injects the value (R4).
    public static func load() throws(TailoringModelError) -> WordLists {
        guard let index = try WordListResources.data(named: "index", as: .index) else { throw .corruptWordList(.index, nil) }
        return try WordLists(index: index) { language throws(TailoringModelError) in
            try WordListResources.data(named: language.code, as: .language(language))
        }
    }

    /// The lists of one language, or `unsupportedLanguage` when it has no file. It never falls back to another (R13).
    public func forLanguage(_ language: TailoringLanguage) throws(TailoringModelError) -> LanguageWordLists {
        guard let found = lists[language] else { throw .unsupportedLanguage }
        return found
    }

    /// The codes of the index, each one of the six and none twice.
    private static func languages(in index: Data) throws(TailoringModelError) -> [TailoringLanguage] {
        guard index.count <= WordListFormat.maxFileBytes else { throw .corruptWordList(.index, nil) }
        let codes: [String]
        do { codes = try JSONDecoder().decode([String].self, from: index) } catch { throw .corruptWordList(.index, nil) }
        let languages = codes.compactMap(TailoringLanguage.init(rawValue:))
        guard !codes.isEmpty, languages.count == codes.count, Set(languages).count == languages.count else { throw .corruptWordList(.index, nil) }
        return languages
    }
}
