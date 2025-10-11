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
}
