import Foundation

// MARK: - Social Model

public struct Social: Codable, Identifiable, Sendable {
    public var id: UUID
    public var platform: String
    public var url: String
    
    public init(id: UUID = UUID(), platform: String = "", url: String = "") {
        self.id = id
        self.platform = platform
        self.url = url
    }
}