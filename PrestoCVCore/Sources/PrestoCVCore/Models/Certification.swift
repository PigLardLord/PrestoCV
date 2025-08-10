import Foundation

// MARK: - Certification Model

public struct Certification: Codable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var issuer: String
    public var year: Int?
    public var url: String
    public var description: String
    
    public init(id: UUID = UUID(), name: String = "", issuer: String = "", year: Int? = nil, url: String = "", description: String = "") {
        self.id = id
        self.name = name
        self.issuer = issuer
        self.year = year
        self.url = url
        self.description = description
    }
}