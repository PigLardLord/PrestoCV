import Foundation
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif
import PrestoCVApplication

/// The exclusive lock on a store directory (`flock` on its `.lock` file), so that a revision check holds across repository
/// instances and processes (PersistedSchema). Waiting for the lock blocks the calling thread: #111.
struct StoreLock {
    let directory: URL

    /// Runs `body` while holding the lock, creating the store directory first if it is not there.
    func withExclusiveAccess<T>(_ body: () throws(RepositoryError) -> T) throws(RepositoryError) -> T {
        try createDirectory()
        let descriptor = try openLockFile()
        defer { close(descriptor) }
        try requireRegularFile(descriptor)
        try acquire(descriptor)
        defer { flock(descriptor, LOCK_UN) }
        return try body()
    }

    private func createDirectory() throws(RepositoryError) {
        do { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) } catch { throw .storeUnavailable(.cannotLock) }
    }

    /// Never through a link, and never on anything but a regular file: opening does not block.
    private func openLockFile() throws(RepositoryError) -> Int32 {
        let path = directory.appendingPathComponent(".lock").path
        let descriptor = open(path, O_CREAT | O_RDWR | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC, 0o600)
        guard descriptor >= 0 else { throw .storeUnavailable(.cannotLock) }
        return descriptor
    }

    private func requireRegularFile(_ descriptor: Int32) throws(RepositoryError) {
        var status = stat()
        guard fstat(descriptor, &status) == 0, (status.st_mode & S_IFMT) == S_IFREG else { throw .storeUnavailable(.cannotLock) }
    }

    private func acquire(_ descriptor: Int32) throws(RepositoryError) {
        while flock(descriptor, LOCK_EX) != 0 {
            guard errno == EINTR else { throw .storeUnavailable(.cannotLock) }
        }
    }
}
