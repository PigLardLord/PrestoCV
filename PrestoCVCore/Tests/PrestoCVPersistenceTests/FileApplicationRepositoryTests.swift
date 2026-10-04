import Testing
import Foundation
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif
import PrestoCVDomain
import PrestoCVApplication
@testable import PrestoCVPersistence
import PrestoCVCoreTestSupport

private func appID(_ n: Int) -> ApplicationID { ApplicationID(UUID(uuidString: "AAAAAAAA-0000-0000-0000-" + String(format: "%012d", n))!) }
private func application(_ n: Int = 1, job: String? = nil, name: String = "Ada") -> Application {
    var cv = FixtureCV.full(id: CVID(UUID(uuidString: "BBBBBBBB-0000-0000-0000-" + String(format: "%012d", n))!))
    cv.setPersonalDetails(PersonalDetails(fullName: name))
    let base = FixtureApplication.full(id: appID(n), cvID: cv.id, jobID: job ?? "job-\(n)")
    do { return try Application(id: base.id, cv: cv, letter: base.letter, advert: base.advert, provenance: base.provenance) }
    catch { preconditionFailure("\(error)") }
}
private func appRepo(_ dir: URL) -> FileApplicationRepository { FileApplicationRepository(directory: dir, clock: SteppingClock()) }
private func appFile(_ id: ApplicationID) -> String { "\(id.raw.uuidString).application.json" }
private func stamp(_ application: Application, revision: Int = 1) -> Application {
    application.stamped(revision: revision, createdAt: Date(timeIntervalSince1970: 1_704_067_200), updatedAt: Date(timeIntervalSince1970: 1_704_067_200))
}

