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

func tempDir() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("adr-spike-\(UUID().uuidString)") }   // hermetic (R10)
let id1 = CVID(UUID(uuidString: "11111111-1111-1111-1111-111111111111")!)
let id2 = CVID(UUID(uuidString: "22222222-2222-2222-2222-222222222222")!)
let isRoot = geteuid() == 0

func fileJSON(id: String = id1.raw.uuidString, revision: String = "1", experiences: String = "[]", version: Int = 1, email: String = "null") -> String {
    #"{"schemaVersion":\#(version),"id":"\#(id)","revision":\#(revision),"createdAt":"2024-01-01T00:00:00Z","updatedAt":"2024-01-01T00:00:00Z","title":"","fullName":"A","email":\#(email),"experiences":\#(experiences),"skills":[]}"#
}
func decode(_ json: String) throws -> CV {
    let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601
    return try d.decode(CVFileV1.self, from: Data(json.utf8)).toDomain()
}
func exp(_ start: String, _ end: String, _ current: Bool) -> String {
    #"[{"role":"r","company":"c","description":"","start":\#(start),"end":\#(end),"current":\#(current)}]"#
}
func repo(_ dir: URL) -> FileCVRepository { FileCVRepository(directory: dir, clock: SteppingClock()) }

@Suite("R6 · rich domain")
struct DomainTests {
    @Test("invalid values cannot exist; validators reject trailing newlines")
    func invariants() {
        #expect(SkillLevel(0) == nil && SkillLevel(6) == nil && SkillLevel(3) != nil)
        #expect(EmailAddress("a@b.") == nil && EmailAddress("ada@example.com") != nil)
        #expect(EmailAddress("ada@example.com\n")?.value == "ada@example.com")     // normalised, never stored with a newline
        #expect(!CV(id: id1, fullName: "\n").canBeSaved && CV(id: id1, fullName: "Ada").canBeSaved)
    }
    @Test("mixed precision is ordered by year when months are unknown (review 14)")
    func mixedPrecision() throws {
        #expect(try Period.make(start: (2020, 5), end: (2020, nil), current: false) != nil)
        #expect(try Period.make(start: (2020, nil), end: (2020, 3), current: false) != nil)
        #expect(throws: PeriodError.endBeforeStart) { _ = try Period.make(start: (2020, 5), end: (2020, 3), current: false) }
    }
    @Test("one rule for every period shape", arguments: [
        (nil, nil, true, PeriodError.currentWithoutStart), (nil, (2020, nil), false, .endWithoutStart),
        ((2020, nil), (2021, nil), true, .currentWithEndDate), ((2020, 13), nil, false, .invalidDate), ((2020, nil), (9999, nil), false, .invalidDate),
    ] as [((Int, Int?)?, (Int, Int?)?, Bool, PeriodError)])
    func periodErrors(start: (Int, Int?)?, end: (Int, Int?)?, current: Bool, error: PeriodError) {
        #expect(throws: error) { _ = try Period.make(start: start.map { (year: $0.0, month: $0.1) }, end: end.map { (year: $0.0, month: $0.1) }, current: current) }
    }
}

