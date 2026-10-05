import Foundation
#if canImport(Glibc)   // outbound adapter: platform code is allowed here (PlatformAdapters)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif
import PrestoCVApplication

/// File operations of a store, with their failures coded as repository errors.
enum StoreFiles {
    /// Whether anything is at `url`, a link included, without following it. Only ENOENT means nothing is there.
    static func exists(_ url: URL) throws(RepositoryError) -> Bool {
        var status = stat()
        if lstat(url.path, &status) == 0 { return true }
        guard errno == ENOENT else { throw .unreadable(file: url.lastPathComponent) }
        return false
    }

    static func remove(_ url: URL) throws(RepositoryError) {
        do { try FileManager.default.removeItem(at: url) } catch { throw .writeFailed(file: url.lastPathComponent) }
    }

    static func removeIfPresent(_ url: URL) throws(RepositoryError) {
        if try exists(url) { try remove(url) }
    }
}
