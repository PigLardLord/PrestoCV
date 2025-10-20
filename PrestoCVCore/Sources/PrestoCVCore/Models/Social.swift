import Foundation

// MARK: - Social Model

public struct Social: Codable, Identifiable, Sendable, Equatable {
    public var id: UUID
    public var platform: String
    public var url: String
    
    private enum CodingKeys: String, CodingKey {
        case id, platform, url
    }
    
    public init(id: UUID = UUID(), platform: String = "", url: String = "") {
        self.id = id
        self.platform = platform
        self.url = url
    }
    
    // MARK: - Codable Implementation
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // For id, generate a new UUID if not present in JSON
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.platform = try container.decodeIfPresent(String.self, forKey: .platform) ?? ""
        self.url = try container.decodeIfPresent(String.self, forKey: .url) ?? ""
    }
}