@Suite("ADR 0009 · strict decoding")
struct DecodingTests {
    @Test("{} is not a CV") func emptyObject() { #expect(throws: DecodingError.self) { try decode("{}") } }
    @Test("missing id is rejected, not regenerated")
    func missingID() { #expect(throws: DecodingError.self) { try decode(fileJSON().replacingOccurrences(of: #""id":"11111111-1111-1111-1111-111111111111","#, with: "")) } }
    @Test("revision must be present and within bounds (review 15, L1)", arguments: ["0", "-1", "\(Int.max)"])
    func revisionBounds(revision: String) { #expect(throws: CVFileV1.Invalid.self) { try decode(fileJSON(revision: revision)) } }
    @Test("missing revision is rejected") func missingRevision() {
        #expect(throws: DecodingError.self) { try decode(fileJSON().replacingOccurrences(of: #""revision":1,"#, with: "")) }
    }
    @Test("out-of-range values are rejected")
    func invalidLevel() { #expect(throws: CVFileV1.Invalid.self) { try decode(fileJSON().replacingOccurrences(of: #""skills":[]"#, with: #""skills":[{"name":"x","level":9}]"#)) } }
    @Test("an invalid date with a valid start is rejected (L1)")
    func invalidMonth() { #expect(throws: CVFileV1.Invalid.self) { try decode(fileJSON(experiences: exp(#"{"year":2020,"month":13}"#, "null", false))) } }
    @Test("an email with a trailing newline in the file is corrupt, not silently normalised")
    func emailNewline() { #expect(throws: CVFileV1.Invalid.self) { try decode(fileJSON(email: #""ada@example.com\n""#)) } }
    @Test("start without end and not current stays 'ended, date unknown'")
    func startOnly() throws { #expect(try decode(fileJSON(experiences: exp(#"{"year":2020}"#, "null", false))).experiences.first?.period?.end == .unknown) }
}

@Suite("ADR 0009 · file repository")
struct FileRepositoryTests {
    @Test("mixed directory: healthy listed, corrupt quarantined with a reason, newer schema untouched")
    func mixedDirectory() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let r = repo(dir)
        let healthy = try await r.create(CV(id: id1, fullName: "Ada"))
        try Data("{".utf8).write(to: dir.appendingPathComponent("\(id2.raw.uuidString).cv.json"))
        let newerName = "33333333-3333-3333-3333-333333333333.cv.json"
        let newer = fileJSON(id: "33333333-3333-3333-3333-333333333333", version: 2)
        try Data(newer.utf8).write(to: dir.appendingPathComponent(newerName))
        let listing = try await r.list()
        #expect(listing.cvs == [healthy])
        #expect(listing.issues == [.corrupt(file: "\(id2.raw.uuidString).cv.json", reason: "no schemaVersion envelope"), .upgradeRequired(file: newerName, version: 2)])
        #expect(try String(contentsOf: dir.appendingPathComponent(newerName), encoding: .utf8) == newer)
    }

    @Test("an unreadable file is reported and left in place, never quarantined (security S2, review H4)", .enabled(if: !isRoot))
    func unreadableNotQuarantined() async throws {
        let dir = tempDir(); defer { chmod(dir.appendingPathComponent("\(id1.raw.uuidString).cv.json").path, 0o644); try? FileManager.default.removeItem(at: dir) }
        let r = repo(dir)
        _ = try await r.create(CV(id: id1, fullName: "Ada"))
        let path = dir.appendingPathComponent("\(id1.raw.uuidString).cv.json").path
        chmod(path, 0)
        #expect(try await r.list().issues == [.unreadable(file: "\(id1.raw.uuidString).cv.json")])
        #expect(FileManager.default.fileExists(atPath: path))
        chmod(path, 0o644)
        #expect(try await r.list().cvs.map(\.id) == [id1])
    }

    @Test("an oversized file is reported without being read (security S3)")
    func tooLarge() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data(count: 2048).write(to: dir.appendingPathComponent("\(id1.raw.uuidString).cv.json"))
        let r = FileCVRepository(directory: dir, clock: SteppingClock(), maxFileBytes: 1024)
        #expect(try await r.list().issues == [.tooLarge(file: "\(id1.raw.uuidString).cv.json", bytes: 2048)])
    }

    @Test("a save that would not read back is refused and the previous version stays (review round 2)")
    func wouldNotReadBack() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let r = FileCVRepository(directory: dir, clock: SteppingClock(), maxFileBytes: 4096)
        let v1 = try await r.create(CV(id: id1, fullName: "Ada"))
        var big = v1; big.addExperience(Experience(role: String(repeating: "𝒜", count: 2000), company: "c"))   // 4-byte scalars
        await #expect(throws: RepositoryError.wouldNotReadBack(file: "\(id1.raw.uuidString).cv.json")) { _ = try await r.update(big) }
        var long = v1; long.addExperience(Experience(role: String(repeating: "x", count: 10_001), company: "c"))  // under the size cap, over the text cap
        let roomy = FileCVRepository(directory: dir, clock: SteppingClock())
        await #expect(throws: RepositoryError.wouldNotReadBack(file: "\(id1.raw.uuidString).cv.json")) { _ = try await roomy.update(long) }
        await #expect(throws: RepositoryError.wouldNotReadBack(file: "\(id2.raw.uuidString).cv.json")) {
            _ = try await r.create(CV(id: id2, fullName: String(repeating: "𝒜", count: 2000)))
        }
        #expect(try await roomy.load(id1) == v1)
        #expect(try await roomy.list().cvs.map(\.id) == [id1])
        await #expect(throws: AuthoringError.tooLarge) { _ = try await SaveCV(repository: r)(big) }
    }

    @Test("a clock with fractional seconds still round-trips (timestamps are normalised)")
    func fractionalClock() async throws {
        struct Fractional: TimeSource { func now() -> Date { Date(timeIntervalSince1970: 1_700_000_000.7654) } }
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let r = FileCVRepository(directory: dir, clock: Fractional())
        let v1 = try await r.create(CV(id: id1, fullName: "Ada"))
        #expect(try await r.load(id1) == v1)
        var v = v1; v.rename("x")
        #expect(try await r.update(v).revision == 2)
    }

    @Test("a failing quarantine does not hide the healthy CVs (security S4)")
    func quarantineFails() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let r = repo(dir)
        _ = try await r.create(CV(id: id1, fullName: "Ada"))
        try Data("x".utf8).write(to: dir.appendingPathComponent("Quarantine"))          // a file where the folder should be
        try Data("{".utf8).write(to: dir.appendingPathComponent("\(id2.raw.uuidString).cv.json"))
        let listing = try await r.list()
        #expect(listing.cvs.map(\.id) == [id1])
        #expect(listing.issues == [.quarantineFailed(file: "\(id2.raw.uuidString).cv.json")])
    }

    @Test("restore: repaired files come back only through the read checks; hostile names and symlinks are refused (security S5)")
    func restore() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let r = repo(dir)
        let name = "\(id1.raw.uuidString).cv.json"
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for _ in 0..<2 { try Data("{".utf8).write(to: dir.appendingPathComponent(name)); _ = try await r.list() }
        #expect(Set(try FileManager.default.contentsOfDirectory(atPath: dir.appendingPathComponent("Quarantine").path)) == ["1~\(name)", name])
        for hostile in ["../\(name)", "1~../../\(name)", "../../etc/passwd", "\(name)\n", "x.cv.json"] {
            await #expect(throws: RepositoryError.invalidName(hostile)) { _ = try await r.restore(quarantined: hostile) }
        }
        await #expect(throws: RepositoryError.corrupt(file: "1~\(name)")) { _ = try await r.restore(quarantined: "1~\(name)") }
        // A repaired file must pass the same size cap as a read; a failed restore leaves both folders unchanged (review round 3).
        let small = FileCVRepository(directory: dir, clock: SteppingClock(), maxFileBytes: 64)
        try Data(fileJSON().utf8).write(to: dir.appendingPathComponent("Quarantine/1~\(name)"))
        await #expect(throws: RepositoryError.tooLarge(file: "1~\(name)")) { _ = try await small.restore(quarantined: "1~\(name)") }
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("Quarantine/1~\(name)").path))
        #expect(!FileManager.default.fileExists(atPath: dir.appendingPathComponent(name).path))
        #expect(try await r.restore(quarantined: "1~\(name)").id == id1)
        let link = "22222222-2222-2222-2222-222222222222.cv.json"
        try FileManager.default.createSymbolicLink(atPath: dir.appendingPathComponent("Quarantine/\(link)").path, withDestinationPath: dir.appendingPathComponent(name).path)
        await #expect(throws: RepositoryError.self) { _ = try await r.restore(quarantined: link) }
    }

    @Test("erase removes every copy, whatever its schema or state (GDPR)")
    func erase() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let r = repo(dir)
        let name = "\(id1.raw.uuidString).cv.json"
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("Quarantine"), withIntermediateDirectories: true)
        try Data("{".utf8).write(to: dir.appendingPathComponent("Quarantine/\(name)"))
        try Data("{".utf8).write(to: dir.appendingPathComponent("Quarantine/1~\(name)"))
        try Data(fileJSON(version: 3).utf8).write(to: dir.appendingPathComponent(name))
        try await r.erase(id1)
        #expect(!FileManager.default.fileExists(atPath: dir.appendingPathComponent(name).path))
        #expect(try FileManager.default.contentsOfDirectory(atPath: dir.appendingPathComponent("Quarantine").path).isEmpty)
    }

    @Test("quarantine purge removes only old entries")
    func purge() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let r = repo(dir)
        let q = dir.appendingPathComponent("Quarantine")
        try FileManager.default.createDirectory(at: q, withIntermediateDirectories: true)
        try Data("{".utf8).write(to: q.appendingPathComponent("old"))
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 0)], ofItemAtPath: q.appendingPathComponent("old").path)
        try Data("{".utf8).write(to: q.appendingPathComponent("new"))
        #expect(try await r.purgeQuarantine(olderThan: Date(timeIntervalSince1970: 1_000)) == 1)
        #expect(try FileManager.default.contentsOfDirectory(atPath: q.path) == ["new"])
    }

    @Test("an embedded id that differs from the file name is corrupt")
    func identityMismatch() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data(fileJSON(id: id2.raw.uuidString).utf8).write(to: dir.appendingPathComponent("\(id1.raw.uuidString).cv.json"))
        await #expect(throws: RepositoryError.corrupt(file: "\(id1.raw.uuidString).cv.json")) { _ = try await repo(dir).load(id1) }
    }

    @Test("an unreadable store is an error, a missing one is a first run")
    func unreadableStore() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        try Data("x".utf8).write(to: dir)
        await #expect(throws: RepositoryError.storeUnavailable(.notADirectory)) { _ = try await repo(dir).list() }
        #expect(try await repo(tempDir()).list().cvs.isEmpty)
    }

    @Test("two repository instances on one store cannot both win a race (review 3)")
    func twoInstances() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let a = repo(dir), b = repo(dir)
        let v1 = try await a.create(CV(id: id1, fullName: "Ada"))
        let wins = await withTaskGroup(of: Bool.self) { group in
            for n in 0..<40 {
                let target = n.isMultiple(of: 2) ? a : b
                group.addTask { var c = v1; c.rename("W\(n)"); return (try? await target.update(c)) != nil }
            }
            return await group.reduce(0) { $0 + ($1 ? 1 : 0) }
        }
        #expect(wins == 1)
    }
}

