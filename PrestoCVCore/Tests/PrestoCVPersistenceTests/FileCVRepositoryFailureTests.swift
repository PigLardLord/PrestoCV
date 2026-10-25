import Testing
import Foundation
#if canImport(Glibc)
import Glibc
#elseif canImport(Android)
import Android
#elseif canImport(Darwin)
import Darwin
#endif
import PrestoCVDomain
import PrestoCVApplication
@testable import PrestoCVPersistence
import PrestoCVCoreTestSupport

/// What Foundation reports for a failed call, read here without the repository's own mapping.
private func foundationCause(_ error: any Error) -> FailureCause {
    let bridged = error as NSError
    switch bridged.domain {
    case NSCocoaErrorDomain: return FailureCause(domain: .cocoa, code: bridged.code)
    case NSPOSIXErrorDomain: return FailureCause(domain: .posix, code: bridged.code)
    default: return FailureCause(domain: .other, code: bridged.code)
    }
}

/// A directory that nothing can be added to or removed from, with a file in it.
private func makeReadOnlyDirectory() throws -> (directory: URL, file: URL) {
    let directory = tempDir()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let file = directory.appendingPathComponent("probe")
    try Data("x".utf8).write(to: file)
    chmod(directory.path, 0o555)
    return (directory, file)
}

private func release(_ directory: URL) {
    chmod(directory.path, 0o755)
    try? FileManager.default.removeItem(at: directory)
}

/// The cause Foundation gives for a write of the repository's kind into a directory that cannot be written to.
private func failedWriteCause() throws -> FailureCause {
    let (directory, _) = try makeReadOnlyDirectory(); defer { release(directory) }
    do { try Data("x".utf8).write(to: directory.appendingPathComponent("other"), options: FileCVRepository.writeOptions) }
    catch { return foundationCause(error) }
    Issue.record("a write into a read-only directory succeeded"); return FailureCause(domain: .other, code: 0)
}

/// The cause Foundation gives for removing a file from a directory that cannot be changed.
private func failedRemovalCause() throws -> FailureCause {
    let (directory, file) = try makeReadOnlyDirectory(); defer { release(directory) }
    do { try FileManager.default.removeItem(at: file) } catch { return foundationCause(error) }
    Issue.record("a removal from a read-only directory succeeded"); return FailureCause(domain: .other, code: 0)
}

/// The cause Foundation gives for moving a file into a directory that cannot be changed.
private func failedMoveCause() throws -> FailureCause {
    let (directory, _) = try makeReadOnlyDirectory(); defer { release(directory) }
    let source = tempDir(); defer { try? FileManager.default.removeItem(at: source) }
    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    let file = source.appendingPathComponent("moved")
    try Data("x".utf8).write(to: file)
    do { try FileManager.default.moveItem(at: file, to: directory.appendingPathComponent("moved")) } catch { return foundationCause(error) }
    Issue.record("a move into a read-only directory succeeded"); return FailureCause(domain: .other, code: 0)
}

@Suite("R7 · a failed write keeps its cause")
struct FileCVRepositoryFailureTests {
    @Test("a Foundation error becomes its domain and code, and nothing that names a path")
    func mapping() {
        #expect(FailureCause(CocoaError(.fileWriteNoPermission)) == FailureCause(domain: .cocoa, code: CocoaError.fileWriteNoPermission.rawValue))
        #expect(FailureCause(NSError(domain: NSPOSIXErrorDomain, code: Int(EACCES))) == FailureCause(domain: .posix, code: Int(EACCES)))
        #expect(FailureCause(NSError(domain: "Elsewhere", code: 7, userInfo: [NSFilePathErrorKey: "/private/path"])) == FailureCause(domain: .other, code: 7))
    }

    @Test("a cause reads as its domain and code in test output and in the log")
    func description() {
        #expect("\(FailureCause(domain: .posix, code: 13))" == "posix 13")
        #expect("\(FailureCause(domain: .cocoa, code: 513))" == "cocoa 513")
        #expect("\(FailureCause(domain: .other, code: 1))" == "other 1")
        #expect("\(RepositoryError.writeFailed(file: "a.cv.json", cause: FailureCause(domain: .posix, code: 28)))".contains("posix 28"))
    }

    @Test("a write into a read-only directory reports the underlying error's domain and code", .enabled(if: !isRoot))
    func writeIntoReadOnlyDirectory() async throws {
        let dir = tempDir(); defer { release(dir) }
        let r = repo(dir)
        let saved = try await r.create(named("Ada"))
        let expected = try failedWriteCause()
        #expect(expected.domain != .other && expected.code != 0)         // Foundation names a cause; the repository must keep it
        chmod(dir.path, 0o555)
        await #expect(throws: RepositoryError.writeFailed(file: fileName(id1), cause: expected)) { _ = try await r.update(saved) }
        await #expect(throws: RepositoryError.writeFailed(file: fileName(id2), cause: expected)) { _ = try await r.create(named("Bob", id: id2)) }
        chmod(dir.path, 0o755)
        #expect(try await r.load(id1) == saved)                          // the previous version stays
        #expect(try await r.list().cvs.map(\.id) == [id1])               // and nothing half-written is left behind
    }

