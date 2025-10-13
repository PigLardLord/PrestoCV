#if canImport(FoundationModels)
import Foundation
import FoundationModels

/// Language proficiency level (CEFR-based)
@Generable
public enum LanguageProficiency: String, Codable, CaseIterable, Sendable {
    case a1 = "A1"
    case a2 = "A2"
    case b1 = "B1"
    case b2 = "B2"
    case c1 = "C1"
    case c2 = "C2"
    case native = "Native"
}

/// Language proficiency entry
@Generable
public struct Language: Codable, Equatable, Sendable {
    @Guide(description: "Language name (e.g., 'English', 'Spanish', 'Mandarin')")
    public let name: String

    @Guide(description: "CEFR proficiency level or Native")
    public let proficiency: LanguageProficiency

    public init(
        name: String,
        proficiency: LanguageProficiency
    ) {
        self.name = name
        self.proficiency = proficiency
    }
}
#endif
