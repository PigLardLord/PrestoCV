import Foundation

// MARK: - Experience Model

public struct Experience: Codable, Identifiable, Sendable {
    public var id: UUID
    public var title: String
    public var company: String
    public var location: String
    public var period: String
    public var description: String
    
    private enum CodingKeys: String, CodingKey {
        case id, title, company, location, period, description
    }
    
    public init(id: UUID = UUID(), title: String = "", company: String = "", location: String = "", period: String = "", description: String = "") {
        self.id = id
        self.title = title
        self.company = company
        self.location = location
        self.period = period
        self.description = description
    }
    
    // MARK: - Codable Implementation
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // For id, generate a new UUID if not present in JSON
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.company = try container.decodeIfPresent(String.self, forKey: .company) ?? ""
        self.location = try container.decodeIfPresent(String.self, forKey: .location) ?? ""
        self.period = try container.decodeIfPresent(String.self, forKey: .period) ?? ""
        self.description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
    }
}