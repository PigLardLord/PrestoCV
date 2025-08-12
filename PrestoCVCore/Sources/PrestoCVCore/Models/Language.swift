import Foundation

// MARK: - Language Model

public struct Language: Codable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var level: String
    
    private enum CodingKeys: String, CodingKey {
        case id, name, level
    }
    
    public init(id: UUID = UUID(), name: String = "", level: String = "") {
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
        self.level = try container.decodeIfPresent(String.self, forKey: .level) ?? ""
    }
}