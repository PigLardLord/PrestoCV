import Foundation
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

/// The directory of a design store, and the lock that serialises the instances and processes that use it: a save holds
/// an exclusive `flock`, a read a shared one.
struct StoreDirectory {
    let url: URL

    var designsURL: URL { url.appendingPathComponent("Designs", isDirectory: true) }

    /// Runs `body` holding the exclusive lock, creating the store first when it does not exist yet.
    func withExclusiveLock<T>(_ body: () throws(FileDesignStoreError) -> T) throws(FileDesignStoreError) -> T {
        do { try FileManager.default.createDirectory(at: designsURL, withIntermediateDirectories: true) } catch { throw .storeUnavailable }
        return try locked(LOCK_EX, body)
    }

    /// Runs `body` holding a shared lock. A store that does not exist yet returns nil and creates nothing: nothing has
    /// been saved. A store that exists but cannot be reached is unavailable, never empty (CleanErrors).
    func withSharedLock<T>(_ body: () throws(FileDesignStoreError) -> T) throws(FileDesignStoreError) -> T? {
        guard try exists() else { return nil }
        return try locked(LOCK_SH, body)
    }

    private func exists() throws(FileDesignStoreError) -> Bool {
        guard let status = FileStatus.of(path: url.path) else {   // follows a link: the injected directory may be one
            guard errno == ENOENT, !Self.passesThroughDanglingLink(url.path) else { throw .storeUnavailable }
            return false
        }
        guard status.isDirectory else { throw .storeUnavailable }
        return true
    }

    /// Whether the path, or one of its ancestors, is a symbolic link whose target is missing: a store that was moved
    /// away, not one that was never created.
    private static func passesThroughDanglingLink(_ path: String) -> Bool {
        var current = path
        while !current.isEmpty, current != "/" {
            if FileStatus.ofLink(path: current)?.isSymbolicLink == true, FileStatus.of(path: current) == nil { return true }
            current = (current as NSString).deletingLastPathComponent
        }
        return false
    }

    private func locked<T>(_ operation: Int32, _ body: () throws(FileDesignStoreError) -> T) throws(FileDesignStoreError) -> T {
        let descriptor = try openLockFile()
        defer { close(descriptor) }
        try acquire(descriptor, operation)
        defer { flock(descriptor, LOCK_UN) }
        try checkDesignsDirectory()
        return try body()
    }

    private func openLockFile() throws(FileDesignStoreError) -> Int32 {
        let descriptor = open(url.appendingPathComponent(".lock").path, O_CREAT | O_RDWR | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC, 0o600)
        guard descriptor >= 0 else { throw .storeUnavailable }
        guard FileStatus.of(descriptor: descriptor)?.isRegularFile == true else {
            close(descriptor)
            throw .storeUnavailable
        }
        return descriptor
    }

    private func acquire(_ descriptor: Int32, _ operation: Int32) throws(FileDesignStoreError) {
        while flock(descriptor, operation) != 0 {
            guard errno == EINTR else { throw .storeUnavailable }
        }
    }

    /// `Designs` is a real directory of the store, or absent before the first save: never a link that would move
    /// reads and writes elsewhere.
    private func checkDesignsDirectory() throws(FileDesignStoreError) {
        guard let status = FileStatus.ofLink(path: designsURL.path) else {
            guard errno == ENOENT else { throw .storeUnavailable }
            return
        }
        guard status.isDirectory else { throw .storeUnavailable }
    }
}
