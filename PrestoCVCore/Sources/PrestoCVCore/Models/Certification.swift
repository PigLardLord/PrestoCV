import Foundation

// MARK: - Certification Model

public struct Certification: Codable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var issuer: String
    public var year: Int
    public var url: String
    public var description: String
    
    private enum CodingKeys: String, CodingKey {
        case id, name, issuer, year, url, description
    }
    
    public init(id: UUID = UUID(), name: String = "", issuer: String = "", year: Int = 0, url: String = "", description: String = "") {
        self.id = id
        self.name = name
        self.issuer = issuer
        self.year = year
        self.url = url
        self.description = description
    }
    
    // MARK: - Codable Implementation
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // For id, generate a new UUID if not present in JSON
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.issuer = try container.decodeIfPresent(String.self, forKey: .issuer) ?? ""
        self.year = try container.decodeIfPresent(Int.self, forKey: .year) ?? 0
        self.url = try container.decodeIfPresent(String.self, forKey: .url) ?? ""
        self.description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
    }
}