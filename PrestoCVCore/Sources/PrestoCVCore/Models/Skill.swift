import Foundation

// MARK: - Skill Model

public struct Skill: Codable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var level: Int
    
    public init(id: UUID = UUID(), name: String = "", level: Int = 1) {
        self.id = id
        self.name = name
        self.level = level
    }
}