    @Test("a failed delete keeps its cause", .enabled(if: !isRoot))
    func deleteFailure() async throws {
        let dir = tempDir(); defer { release(dir) }
        let r = repo(dir)
        let saved = try await r.create(named("Ada"))
        let expected = try failedRemovalCause()
        chmod(dir.path, 0o555)
        await #expect(throws: RepositoryError.writeFailed(file: fileName(id1), cause: expected)) { try await r.delete(id1, revision: saved.revision) }
    }

    @Test("a failed erase keeps its cause", .enabled(if: !isRoot))
    func eraseFailure() async throws {
        let dir = tempDir(); defer { release(dir) }
        let r = repo(dir)
        _ = try await r.create(named("Ada"))
        let expected = try failedRemovalCause()
        chmod(dir.path, 0o555)
        await #expect(throws: RepositoryError.writeFailed(file: fileName(id1), cause: expected)) { try await r.erase(id1) }
    }

    @Test("a failed purge keeps its cause", .enabled(if: !isRoot))
    func purgeFailure() async throws {
        let dir = tempDir(); defer { release(dir) }
        let quarantine = dir.appendingPathComponent("Quarantine")
        defer { chmod(quarantine.path, 0o755) }
        let r = repo(dir)
        _ = try await r.create(named("Ada"))
        try FileManager.default.createDirectory(at: quarantine, withIntermediateDirectories: true)
        let old = quarantine.appendingPathComponent(fileName(id2))
        try Data("{".utf8).write(to: old)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 0)], ofItemAtPath: old.path)
        let expected = try failedRemovalCause()
        chmod(quarantine.path, 0o555)
        await #expect(throws: RepositoryError.writeFailed(file: fileName(id2), cause: expected)) {
            _ = try await r.purgeQuarantine(olderThan: Date(timeIntervalSince1970: 1_000))
        }
    }

    @Test("a failed restore keeps its cause, and the quarantined copy stays", .enabled(if: !isRoot))
    func restoreFailure() async throws {
        let dir = tempDir(); defer { release(dir) }
        let quarantine = dir.appendingPathComponent("Quarantine")
        let r = repo(dir)
        _ = try await r.create(named("Ada"))
        try FileManager.default.createDirectory(at: quarantine, withIntermediateDirectories: true)
        let quarantined = quarantine.appendingPathComponent(fileName(id2))
        try Data(fileJSON(id: id2.raw.uuidString).utf8).write(to: quarantined)
        let expected = try failedMoveCause()
        chmod(dir.path, 0o555)
        await #expect(throws: RepositoryError.writeFailed(file: fileName(id2), cause: expected)) {
            _ = try await r.restore(quarantined: fileName(id2))
        }
        #expect(FileManager.default.fileExists(atPath: quarantined.path))
    }
}

@Suite("ADR 0009 · a locked device")
struct LockedDeviceTests {
    @Test("building the repository reads and writes nothing, so a launch that never opens the store cannot fail on it")
    func noIOAtInit() {
        let dir = tempDir()
        _ = repo(dir)
        #expect(!FileManager.default.fileExists(atPath: dir.path))
    }

    // A CV file that cannot be opened (mode 0) stands for one that is protected while the device is locked: both
    // fail at `open`. The real protection class is checked on a device, which neither the simulator nor Linux can do.
    @Test("a CV that cannot be opened is reported, never lost or quarantined, and listed again once it can", .enabled(if: !isRoot))
    func locksAndUnlocks() async throws {
        let dir = tempDir()
        let locked = dir.appendingPathComponent(fileName(id1))
        defer { chmod(locked.path, 0o644); try? FileManager.default.removeItem(at: dir) }
        let r = repo(dir)
        let ada = try await r.create(named("Ada"))
        let bob = try await r.create(named("Bob", id: id2))
        let before = try Data(contentsOf: locked)

        chmod(locked.path, 0)
        let whileLocked = try await r.list()
        #expect(whileLocked.cvs.map(\.id) == [id2])                         // the CV that can be read is still listed
        #expect(whileLocked.issues == [.unreadable(file: fileName(id1))])   // the other is named, so it is not taken for deleted
        await #expect(throws: RepositoryError.unreadable(file: fileName(id1))) { _ = try await r.load(id1) }
        await #expect(throws: RepositoryError.unreadable(file: fileName(id1))) { _ = try await r.update(ada) }
        await #expect(throws: RepositoryError.unreadable(file: fileName(id1))) { _ = try await r.create(named("Other")) }
        await #expect(throws: RepositoryError.unreadable(file: fileName(id1))) { try await r.delete(id1, revision: ada.revision) }
        #expect(!FileManager.default.fileExists(atPath: dir.appendingPathComponent("Quarantine").path))

        chmod(locked.path, 0o644)                                           // unlocked: the next listing reads it again
        let afterUnlock = try await r.list()
        #expect(Set(afterUnlock.cvs.map(\.id)) == [id1, id2] && afterUnlock.issues.isEmpty)
        #expect(try Data(contentsOf: locked) == before)                     // nothing was written or removed meanwhile
        #expect(try await r.load(id2) == bob)
    }
}
