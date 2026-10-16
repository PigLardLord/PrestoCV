import Foundation

/// Request for CV generation from user input
public struct CVGenerationRequest: Equatable, Sendable {
    /// Free-form text description from user about their background
    public let userPrompt: String

    /// BCP 47 code of the app's language (e.g. "it"), used to write the CV only when the
    /// language of the description is unclear
    public let fallbackLanguageCode: String?

    public init(userPrompt: String, fallbackLanguageCode: String? = nil) {
        self.userPrompt = userPrompt
        self.fallbackLanguageCode = fallbackLanguageCode
    }
}
