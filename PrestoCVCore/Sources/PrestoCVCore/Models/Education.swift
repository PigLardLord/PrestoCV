import Foundation

// MARK: - Education Model

public struct Education: Codable, Identifiable, Sendable {
    public var id: UUID
    public var degree: String
    public var school: String
    public var period: String
    public var description: String
    
    public init(id: UUID = UUID(), degree: String = "", school: String = "", period: String = "", description: String = "") {
        self.id = id
        self.degree = degree
        self.school = school
        self.period = period
        self.description = description
    }
}