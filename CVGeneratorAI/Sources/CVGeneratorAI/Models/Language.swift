import Foundation

/// Language proficiency entry
public struct Language: Codable, Equatable, Sendable {
    public let name: String
    public let proficiency: LanguageProficiency

    public init(
        name: String,
        proficiency: LanguageProficiency
    ) {
        self.name = name
        self.proficiency = proficiency
    }
}

/// Language proficiency level (CEFR-based)
public enum LanguageProficiency: String, Codable, CaseIterable, Sendable {
    case a1 = "A1"
    case a2 = "A2"
    case b1 = "B1"
    case b2 = "B2"
    case c1 = "C1"
    case c2 = "C2"
    case native = "Native"
}
