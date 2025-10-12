import Foundation

/// Certification entry
public struct Certification: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let issuer: String
    public let date: String
    public let expiryDate: String?
    public let credentialId: String?
    public let url: String?

    public init(
        id: UUID = UUID(),
        name: String,
        issuer: String,
        date: String,
        expiryDate: String? = nil,
        credentialId: String? = nil,
        url: String? = nil
    ) {
        self.id = id
        self.name = name
        self.issuer = issuer
        self.date = date
        self.expiryDate = expiryDate
        self.credentialId = credentialId
        self.url = url
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.name = try container.decode(String.self, forKey: .name)
        self.issuer = try container.decode(String.self, forKey: .issuer)
        self.date = try container.decode(String.self, forKey: .date)
        self.expiryDate = try container.decodeIfPresent(String.self, forKey: .expiryDate)
        self.credentialId = try container.decodeIfPresent(String.self, forKey: .credentialId)
        self.url = try container.decodeIfPresent(String.self, forKey: .url)
    }
}
