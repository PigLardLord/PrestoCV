import Testing
import Foundation
import PrestoCVDomain
import PrestoCVApplication
import PrestoCVCoreTestSupport
@testable import PrestoCVPersistence

@Suite("PersistedSchema · stamping a quarantined file")
struct QuarantineStampTests {
    @Test("the clock is read once for a file that is moved into the quarantine")
    func stampedOnce() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("{".utf8).write(to: dir.appendingPathComponent(fileName(id2)))
        let clock = CountingClock()
        let issues = try await FileCVRepository(directory: dir, clock: clock).list().issues
        #expect(issues == [.corrupt(file: fileName(id2), reason: "no schemaVersion envelope")])
        #expect(clock.readCount == 1)
    }

    @Test("the clock is not read when the quarantine cannot take the file")
    func notReadWhenRefused() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let elsewhere = dir.appendingPathComponent("elsewhere", isDirectory: true)
        try FileManager.default.createDirectory(at: elsewhere, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: dir.appendingPathComponent("Quarantine"), withDestinationURL: elsewhere)
        try Data("{".utf8).write(to: dir.appendingPathComponent(fileName(id2)))
        let clock = CountingClock()
        let issues = try await FileCVRepository(directory: dir, clock: clock).list().issues
        #expect(issues == [.quarantineFailed(file: fileName(id2))])
        #expect(clock.readCount == 0)
    }
}
