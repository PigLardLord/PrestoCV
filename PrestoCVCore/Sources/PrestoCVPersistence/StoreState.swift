import Foundation
import PrestoCVApplication
import PrestoCVDomain

/// Whether the store directory itself can be used: absent before the first save, unavailable when it cannot be reached,
/// sits behind a link whose target is gone, or is not a directory. The store may be reached through a link.
enum StoreState {
    case present, absent, unavailable(StoreFailure)

    init(of directory: URL) {
        switch StoreFiles.statusFollowingLinks(of: directory.path).kind {
        case .directory: self = .present
        case .missing: self = Self.whenMissing(directory.path)
        case .inaccessible: self = .unavailable(.cannotList)
        case .regularFile, .symbolicLink, .other: self = .unavailable(.notADirectory)
        }
    }

    /// Why a CV that is not in the store cannot be loaded. A CV is loaded by an identifier from a listing, so a store that is
    /// not there at all is unavailable: its CVs were not deleted one by one. Only a listing reads a missing store as a first run.
    func failureToLoad(_ id: CVID) -> RepositoryError {
        switch self {
        case .present: return .notFound(id)
        case .absent: return .storeUnavailable(.cannotList)
        case .unavailable(let failure): return .storeUnavailable(failure)
        }
    }

    private static func whenMissing(_ path: String) -> StoreState {
        passesThroughDanglingLink(path) ? .unavailable(.cannotList) : .absent
    }

    /// Whether the path, or one of its ancestors, is a symbolic link whose target is missing: a store that was moved
    /// away, not one that was never created.
    private static func passesThroughDanglingLink(_ path: String) -> Bool {
        var current = path
        while !current.isEmpty, current != "/" {
            if isDanglingLink(current) { return true }
            current = (current as NSString).deletingLastPathComponent
        }
        return false
    }

    private static func isDanglingLink(_ path: String) -> Bool {
        StoreFiles.status(of: path).kind == .symbolicLink && !StoreFiles.statusFollowingLinks(of: path).kind.isReachable
    }
}
