import Foundation

// MARK: - Education Model

public struct Education: Codable, Identifiable, Sendable, Equatable {
    public var id: UUID
    public var degree: String
    public var school: String
    public var period: String
    public var description: String
    
    private enum CodingKeys: String, CodingKey {
        case id, degree, school, period, description
    }
    
    public init(id: UUID = UUID(), degree: String = "", school: String = "", period: String = "", description: String = "") {
        self.id = id
        self.degree = degree
        self.school = school
        self.period = period
        self.description = description
    }
    
    // MARK: - Codable Implementation
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // For id, generate a new UUID if not present in JSON
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.degree = try container.decodeIfPresent(String.self, forKey: .degree) ?? ""
        self.school = try container.decodeIfPresent(String.self, forKey: .school) ?? ""
        self.period = try container.decodeIfPresent(String.self, forKey: .period) ?? ""
        self.description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
    }
}