@Suite("R10 · repository contract")
struct ContractTests {
    @Test("in-memory adapter passes") func inMemory() async throws { try await CVRepositoryContract.verify(InMemoryCVRepository()) }
    @Test("file adapter passes")
    func file() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        try await CVRepositoryContract.verify(repo(dir))
    }
}

@Suite("use cases")
struct UseCaseTests {
    @Test("save creates once, then updates; errors are translated (#4, #5)")
    func saveCreatesThenUpdates() async throws {
        let r = InMemoryCVRepository()
        var cv = NewCV(ids: SequentialIDGenerator())()
        cv.setPerson(fullName: "Ada", email: nil)
        cv = try await SaveCV(repository: r)(cv)
        cv.rename("iOS – Apple")
        let saved = try await SaveCV(repository: r)(cv)
        let listed = try await r.list().cvs
        #expect(saved.revision == 2 && listed == [saved])
        await #expect(throws: AuthoringError.conflict(storedRevision: 2)) { _ = try await SaveCV(repository: r)(cv) }
        try await r.delete(saved.id, revision: 2)
        await #expect(throws: AuthoringError.deletedElsewhere) { _ = try await SaveCV(repository: r)(saved) }
    }
    @Test("an empty CV is not persisted")
    func emptyRejected() async { await #expect(throws: AuthoringError.notEnoughContent) { _ = try await SaveCV(repository: InMemoryCVRepository())(CV(id: id1)) } }
}