/// A stored application as JSON, at schema `version`.
private func appJSON(_ application: Application = application(), version: Int = 1) throws -> String {
    let stored = stamp(application)
    let json = try ApplicationFileV1(stored, createdAt: stored.createdAt!, updatedAt: stored.updatedAt!).encoded()
    return String(decoding: json, as: UTF8.self).replacingOccurrences(of: #""schemaVersion":1"#, with: #""schemaVersion":\#(version)"#)
}

private func exists(_ url: URL) -> Bool { FileManager.default.fileExists(atPath: url.path) }

private func write(_ text: String, to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(text.utf8).write(to: url)
}

@Suite("ADR 0019 · application file repository")
struct FileApplicationRepositoryTests {
    @Test("every field survives a save and a load, in the repository's own format, and the CV keeps its CVID")
    func fullRoundTrip() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let saved = try await appRepo(dir).create(FixtureApplication.full())
        let loaded = try await appRepo(dir).load(saved.id)
        let source = FixtureApplication.full()
        #expect(loaded == saved)
        #expect(loaded.cv.id == FixtureApplication.cvID && loaded.cv.revision == 1 && loaded.cv.updatedAt == loaded.updatedAt)
        #expect(loaded.cv.personal == source.cv.personal && loaded.cv.sections == source.cv.sections && loaded.letter == source.letter)
        #expect(loaded.advert == source.advert && loaded.provenance == source.provenance)
    }

    @Test("an update keeps the CV's identity through the file, and an edit of the CV is one revision of the application")
    func updateKeepsIdentity() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let r = appRepo(dir)
        let v1 = try await r.create(application())
        var cv = v1.cv
        cv.rename("Edited")
        let v2 = try await UpdateApplicationCV(repository: r)(v1, to: cv)
        #expect(v2.revision == 2 && v2.cv.revision == 2 && v2.cv.id == v1.cv.id && v2.createdAt == v1.createdAt)
        #expect(try await appRepo(dir).load(v1.id) == v2)
    }

    @Test("the CV listing never holds the CV of an application, and erasing a CV leaves the applications made from it")
    func cvAndApplicationsAreSeparate() async throws {
        let root = tempDir(); defer { try? FileManager.default.removeItem(at: root) }
        let applications = FileApplicationRepository(directory: root.appendingPathComponent("Applications"), clock: SteppingClock())
        let cvs = FileCVRepository(directory: root.appendingPathComponent("CVs"), clock: SteppingClock())
        let source = try await cvs.create(FixtureCV.full())
        let kept = try await applications.create(FixtureApplication.full())
        #expect(try await cvs.list().cvs == [source])
        await #expect(throws: RepositoryError.notFound(kept.cv.id)) { _ = try await cvs.load(kept.cv.id) }
        try await cvs.erase(source.id)
        #expect(try await cvs.list().cvs.isEmpty)
        #expect(try await applications.load(kept.id) == kept)
        #expect(kept.provenance.sourceCV == FixtureProvenance.sourceCV)
    }

    @Test("mixed directory: healthy listed, corrupt quarantined with a reason, newer schema untouched")
    func mixedDirectory() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let r = appRepo(dir)
        let healthy = try await r.create(application(1))
        try write("{", to: dir.appendingPathComponent(appFile(appID(2))))
        let newerName = appFile(appID(3)), newer = try appJSON(application(3), version: 2)
        try write(newer, to: dir.appendingPathComponent(newerName))
        let listing = try await r.list()
        #expect(listing.applications == [healthy])
        #expect(listing.issues == [.corrupt(file: appFile(appID(2)), reason: "no schemaVersion envelope"), .upgradeRequired(file: newerName, version: 2)])
        #expect(try String(contentsOf: dir.appendingPathComponent(newerName), encoding: .utf8) == newer)
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("Quarantine/\(appFile(appID(2)))").path))
    }

    @Test("a file of the wrong kind is corrupt: a CV file under an application's name")
    func wrongKind() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let cv = FixtureCV.full().stored(revision: 1, at: Date(timeIntervalSince1970: 0))
        let json = try CVFileV1(cv, createdAt: cv.createdAt!, updatedAt: cv.updatedAt!).encoded()
        try write(String(decoding: json, as: UTF8.self), to: dir.appendingPathComponent(appFile(appID(1))))
        #expect(try await appRepo(dir).list().issues == [.corrupt(file: appFile(appID(1)), reason: "not an application file")])
    }

    @Test("an unreadable file is reported and left in place, never quarantined", .enabled(if: !isRoot))
    func unreadableNotQuarantined() async throws {
        let dir = tempDir(); defer { chmod(dir.appendingPathComponent(appFile(appID(1))).path, 0o644); try? FileManager.default.removeItem(at: dir) }
        let r = appRepo(dir)
        _ = try await r.create(application(1))
        let path = dir.appendingPathComponent(appFile(appID(1))).path
        chmod(path, 0)
        #expect(try await r.list().issues == [.unreadable(file: appFile(appID(1)))])
        #expect(FileManager.default.fileExists(atPath: path))
        chmod(path, 0o644)
        #expect(try await r.list().applications.map(\.id) == [appID(1)])
    }

    @Test("an oversized file is reported without being read")
    func tooLarge() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data(count: 2048).write(to: dir.appendingPathComponent(appFile(appID(1))))
        let r = FileApplicationRepository(directory: dir, clock: SteppingClock(), maxFileBytes: 1024)
        #expect(try await r.list().issues == [.tooLarge(file: appFile(appID(1)), bytes: 2048)])
        await #expect(throws: ApplicationRepositoryError.tooLarge(file: appFile(appID(1)))) { _ = try await r.load(appID(1)) }
    }

    @Test("a save that would not read back is refused and the previous version stays")
    func wouldNotReadBack() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let r = FileApplicationRepository(directory: dir, clock: SteppingClock(), maxFileBytes: 6_000)
        let v1 = try await r.create(application(1))
        let paragraph = String(repeating: "𝒜", count: 800)                                                  // 3,200 bytes: valid, and large together
        let big = try CoverLetter(recipient: LetterRecipient(), paragraphs: Array(repeating: paragraph, count: 4))
        var heavy = v1
        heavy.setLetter(big)
        await #expect(throws: ApplicationRepositoryError.wouldNotReadBack(file: appFile(appID(1)))) { _ = try await r.update(heavy) }
        await #expect(throws: ApplicationRepositoryError.wouldNotReadBack(file: appFile(appID(2)))) {
            var other = application(2); other.setLetter(big); _ = try await r.create(other)
        }
        #expect(try await r.load(appID(1)) == v1)
        #expect(try await r.list().applications.map(\.id) == [appID(1)])
        await #expect(throws: AuthoringError.tooLarge) { _ = try await UpdateApplicationLetter(repository: r)(v1, to: big) }
        let roomy = appRepo(dir)
        #expect(try await roomy.update(heavy).letter == big)
    }

    @Test("a clock with fractional seconds still round-trips: timestamps are stored to the second")
    func fractionalClock() async throws {
        struct Fractional: TimeSource { func now() -> Date { Date(timeIntervalSince1970: 1_700_000_000.7654) } }
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let r = FileApplicationRepository(directory: dir, clock: Fractional())
        let v1 = try await r.create(application())
        #expect(try await r.load(appID(1)) == v1)
        var edited = v1
        edited.setLetter(try CoverLetter(recipient: LetterRecipient(), paragraphs: ["x"]))
        #expect(try await r.update(edited).revision == 2)
    }

    @Test("a failing quarantine does not hide the healthy applications")
    func quarantineFails() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let r = appRepo(dir)
        _ = try await r.create(application(1))
        try Data("x".utf8).write(to: dir.appendingPathComponent("Quarantine"))          // a file where the folder should be
        try write("{", to: dir.appendingPathComponent(appFile(appID(2))))
        let listing = try await r.list()
        #expect(listing.applications.map(\.id) == [appID(1)])
        #expect(listing.issues == [.quarantineFailed(file: appFile(appID(2)))])
    }

    @Test("restore: repaired files come back only through the read checks; hostile names and links are refused")
    func restore() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let r = appRepo(dir)
        let name = appFile(appID(1))
        for _ in 0..<2 { try write("{", to: dir.appendingPathComponent(name)); _ = try await r.list() }
        #expect(Set(try FileManager.default.contentsOfDirectory(atPath: dir.appendingPathComponent("Quarantine").path)) == ["1~\(name)", name])
        for hostile in ["../\(name)", "1~../../\(name)", "../../etc/passwd", "\(name)\n", "x.application.json", "\(appID(1).raw.uuidString).cv.json"] {
            await #expect(throws: ApplicationRepositoryError.invalidName(hostile)) { _ = try await r.restore(quarantined: hostile) }
        }
        await #expect(throws: ApplicationRepositoryError.corrupt(file: "1~\(name)")) { _ = try await r.restore(quarantined: "1~\(name)") }
        // A repaired file passes the same size cap as a read; a failed restore leaves both folders unchanged.
        let small = FileApplicationRepository(directory: dir, clock: SteppingClock(), maxFileBytes: 64)
        try write(try appJSON(), to: dir.appendingPathComponent("Quarantine/1~\(name)"))
        await #expect(throws: ApplicationRepositoryError.tooLarge(file: "1~\(name)")) { _ = try await small.restore(quarantined: "1~\(name)") }
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("Quarantine/1~\(name)").path))
        #expect(!FileManager.default.fileExists(atPath: dir.appendingPathComponent(name).path))
        #expect(try await r.restore(quarantined: "1~\(name)").id == appID(1))
        await #expect(throws: ApplicationRepositoryError.alreadyExists(appID(1))) { _ = try await r.restore(quarantined: name) }
        let link = appFile(appID(2))
        try FileManager.default.createSymbolicLink(atPath: dir.appendingPathComponent("Quarantine/\(link)").path, withDestinationPath: dir.appendingPathComponent(name).path)
        await #expect(throws: ApplicationRepositoryError.unreadable(file: link)) { _ = try await r.restore(quarantined: link) }
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("Quarantine/\(link)").path))
        #expect(!FileManager.default.fileExists(atPath: dir.appendingPathComponent(link).path))
    }

    @Test("erase removes every copy, whatever its schema or state, and the CV inside goes with it")
    func erase() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let r = appRepo(dir)
        let name = appFile(appID(1))
        try write("{", to: dir.appendingPathComponent("Quarantine/\(name)"))
        try write("{", to: dir.appendingPathComponent("Quarantine/1~\(name)"))
        try write(try appJSON(version: 3), to: dir.appendingPathComponent(name))
        _ = try await r.create(application(2))
        try await r.erase(appID(1))
        #expect(!FileManager.default.fileExists(atPath: dir.appendingPathComponent(name).path))
        #expect(try FileManager.default.contentsOfDirectory(atPath: dir.appendingPathComponent("Quarantine").path).isEmpty)
        #expect(try await r.list().applications.map(\.id) == [appID(2)])
    }

    @Test("the quarantine purge removes only old entries")
    func purge() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let q = dir.appendingPathComponent("Quarantine")
        try write("{", to: q.appendingPathComponent("old"))
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 0)], ofItemAtPath: q.appendingPathComponent("old").path)
        try write("{", to: q.appendingPathComponent("new"))
        #expect(try await appRepo(dir).purgeQuarantine(olderThan: Date(timeIntervalSince1970: 1_000)) == 1)
        #expect(try FileManager.default.contentsOfDirectory(atPath: q.path) == ["new"])
    }

    @Test("an embedded identifier that differs from the file name is corrupt")
    func identityMismatch() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        try write(try appJSON(application(2)), to: dir.appendingPathComponent(appFile(appID(1))))
        await #expect(throws: ApplicationRepositoryError.corrupt(file: appFile(appID(1)))) { _ = try await appRepo(dir).load(appID(1)) }
    }

    @Test("an unreadable store is an error, a missing one is a first run")
    func unreadableStore() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        try Data("x".utf8).write(to: dir)
        await #expect(throws: ApplicationRepositoryError.storeUnavailable(.notADirectory)) { _ = try await appRepo(dir).list() }
        #expect(try await appRepo(tempDir()).list().applications.isEmpty)
    }

    @Test("a named pipe in place of an application is unreadable, and never blocks the store", .timeLimit(.minutes(1)))
    func namedPipe() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let r = appRepo(dir)
        _ = try await r.create(application(1))
        #expect(mkfifo(dir.appendingPathComponent(appFile(appID(2))).path, 0o600) == 0)
        #expect(try await r.list().issues == [.unreadable(file: appFile(appID(2)))])
        await #expect(throws: ApplicationRepositoryError.unreadable(file: appFile(appID(2)))) { _ = try await r.load(appID(2)) }
        #expect(try await r.create(application(3)).id == appID(3))
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent(appFile(appID(2))).path))
    }

    @Test("a lock file that is a link is not followed: nothing is created through it, and the store is unavailable")
    func linkedLock() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let target = dir.appendingPathComponent("elsewhere")
        try FileManager.default.createSymbolicLink(at: dir.appendingPathComponent(".lock"), withDestinationURL: target)
        await #expect(throws: ApplicationRepositoryError.storeUnavailable(.cannotLock)) { _ = try await appRepo(dir).create(application()) }
        #expect(!FileManager.default.fileExists(atPath: target.path))
    }

    @Test("a quarantine that is a link is never used: a corrupt file stays, erase and restore refuse")
    func linkedQuarantine() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let r = appRepo(dir)
        _ = try await r.create(application(1))
        let elsewhere = dir.appendingPathComponent("elsewhere", isDirectory: true)
        try FileManager.default.createDirectory(at: elsewhere, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: dir.appendingPathComponent("Quarantine"), withDestinationURL: elsewhere)
        try write("{", to: dir.appendingPathComponent(appFile(appID(2))))
        #expect(try await r.list().issues == [.quarantineFailed(file: appFile(appID(2)))])
        try write("{", to: elsewhere.appendingPathComponent(appFile(appID(1))))
        await #expect(throws: ApplicationRepositoryError.storeUnavailable(.notADirectory)) { try await r.erase(appID(1)) }
        await #expect(throws: ApplicationRepositoryError.storeUnavailable(.notADirectory)) { _ = try await r.restore(quarantined: appFile(appID(1))) }
        await #expect(throws: ApplicationRepositoryError.storeUnavailable(.notADirectory)) { _ = try await r.purgeQuarantine(olderThan: .distantFuture) }
        #expect(FileManager.default.fileExists(atPath: elsewhere.appendingPathComponent(appFile(appID(1))).path))
    }

    @Test("a store that exists but cannot be reached is an error, never an empty store", .enabled(if: !isRoot))
    func unreachableStore() async throws {
        let parent = tempDir(); defer { chmod(parent.path, 0o755); try? FileManager.default.removeItem(at: parent) }
        let dir = parent.appendingPathComponent("store")
        _ = try await appRepo(dir).create(application(1))
        chmod(parent.path, 0)
        await #expect(throws: ApplicationRepositoryError.storeUnavailable(.cannotList)) { _ = try await appRepo(dir).list() }
        await #expect(throws: ApplicationRepositoryError.unreadable(file: appFile(appID(1)))) { _ = try await appRepo(dir).load(appID(1)) }
    }

    @Test("a store behind a link whose target is gone is an error, never an empty store")
    func danglingStore() async throws {
        let parent = tempDir(); defer { try? FileManager.default.removeItem(at: parent) }
        let target = parent.appendingPathComponent("target", isDirectory: true), link = parent.appendingPathComponent("store")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        _ = try await appRepo(link).create(application(1))
        try FileManager.default.removeItem(at: target)
        await #expect(throws: ApplicationRepositoryError.storeUnavailable(.cannotList)) { _ = try await appRepo(link).list() }
        await #expect(throws: ApplicationRepositoryError.storeUnavailable(.cannotList)) { _ = try await appRepo(link).load(appID(1)) }
        await #expect(throws: AuthoringError.unavailable) { _ = try await LoadApplication(repository: appRepo(link))(appID(1)) }
    }

    @Test("the retention period starts when a file enters the quarantine, not when it was last changed")
    func retentionStartsAtQuarantine() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let r = appRepo(dir)
        _ = try await r.create(application(1))
        let corrupt = dir.appendingPathComponent(appFile(appID(2)))
        try write("{", to: corrupt)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 0)], ofItemAtPath: corrupt.path)
        #expect(try await r.list().issues == [.corrupt(file: appFile(appID(2)), reason: "no schemaVersion envelope")])
        #expect(try await r.purgeQuarantine(olderThan: Date(timeIntervalSince1970: 1_000)) == 0)
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("Quarantine/\(appFile(appID(2)))").path))
    }

    @Test("erase fails when a copy cannot be inspected, rather than report every copy gone", .enabled(if: !isRoot))
    func eraseInaccessibleCopy() async throws {
        let dir = tempDir()
        let q = dir.appendingPathComponent("Quarantine")
        defer { chmod(q.path, 0o755); try? FileManager.default.removeItem(at: dir) }
        try write("{", to: q.appendingPathComponent(appFile(appID(1))))
        chmod(q.path, 0o600)                                     // names can be listed, entries cannot be inspected
        await #expect(throws: ApplicationRepositoryError.self) { try await appRepo(dir).erase(appID(1)) }
        chmod(q.path, 0o755)
        #expect(FileManager.default.fileExists(atPath: q.appendingPathComponent(appFile(appID(1))).path))
    }

    @Test("loading an application from a store that has disappeared reports the store, not the application deleted")
    func vanishedStore() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        _ = try await appRepo(dir).create(application(1))
        try FileManager.default.removeItem(at: dir)
        await #expect(throws: ApplicationRepositoryError.storeUnavailable(.cannotList)) { _ = try await appRepo(dir).load(appID(1)) }
        await #expect(throws: AuthoringError.unavailable) { _ = try await LoadApplication(repository: appRepo(dir))(appID(1)) }
        #expect(try await appRepo(dir).list().applications.isEmpty)                     // a listing still reads as a first run
    }

    @Test("two repository instances on one store cannot both win a race")
    func twoInstances() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let a = appRepo(dir), b = appRepo(dir)
        let v1 = try await a.create(application(1))
        let wins = await withTaskGroup(of: Bool.self) { group in
            for n in 0..<40 {
                let target = n.isMultiple(of: 2) ? a : b
                group.addTask {
                    var edited = v1
                    guard let letter = try? CoverLetter(recipient: LetterRecipient(), paragraphs: ["W\(n)"]) else { return false }
                    edited.setLetter(letter)
                    return (try? await target.update(edited)) != nil
                }
            }
            return await group.reduce(0) { $0 + ($1 ? 1 : 0) }
        }
        #expect(wins == 1)
    }

    @Test("two repository instances creating for one job leave one application, and every caller gets it")
    func twoInstancesOneJob() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let a = appRepo(dir), b = appRepo(dir)
        let ids = await withTaskGroup(of: ApplicationID?.self) { group in
            for n in 1...40 {
                let target = n.isMultiple(of: 2) ? a : b
                group.addTask { (try? await target.create(application(n, job: "one job")))?.id }
            }
            return await group.reduce(into: Set<ApplicationID?>()) { $0.insert($1) }
        }
        let held = try await a.list().applications
        #expect(held.count == 1 && ids == [held.first?.id])
    }

    @Test("keeping a result is not refused for another file: a corrupt, newer or unreadable file does not hold the job, and nothing is quarantined")
    func createBesideBadFiles() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        try write("{", to: dir.appendingPathComponent(appFile(appID(2))))
        try write(try appJSON(application(3), version: 2), to: dir.appendingPathComponent(appFile(appID(3))))
        let r = appRepo(dir)
        #expect(try await r.create(application(1)).id == appID(1))
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent(appFile(appID(2))).path))
        #expect(!FileManager.default.fileExists(atPath: dir.appendingPathComponent("Quarantine").path))
    }

    @Test("a file that names the job but does not read strictly does not hold it: another application is kept, and the file is left alone")
    func createBesideFileThatNamesTheJob() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let broken = try appJSON(application(2, job: "one job")).replacingOccurrences(of: #""fullName":"Ada""#, with: #""fullName":" ""#)
        #expect(broken.contains(#""jobID":"one job""#) && broken.contains(#""fullName":" ""#))
        try write(broken, to: dir.appendingPathComponent(appFile(appID(2))))
        let mismatched = try appJSON(application(4, job: "one job"))                         // named for application 3, holding application 4
        try write(mismatched, to: dir.appendingPathComponent(appFile(appID(3))))
        let r = appRepo(dir)
        let kept = try await r.create(application(1, job: "one job"))
        #expect(kept.id == appID(1) && kept.provenance.jobID.raw == "one job")
        #expect(try String(contentsOf: dir.appendingPathComponent(appFile(appID(2))), encoding: .utf8) == broken)
        #expect(try String(contentsOf: dir.appendingPathComponent(appFile(appID(3))), encoding: .utf8) == mismatched)
        #expect(!exists(dir.appendingPathComponent("Quarantine")))
        #expect(try await r.create(application(5, job: "one job")) == kept)
    }

    @Test("every write is atomic and asks for complete data protection")
    func writeOptions() {
        #expect(StoreWriting.options.contains(.atomic) && StoreWriting.options.contains(.completeFileProtection))
    }

    #if os(iOS)
    @Test("a stored application has complete data protection: it cannot be read while the device is locked",
          .enabled(if: !runningInSimulator, "the simulator neither applies nor reports data protection"))
    func dataProtection() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        _ = try await appRepo(dir).create(application(1))
        let attributes = try FileManager.default.attributesOfItem(atPath: dir.appendingPathComponent(appFile(appID(1))).path)
        #expect(attributes[.protectionKey] as? FileProtectionType == .complete, "protection: \(String(describing: attributes[.protectionKey]))")
    }
    #endif
}

@Suite("R10 · application repository contract, file adapter")
struct FileApplicationContractTests {
    @Test("the file adapter passes")
    func file() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        try await ApplicationRepositoryContract.verify(appRepo(dir))
    }
}
