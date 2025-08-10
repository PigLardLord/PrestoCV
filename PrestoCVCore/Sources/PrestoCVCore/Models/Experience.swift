import Foundation

// MARK: - Experience Model

public struct Experience: Codable, Identifiable, Sendable {
    public var id: UUID
    public var title: String
    public var company: String
    public var location: String
    public var period: String
    public var description: String
    
    public init(id: UUID = UUID(), title: String = "", company: String = "", location: String = "", period: String = "", description: String = "") {
        self.id = id
        self.title = title
        self.company = company
        self.location = location
        self.period = period
        self.description = description
    }
}