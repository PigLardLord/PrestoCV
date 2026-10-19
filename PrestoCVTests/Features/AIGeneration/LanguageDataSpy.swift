@testable import PrestoCV

/// Records the languages whose data the app asks the system for.
@MainActor
final class LanguageDataSpy: LanguageDataRequesting {
    private(set) var requests: [String] = []

    func requestLexicalClassData(forLanguage language: String) {
        requests.append(language)
    }
}
