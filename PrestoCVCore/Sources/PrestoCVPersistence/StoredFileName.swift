import Foundation
import PrestoCVDomain

/// How a store names its files: a CV by its identifier and a suffix.
enum StoredFileName {
    static let suffix = ".cv.json"

    static func of(_ id: CVID) -> String { id.raw.uuidString + suffix }
}
