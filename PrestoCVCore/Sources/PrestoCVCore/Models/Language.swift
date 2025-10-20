import Foundation

// MARK: - Language Proficiency Level

public enum LanguageProficiencyLevel: String, CaseIterable, Codable, Sendable {
    case a1 = "A1"
    case a2 = "A2"
    case b1 = "B1"
    case b2 = "B2"
    case c1 = "C1"
    case c2 = "C2"
    case native = "Native"
    
    public var localizationKey: String {
        switch self {
        case .a1: return "language.level.a1"
        case .a2: return "language.level.a2"
        case .b1: return "language.level.b1"
        case .b2: return "language.level.b2"
        case .c1: return "language.level.c1"
        case .c2: return "language.level.c2"
        case .native: return "language.level.native"
        }
    }
    
    // For backward compatibility with existing data
    public static func fromString(_ string: String) -> LanguageProficiencyLevel? {
        // Try exact match first
        if let level = LanguageProficiencyLevel(rawValue: string) {
            return level
        }
        
        // Try case-insensitive match
        let uppercased = string.uppercased()
        for level in LanguageProficiencyLevel.allCases {
            if level.rawValue.uppercased() == uppercased {
                return level
            }
        }
        
        // Default fallback based on common descriptions
        let lowercased = string.lowercased()
        if lowercased.contains("native") || lowercased.contains("mother") {
            return .native
        } else if lowercased.contains("beginner") || lowercased.contains("a1") {
            return .a1
        } else if lowercased.contains("elementary") || lowercased.contains("a2") {
            return .a2
        } else if lowercased.contains("intermediate") && !lowercased.contains("upper") {
            return .b1
        } else if lowercased.contains("upper") || lowercased.contains("b2") {
            return .b2
        } else if lowercased.contains("advanced") || lowercased.contains("c1") {
            return .c1
        } else if lowercased.contains("proficient") || lowercased.contains("c2") {
            return .c2
        }
        
        return nil
    }
}

// MARK: - Language Model

public struct Language: Codable, Identifiable, Sendable, Equatable {
    public var id: UUID
    public var name: String
    public var level: LanguageProficiencyLevel
    
    private enum CodingKeys: String, CodingKey {
        case id, name, level
    }
    
    public init(id: UUID = UUID(), name: String = "", level: LanguageProficiencyLevel = .b1) {
        self.id = id
        self.name = name
        self.level = level
    }
    
    // MARK: - Codable Implementation
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // For id, generate a new UUID if not present in JSON
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        
        // Try to decode as enum first, then fall back to string for backward compatibility
        if let levelEnum = try? container.decode(LanguageProficiencyLevel.self, forKey: .level) {
            self.level = levelEnum
        } else if let levelString = try? container.decode(String.self, forKey: .level),
                  let levelEnum = LanguageProficiencyLevel.fromString(levelString) {
            self.level = levelEnum
        } else {
            self.level = .b1 // Default to B1 (Intermediate)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(level, forKey: .level)
    }
}