import Foundation
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif
import PrestoCVApplication

/// What is at a path. The mode of a file is read here and nowhere else.
enum FileKind: Equatable {
    /// Nothing is there.
    case missing
    /// The path cannot be inspected: a directory on the way cannot be searched, or the descriptor is not valid.
    case inaccessible
    case regularFile, directory, symbolicLink
    /// A pipe, a socket or a device.
    case other

    /// Whether something was found, not necessarily a file the store can use.
    var isReachable: Bool { self != .missing && self != .inaccessible }
}

/// The kind and the size of a file, from one `stat` call.
struct FileStatus {
    let kind: FileKind
    let size: Int
}

/// File operations of a store, with their failures coded as repository errors.
enum StoreFiles {
    /// The status of the file at `path`. A link is its own kind: what it points to is not looked at.
    static func status(of path: String) -> FileStatus { status { lstat(path, &$0) } }

    /// The status of what `path` leads to, a link followed.
    static func statusFollowingLinks(of path: String) -> FileStatus { status { stat(path, &$0) } }

    /// The status of the file an open descriptor refers to.
    static func status(ofDescriptor descriptor: Int32) -> FileStatus { status { fstat(descriptor, &$0) } }

    /// Whether anything is at `url`, a link included, without following it. Only a missing path means nothing is there.
    static func exists(_ url: URL) throws(RepositoryError) -> Bool {
        switch status(of: url.path).kind {
        case .missing: return false
        case .inaccessible: throw .unreadable(file: url.lastPathComponent)
        case .regularFile, .directory, .symbolicLink, .other: return true
        }
    }

    static func remove(_ url: URL) throws(RepositoryError) {
        do { try FileManager.default.removeItem(at: url) } catch { throw .writeFailed(file: url.lastPathComponent) }
    }

    static func removeIfPresent(_ url: URL) throws(RepositoryError) {
        if try exists(url) { try remove(url) }
    }

    private static func status(from call: (inout stat) -> Int32) -> FileStatus {
        var raw = stat()
        guard call(&raw) == 0 else { return FileStatus(kind: errno == ENOENT ? .missing : .inaccessible, size: 0) }
        return FileStatus(kind: kind(ofMode: raw.st_mode), size: Int(raw.st_size))
    }

    private static func kind(ofMode mode: mode_t) -> FileKind {
        switch mode & S_IFMT {
        case S_IFREG: return .regularFile
        case S_IFDIR: return .directory
        case S_IFLNK: return .symbolicLink
        default: return .other
        }
    }
}
