/// Asks the system for the language data that grounding a description needs (`CVGenerationError.languageDataUnavailable`).
@MainActor
protocol LanguageDataRequesting {
    /// Asks the system to download the lexical class of `language`, a BCP 47 code ("en", "de"). The system downloads it; the app
    /// sends nothing.
    func requestLexicalClassData(forLanguage language: String)
}
