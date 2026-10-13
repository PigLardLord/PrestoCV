import Foundation

/// The stored CVs, in list order, and how many stored files could not be opened as CVs.
public struct CVListing: Equatable, Sendable {
    public let cvs: [CVModel]
    public let unreadableCount: Int
    
    public init(cvs: [CVModel], unreadableCount: Int = 0) {
        self.cvs = cvs
        self.unreadableCount = unreadableCount
    }
}
