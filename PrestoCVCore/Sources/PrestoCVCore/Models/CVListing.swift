import Foundation

/// The stored CVs, in list order, when each was last saved, and how many stored files could not be opened as CVs.
public struct CVListing: Equatable, Sendable {
    public let cvs: [CVModel]
    /// When each CV was last saved, in whole seconds. A CV that was stored without a time is not in it.
    public let lastSavedAt: [UUID: Date]
    public let unreadableCount: Int
    
    public init(cvs: [CVModel], lastSavedAt: [UUID: Date] = [:], unreadableCount: Int = 0) {
        self.cvs = cvs
        self.lastSavedAt = lastSavedAt
        self.unreadableCount = unreadableCount
    }
}
