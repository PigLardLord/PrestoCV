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

#if targetEnvironment(simulator)
let runningInSimulator = true
#else
let runningInSimulator = false
#endif

func tempDir() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("cv-store-\(UUID().uuidString)") }   // hermetic (R10)
let id1 = CVID(UUID(uuidString: "11111111-1111-1111-1111-111111111111")!)
let id2 = CVID(UUID(uuidString: "22222222-2222-2222-2222-222222222222")!)
let isRoot = geteuid() == 0
func named(_ name: String, id: CVID = id1) -> CV { CV(id: id, personal: PersonalDetails(fullName: name)) }
func repo(_ dir: URL) -> FileCVRepository { FileCVRepository(directory: dir, clock: SteppingClock()) }
func fileName(_ id: CVID) -> String { "\(id.raw.uuidString).cv.json" }

/// A stored CV in schema 1, minimal unless a field is given. `sections` replaces a section's JSON by its key.
func fileJSON(id: String = id1.raw.uuidString, revision: String = "1", version: Int = 1,
              personal: String = #"{"fullName":"A","professionalTitle":"","location":"","summary":""}"#,
              sections: [String: String] = [:], extra: String = "") -> String {
    let keys = ["experiences", "education", "skills", "languages", "certifications", "profiles", "interests"]
    let body = keys.map { #""\#($0)":\#(sections[$0] ?? "[]")"# }.joined(separator: ",")
    return #"{"schemaVersion":\#(version),"id":"\#(id)","revision":\#(revision),"createdAt":"2024-01-01T00:00:00Z","#
        + #""updatedAt":"2024-01-01T00:00:00Z","title":"","personal":\#(personal),\#(body)\#(extra)}"#
}

func decode(_ json: String) throws -> CV { try CVFileV1.decode(Data(json.utf8)).toDomain() }

/// The minimal personal details with `field` set to the JSON `value`, each key once.
func personal(_ field: String, _ value: String) -> String {
    var fields = ["fullName": #""A""#, "professionalTitle": #""""#, "location": #""""#, "summary": #""""#]
    fields[field] = value
    return "{" + fields.sorted { $0.key < $1.key }.map { #""\#($0.key)":\#($0.value)"# }.joined(separator: ",") + "}"
}

/// Files that must be corrupt, each with one value out of its canonical, valid form. Built one by one, so the type
/// checker stays fast.
let corruptFiles: [String] = {
    var files: [String] = []
    files.append(fileJSON(personal: personal("email", #""ada@example.com\n""#)))
    files.append(fileJSON(personal: personal("email", #""not an address""#)))
    files.append(fileJSON(personal: personal("phone", #""+39 06\n1234""#)))
    files.append(fileJSON(personal: personal("website", #""javascript:alert(1)""#)))
    files.append(fileJSON(personal: personal("website", #"" https://ada.example""#)))
    files.append(fileJSON(sections: ["skills": #"[{"name":"x","level":9}]"#]))
    files.append(fileJSON(sections: ["experiences": #"[{"role":"r","company":"c","location":"","description":"","start":{"year":2020,"month":13},"current":false}]"#]))
    files.append(fileJSON(sections: ["experiences": #"[{"role":"r","company":"c","location":"","description":"","end":{"year":2020},"current":false}]"#]))
    files.append(fileJSON(sections: ["education": #"[{"degree":"d","school":"s","description":"","start":{"year":2020},"end":{"year":2019},"current":false}]"#]))
    files.append(fileJSON(sections: ["languages": #"[{"language":"Italian","proficiency":"z9"}]"#]))
    files.append(fileJSON(sections: ["certifications": #"[{"name":"n","issuer":"i","description":"","issued":{"year":2021,"month":0}}]"#]))
    files.append(fileJSON(sections: ["certifications": #"[{"name":"n","issuer":"i","description":"","link":"ftp://x.example"}]"#]))
    files.append(fileJSON(sections: ["profiles": #"[{"platform":"GitHub","link":"https://user:pw@github.com"}]"#]))
    files.append(fileJSON(sections: ["interests": #"[" Chess ","chess"]"#]))
    files.append(fileJSON(extra: #","design":{"design":"../evil"}"#))
    files.append(fileJSON(extra: #","language":"italian""#))
    files.append(fileJSON(extra: #","language":"PT-br""#))
    let longSummary = "\"" + String(repeating: "x", count: 10_001) + "\""
    files.append(fileJSON(personal: personal("summary", longSummary)))
    let interests: [String] = (0...500).map { "\"i\($0)\"" }
    files.append(fileJSON(sections: ["interests": "[" + interests.joined(separator: ",") + "]"]))
    return files
}()

@Suite("ADR 0009 · strict decoding of schema 1")
struct StrictDecodingTests {
    @Test("{} is not a CV") func emptyObject() { #expect(throws: (any Error).self) { try decode("{}") } }

    @Test("a missing identifier is rejected, not regenerated")
    func missingID() { #expect(throws: (any Error).self) { try decode(fileJSON().replacingOccurrences(of: #""id":"11111111-1111-1111-1111-111111111111","#, with: "")) } }

    @Test("the revision must be present and within bounds", arguments: ["0", "-1", "\(Int.max)"])
    func revisionBounds(revision: String) { #expect(throws: CVFileV1.Invalid.self) { try decode(fileJSON(revision: revision)) } }

    @Test("a minimal file decodes, and a start without an end that is not current stays 'ended, date unknown'")
    func minimal() throws {
        let experience = #"[{"role":"r","company":"c","location":"","description":"","start":{"year":2020},"current":false}]"#
        #expect(try decode(fileJSON(sections: ["experiences": experience])).sections.experiences.first?.period?.end == .unknown)
    }

    @Test("every value that is not in its canonical, valid form is corrupt, never normalised or defaulted", arguments: corruptFiles)
    func corrupt(json: String) { #expect(throws: CVFileV1.Invalid.self) { try decode(json) } }
}

@Suite("ADR 0009 · file repository")
struct FileRepositoryTests {
    @Test("every field survives a save and a load, in the repository's own format")
    func fullRoundTrip() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let saved = try await repo(dir).create(FixtureCV.full())
        let loaded = try await repo(dir).load(saved.id)
        #expect(loaded == saved)
        #expect(loaded.personal == FixtureCV.full().personal && loaded.sections == FixtureCV.full().sections)
        #expect(loaded.design == FixtureCV.full().design && loaded.language == FixtureCV.full().language && loaded.title == FixtureCV.full().title)
    }

    @Test("mixed directory: healthy listed, corrupt quarantined with a reason, newer schema untouched")
    func mixedDirectory() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let r = repo(dir)
        let healthy = try await r.create(named("Ada"))
        try Data("{".utf8).write(to: dir.appendingPathComponent(fileName(id2)))
        let newerName = "33333333-3333-3333-3333-333333333333.cv.json"
        let newer = fileJSON(id: "33333333-3333-3333-3333-333333333333", version: 2)
        try Data(newer.utf8).write(to: dir.appendingPathComponent(newerName))
        let listing = try await r.list()
        #expect(listing.cvs == [healthy])
        #expect(listing.issues == [.corrupt(file: fileName(id2), reason: "no schemaVersion envelope"), .upgradeRequired(file: newerName, version: 2)])
        #expect(try String(contentsOf: dir.appendingPathComponent(newerName), encoding: .utf8) == newer)
    }

    @Test("an unreadable file is reported and left in place, never quarantined", .enabled(if: !isRoot))
    func unreadableNotQuarantined() async throws {
        let dir = tempDir(); defer { chmod(dir.appendingPathComponent(fileName(id1)).path, 0o644); try? FileManager.default.removeItem(at: dir) }
        let r = repo(dir)
        _ = try await r.create(named("Ada"))
        let path = dir.appendingPathComponent(fileName(id1)).path
        chmod(path, 0)
        #expect(try await r.list().issues == [.unreadable(file: fileName(id1))])
        #expect(FileManager.default.fileExists(atPath: path))
        chmod(path, 0o644)
        #expect(try await r.list().cvs.map(\.id) == [id1])
    }

    @Test("an oversized file is reported without being read")
    func tooLarge() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data(count: 2048).write(to: dir.appendingPathComponent(fileName(id1)))
        let r = FileCVRepository(directory: dir, clock: SteppingClock(), maxFileBytes: 1024)
        #expect(try await r.list().issues == [.tooLarge(file: fileName(id1), bytes: 2048)])
    }

    @Test("a save that would not read back is refused and the previous version stays")
    func wouldNotReadBack() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let r = FileCVRepository(directory: dir, clock: SteppingClock(), maxFileBytes: 4096)
        let v1 = try await r.create(named("Ada"))
        func with(role: String) -> CV {
            var cv = v1, sections = v1.sections
            sections.experiences = [Experience(role: role, company: "c")]
            cv.setSections(sections)
            return cv
        }
        let big = with(role: String(repeating: "𝒜", count: 2000))                                  // 4-byte scalars: over the size cap
        await #expect(throws: RepositoryError.wouldNotReadBack(file: fileName(id1))) { _ = try await r.update(big) }
        let roomy = FileCVRepository(directory: dir, clock: SteppingClock())
        await #expect(throws: RepositoryError.wouldNotReadBack(file: fileName(id1))) { _ = try await roomy.update(with(role: String(repeating: "x", count: 10_001))) }
        await #expect(throws: RepositoryError.wouldNotReadBack(file: fileName(id2))) {
            _ = try await r.create(named(String(repeating: "𝒜", count: 2000), id: id2))
        }
        #expect(try await roomy.load(id1) == v1)
        #expect(try await roomy.list().cvs.map(\.id) == [id1])
        await #expect(throws: AuthoringError.tooLarge) { _ = try await SaveCV(repository: r)(big) }
    }

    @Test("a clock with fractional seconds still round-trips: timestamps are stored to the second")
    func fractionalClock() async throws {
        struct Fractional: TimeSource { func now() -> Date { Date(timeIntervalSince1970: 1_700_000_000.7654) } }
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let r = FileCVRepository(directory: dir, clock: Fractional())
        let v1 = try await r.create(named("Ada"))
        #expect(try await r.load(id1) == v1)
        var v = v1; v.rename("x")
        #expect(try await r.update(v).revision == 2)
    }

    @Test("a failing quarantine does not hide the healthy CVs")
    func quarantineFails() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let r = repo(dir)
        _ = try await r.create(named("Ada"))
        try Data("x".utf8).write(to: dir.appendingPathComponent("Quarantine"))          // a file where the folder should be
        try Data("{".utf8).write(to: dir.appendingPathComponent(fileName(id2)))
        let listing = try await r.list()
        #expect(listing.cvs.map(\.id) == [id1])
        #expect(listing.issues == [.quarantineFailed(file: fileName(id2))])
    }

    @Test("restore: repaired files come back only through the read checks; hostile names and links are refused")
    func restore() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let r = repo(dir)
        let name = fileName(id1)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for _ in 0..<2 { try Data("{".utf8).write(to: dir.appendingPathComponent(name)); _ = try await r.list() }
        #expect(Set(try FileManager.default.contentsOfDirectory(atPath: dir.appendingPathComponent("Quarantine").path)) == ["1~\(name)", name])
        for hostile in ["../\(name)", "1~../../\(name)", "../../etc/passwd", "\(name)\n", "x.cv.json"] {
            await #expect(throws: RepositoryError.invalidName(hostile)) { _ = try await r.restore(quarantined: hostile) }
        }
        await #expect(throws: RepositoryError.corrupt(file: "1~\(name)")) { _ = try await r.restore(quarantined: "1~\(name)") }
        // A repaired file passes the same size cap as a read; a failed restore leaves both folders unchanged.
        let small = FileCVRepository(directory: dir, clock: SteppingClock(), maxFileBytes: 64)
        try Data(fileJSON().utf8).write(to: dir.appendingPathComponent("Quarantine/1~\(name)"))
        await #expect(throws: RepositoryError.tooLarge(file: "1~\(name)")) { _ = try await small.restore(quarantined: "1~\(name)") }
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("Quarantine/1~\(name)").path))
        #expect(!FileManager.default.fileExists(atPath: dir.appendingPathComponent(name).path))
        #expect(try await r.restore(quarantined: "1~\(name)").id == id1)
        let link = fileName(id2)
        try FileManager.default.createSymbolicLink(atPath: dir.appendingPathComponent("Quarantine/\(link)").path, withDestinationPath: dir.appendingPathComponent(name).path)
        await #expect(throws: RepositoryError.unreadable(file: link)) { _ = try await r.restore(quarantined: link) }
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("Quarantine/\(link)").path))
        #expect(!FileManager.default.fileExists(atPath: dir.appendingPathComponent(link).path))
    }

    @Test("erase removes every copy, whatever its schema or state")
    func erase() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let r = repo(dir)
        let name = fileName(id1)
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("Quarantine"), withIntermediateDirectories: true)
        try Data("{".utf8).write(to: dir.appendingPathComponent("Quarantine/\(name)"))
        try Data("{".utf8).write(to: dir.appendingPathComponent("Quarantine/1~\(name)"))
        try Data(fileJSON(version: 3).utf8).write(to: dir.appendingPathComponent(name))
        try await r.erase(id1)
        #expect(!FileManager.default.fileExists(atPath: dir.appendingPathComponent(name).path))
        #expect(try FileManager.default.contentsOfDirectory(atPath: dir.appendingPathComponent("Quarantine").path).isEmpty)
    }

    @Test("the quarantine purge removes only old entries")
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

    @Test("an embedded identifier that differs from the file name is corrupt")
    func identityMismatch() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data(fileJSON(id: id2.raw.uuidString).utf8).write(to: dir.appendingPathComponent(fileName(id1)))
        await #expect(throws: RepositoryError.corrupt(file: fileName(id1))) { _ = try await repo(dir).load(id1) }
    }

    @Test("an unreadable store is an error, a missing one is a first run")
    func unreadableStore() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        try Data("x".utf8).write(to: dir)
        await #expect(throws: RepositoryError.storeUnavailable(.notADirectory)) { _ = try await repo(dir).list() }
        #expect(try await repo(tempDir()).list().cvs.isEmpty)
    }

    @Test("a named pipe in place of a CV is unreadable, and never blocks the store", .timeLimit(.minutes(1)))
    func namedPipe() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let r = repo(dir)
        _ = try await r.create(named("Ada"))
        #expect(mkfifo(dir.appendingPathComponent(fileName(id2)).path, 0o600) == 0)
        #expect(try await r.list().issues == [.unreadable(file: fileName(id2))])
        await #expect(throws: RepositoryError.unreadable(file: fileName(id2))) { _ = try await r.load(id2) }
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent(fileName(id2)).path))
    }

    @Test("a lock file that is a link is not followed: nothing is created through it, and the store is unavailable")
    func linkedLock() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let target = dir.appendingPathComponent("elsewhere")
        try FileManager.default.createSymbolicLink(at: dir.appendingPathComponent(".lock"), withDestinationURL: target)
        await #expect(throws: RepositoryError.storeUnavailable(.cannotLock)) { _ = try await repo(dir).create(named("Ada")) }
        #expect(!FileManager.default.fileExists(atPath: target.path))
    }

    @Test("a quarantine that is a link is never used: a corrupt file stays, erase and restore refuse")
    func linkedQuarantine() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let r = repo(dir)
        _ = try await r.create(named("Ada"))
        let elsewhere = dir.appendingPathComponent("elsewhere", isDirectory: true)
        try FileManager.default.createDirectory(at: elsewhere, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: dir.appendingPathComponent("Quarantine"), withDestinationURL: elsewhere)
        try Data("{".utf8).write(to: dir.appendingPathComponent(fileName(id2)))
        #expect(try await r.list().issues == [.quarantineFailed(file: fileName(id2))])
        try Data("{".utf8).write(to: elsewhere.appendingPathComponent(fileName(id1)))
        await #expect(throws: RepositoryError.storeUnavailable(.notADirectory)) { try await r.erase(id1) }
        await #expect(throws: RepositoryError.storeUnavailable(.notADirectory)) { _ = try await r.restore(quarantined: fileName(id1)) }
        await #expect(throws: RepositoryError.storeUnavailable(.notADirectory)) { _ = try await r.purgeQuarantine(olderThan: .distantFuture) }
        #expect(FileManager.default.fileExists(atPath: elsewhere.appendingPathComponent(fileName(id1)).path))
    }

    @Test("a store that exists but cannot be reached is an error, never an empty store", .enabled(if: !isRoot))
    func unreachableStore() async throws {
        let parent = tempDir(); defer { chmod(parent.path, 0o755); try? FileManager.default.removeItem(at: parent) }
        let dir = parent.appendingPathComponent("store")
        _ = try await repo(dir).create(named("Ada"))
        chmod(parent.path, 0)
        await #expect(throws: RepositoryError.storeUnavailable(.cannotList)) { _ = try await repo(dir).list() }
        await #expect(throws: RepositoryError.unreadable(file: fileName(id1))) { _ = try await repo(dir).load(id1) }
    }

    @Test("a store behind a link whose target is gone is an error, never an empty store")
    func danglingStore() async throws {
        let parent = tempDir(); defer { try? FileManager.default.removeItem(at: parent) }
        let target = parent.appendingPathComponent("target", isDirectory: true), link = parent.appendingPathComponent("store")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        _ = try await repo(link).create(named("Ada"))
        try FileManager.default.removeItem(at: target)
        await #expect(throws: RepositoryError.storeUnavailable(.cannotList)) { _ = try await repo(link).list() }
        await #expect(throws: RepositoryError.storeUnavailable(.cannotList)) { _ = try await repo(link).load(id1) }
        await #expect(throws: AuthoringError.unavailable) { _ = try await LoadCV(repository: repo(link))(id1) }
    }

    @Test("the retention period starts when a file enters the quarantine, not when it was last changed")
    func retentionStartsAtQuarantine() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let r = repo(dir)
        _ = try await r.create(named("Ada"))
        let corrupt = dir.appendingPathComponent(fileName(id2))
        try Data("{".utf8).write(to: corrupt)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 0)], ofItemAtPath: corrupt.path)
        #expect(try await r.list().issues == [.corrupt(file: fileName(id2), reason: "no schemaVersion envelope")])
        #expect(try await r.purgeQuarantine(olderThan: Date(timeIntervalSince1970: 1_000)) == 0)
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("Quarantine/\(fileName(id2))").path))
    }

    @Test("erase fails when a copy cannot be inspected, rather than report every copy gone", .enabled(if: !isRoot))
    func eraseInaccessibleCopy() async throws {
        let dir = tempDir()
        let q = dir.appendingPathComponent("Quarantine")
        defer { chmod(q.path, 0o755); try? FileManager.default.removeItem(at: dir) }
        let r = repo(dir)
        try FileManager.default.createDirectory(at: q, withIntermediateDirectories: true)
        try Data("{".utf8).write(to: q.appendingPathComponent(fileName(id1)))
        chmod(q.path, 0o600)                                     // names can be listed, entries cannot be inspected
        await #expect(throws: RepositoryError.self) { try await r.erase(id1) }
        chmod(q.path, 0o755)
        #expect(FileManager.default.fileExists(atPath: q.appendingPathComponent(fileName(id1)).path))
    }

    @Test("loading a CV from a store that has disappeared reports the store, not the CV deleted")
    func vanishedStore() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        _ = try await repo(dir).create(named("Ada"))
        try FileManager.default.removeItem(at: dir)
        await #expect(throws: RepositoryError.storeUnavailable(.cannotList)) { _ = try await repo(dir).load(id1) }
        await #expect(throws: AuthoringError.unavailable) { _ = try await LoadCV(repository: repo(dir))(id1) }
        #expect(try await repo(dir).list().cvs.isEmpty)                     // a listing still reads as a first run
    }

    @Test("two repository instances on one store cannot both win a race")
    func twoInstances() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let a = repo(dir), b = repo(dir)
        let v1 = try await a.create(named("Ada"))
        let wins = await withTaskGroup(of: Bool.self) { group in
            for n in 0..<40 {
                let target = n.isMultiple(of: 2) ? a : b
                group.addTask { var c = v1; c.rename("W\(n)"); return (try? await target.update(c)) != nil }
            }
            return await group.reduce(0) { $0 + ($1 ? 1 : 0) }
        }
        #expect(wins == 1)
    }

    @Test("every write is atomic and asks for complete data protection")
    func writeOptions() {
        #expect(FileCVRepository.writeOptions.contains(.atomic) && FileCVRepository.writeOptions.contains(.completeFileProtection))
    }

    #if os(iOS)
    @Test("a stored CV has complete data protection: it cannot be read while the device is locked",
          .enabled(if: !runningInSimulator, "the simulator neither applies nor reports data protection"))
    func dataProtection() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        _ = try await repo(dir).create(named("Ada"))
        let attributes = try FileManager.default.attributesOfItem(atPath: dir.appendingPathComponent(fileName(id1)).path)
        #expect(attributes[.protectionKey] as? FileProtectionType == .complete, "protection: \(String(describing: attributes[.protectionKey]))")
    }
    #endif
}

@Suite("R10 · repository contract, file adapter")
struct FileContractTests {
    @Test("the file adapter passes")
    func file() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        try await CVRepositoryContract.verify(repo(dir))
    }
}
