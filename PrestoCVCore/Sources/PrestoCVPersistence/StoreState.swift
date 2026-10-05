import Foundation
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif
import PrestoCVApplication
import PrestoCVDomain

/// Whether the store directory itself can be used: absent before the first save, unavailable when it cannot be reached,
/// sits behind a link whose target is gone, or is not a directory. The store may be reached through a link.
enum StoreState {
    case present, absent, unavailable(StoreFailure)

    init(of directory: URL) {
        var status = stat()
        guard stat(directory.path, &status) == 0 else { self = Self.unreachable(directory.path, errno: errno); return }
        self = (status.st_mode & S_IFMT) == S_IFDIR ? .present : .unavailable(.notADirectory)
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

    private static func unreachable(_ path: String, errno code: Int32) -> StoreState {
        code == ENOENT && !passesThroughDanglingLink(path) ? .absent : .unavailable(.cannotList)
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
        var link = stat(), target = stat()
        return lstat(path, &link) == 0 && (link.st_mode & S_IFMT) == S_IFLNK && stat(path, &target) != 0
    }
}
