import Testing
import Foundation
import PrestoCVDomain
import PrestoCVApplication
import PrestoCVCoreTestSupport
@testable import PrestoCVPersistence

@Suite("PersistedSchema · restoring from the quarantine")
struct QuarantineRestoreTests {
    @Test("a CV stored under the same name is never overwritten, and the quarantined copy stays")
    func neverOverwrites() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let store = repo(dir)
        let stored = try await store.create(named("Ada"))
        let quarantined = dir.appendingPathComponent("Quarantine/1~" + fileName(id1))
        try FileManager.default.createDirectory(at: quarantined.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(fileJSON().utf8).write(to: quarantined)
        await #expect(throws: RepositoryError.alreadyExists(id1)) { _ = try await store.restore(quarantined: "1~" + fileName(id1)) }
        #expect(try await store.load(id1) == stored)
        #expect(FileManager.default.fileExists(atPath: quarantined.path))
    }

    @Test("a name that is not in the quarantine is unreadable, whether or not the quarantine exists", arguments: [false, true])
    func notThere(quarantineExists: Bool) async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        if quarantineExists { try FileManager.default.createDirectory(at: dir.appendingPathComponent("Quarantine"), withIntermediateDirectories: true) }
        let name = "1~" + fileName(id1)
        await #expect(throws: RepositoryError.unreadable(file: name)) { _ = try await repo(dir).restore(quarantined: name) }
    }

    @Test("erasing a CV leaves the other files of the quarantine alone")
    func eraseKeepsOthers() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let folder = dir.appendingPathComponent("Quarantine")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let others = ["x" + fileName(id1), fileName(id2), "3~" + fileName(id2)]
        for name in others + ["2~" + fileName(id1)] { try Data("{".utf8).write(to: folder.appendingPathComponent(name)) }
        try await repo(dir).erase(id1)
        #expect(Set(try FileManager.default.contentsOfDirectory(atPath: folder.path)) == Set(others))
    }
}
