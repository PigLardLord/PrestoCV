import Foundation

/// The result of loading everything from a storage: the objects that could be used, and how many stored files
/// could not be: those that stay where they are, and those set aside that nobody has acknowledged yet.
public struct StorageLoadReport<Item: Sendable>: Sendable {
    public let items: [Item]
    public let unreadableCount: Int
    
    public init(items: [Item], unreadableCount: Int) {
        self.items = items
        self.unreadableCount = unreadableCount
    }
}

extension StorageLoadReport: Equatable where Item: Equatable {}
