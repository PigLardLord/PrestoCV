import Foundation

// MARK: - Language Model

public struct Language: Codable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var level: String
    
    public init(id: UUID = UUID(), name: String = "", level: String = "") {
        self.id = id
        self.name = name
        self.level = level
    }
}