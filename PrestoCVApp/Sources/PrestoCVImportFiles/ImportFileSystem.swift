import DiagnosticLogging
import Foundation
#if canImport(Glibc)   // outbound adapter: platform code is allowed here (R11)
import Glibc
#elseif canImport(Android)
import Android
#elseif canImport(Darwin)
import Darwin
#endif

/// What a bounded read of a file gave.
public enum FileRead: Sendable, Equatable {
    /// The whole file, at most the bound.
    case bytes(Data)
    /// The file holds more than the bound; nothing of it is kept.
    case aboveTheLimit
}

/// Why a file of the import could not be read or deleted.
public enum ImportFileError: Error, Equatable, Sendable {
    /// The path no longer names the received file, or it names something that is not a regular file.
    case notTheFile
    /// The file was moved aside to be checked and could not be put back: it stays beside, under a `.releasing` name.
    case leftAside
    /// A system call failed with this `errno`.
    case system(Int32)
}

extension ImportFileError: LoggableError {
    public var logCode: StaticString {
        switch self {
        case .notTheFile: "notTheFile"
        case .leftAside: "leftAside"
        case .system(let code): Self.name(of: code)
        }
    }

    /// The name of an `errno` the import's calls can give; any other is "system".
    private static func name(of code: Int32) -> StaticString {
        switch code {
        case EPERM: "EPERM"
        case ENOENT: "ENOENT"
        case EIO: "EIO"
        case EACCES: "EACCES"
        case EBUSY: "EBUSY"
        case EEXIST: "EEXIST"
        case EXDEV: "EXDEV"
        case ENOTDIR: "ENOTDIR"
        case EISDIR: "EISDIR"
        case EINVAL: "EINVAL"
        case ENFILE: "ENFILE"
        case EMFILE: "EMFILE"
        case ENOSPC: "ENOSPC"
        case EROFS: "EROFS"
        case EMLINK: "EMLINK"
        case ENAMETOOLONG: "ENAMETOOLONG"
        case ELOOP: "ELOOP"
        default: "system"
        }
    }
}

/// What the import's file adapter asks of the file system and of the platform's access to a chosen file. The device's
/// is `SystemImportFiles`; the tests wrap it to record the calls and to fail on purpose.
public protocol ImportFileSystem: Sendable {
    /// Starts security-scoped access to a chosen file. True when access started; it is then stopped exactly once.
    func startAccess(_ url: URL) -> Bool
    /// Stops an access that `startAccess` started.
    func stopAccess(_ url: URL)
    /// The path a URL names, however it is written: symbolic links resolved, `.` and `..` removed.
    func resolve(_ url: URL) -> URL
    /// The identity of a resolved path, when it names a regular file; nil for anything else or for no file.
    func identity(ofResolved url: URL) -> FileIdentity?
    /// When the regular file at a resolved path was created (on Apple platforms its birth time, which a copy that keeps
    /// the source's modification date does not inherit; elsewhere the inode's change time); nil for anything else or for
    /// no file.
    func creationDate(ofResolved url: URL) -> Date?
    /// The bytes of the file at `url`, read into memory (never mapped) through one descriptor that does not follow a
    /// link and does not wait on a pipe. Throws `notTheFile` when the opened file is not a regular file of `identity`.
    /// Reads at most `limit` bytes and one more, whatever size the file states.
    func read(_ url: URL, identity: FileIdentity, atMost limit: Int) throws(ImportFileError) -> FileRead
    /// Deletes the file at `url` only when it is still the regular file of `identity`; anything else found there is put
    /// back and `notTheFile` thrown. A path already gone is not an error.
    func remove(_ url: URL, identity: FileIdentity) throws(ImportFileError)
    /// What lies directly in `folder`, by the folder's path and each entry's name, in no set order: files, links, folders
    /// and anything else alike. None when the folder is not there; anything else that stops the listing is thrown.
    func entries(in folder: URL) throws(ImportFileError) -> [URL]
}
