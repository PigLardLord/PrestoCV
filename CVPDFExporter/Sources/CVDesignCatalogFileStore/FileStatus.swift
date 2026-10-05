import Foundation
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

/// What `stat` says about a path or a descriptor: the kind of file, and its size.
struct FileStatus {
    private let raw: stat

    /// The status of `path`, following a symbolic link. nil when the call fails, and `errno` says why.
    static func of(path: String) -> FileStatus? {
        var raw = stat()
        return stat(path, &raw) == 0 ? FileStatus(raw: raw) : nil
    }

    /// The status of `path` itself, even when it is a symbolic link. nil when the call fails, and `errno` says why.
    static func ofLink(path: String) -> FileStatus? {
        var raw = stat()
        return lstat(path, &raw) == 0 ? FileStatus(raw: raw) : nil
    }

    static func of(descriptor: Int32) -> FileStatus? {
        var raw = stat()
        return fstat(descriptor, &raw) == 0 ? FileStatus(raw: raw) : nil
    }

    var isRegularFile: Bool { kind == S_IFREG }
    var isDirectory: Bool { kind == S_IFDIR }
    var isSymbolicLink: Bool { kind == S_IFLNK }
    var size: Int { Int(raw.st_size) }

    private var kind: mode_t { raw.st_mode & S_IFMT }
}
