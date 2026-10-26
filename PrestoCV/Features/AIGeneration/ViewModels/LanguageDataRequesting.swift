/// What the system answers when the app asks for a language's data.
enum LanguageDataOutcome: Sendable, Equatable {
    /// The device has the data now.
    case available
    /// The system cannot give the data: it says so, it fails, or it does not answer in time.
    case notAvailable
}

/// Asks the system for the language data that grounding a description needs (`CVGenerationError.languageDataUnavailable`).
@MainActor
protocol LanguageDataRequesting: Sendable {
    /// Asks the system to download the lexical class of `language`, a BCP 47 code ("en", "de"), and returns its answer. The system
    /// downloads it; the app sends nothing. Cancelled, it returns `.notAvailable` without waiting for the system.
    func requestLexicalClassData(forLanguage language: String) async -> LanguageDataOutcome
}
