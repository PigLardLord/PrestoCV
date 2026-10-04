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

private let name = "letter-defaults.json"
private func defaults(salary: String = "", start: String = "", note: String = "") throws -> LetterDefaults {
    try LetterDefaults(salaryExpectation: salary, startDate: start, note: note)
}
private func store(_ dir: URL, maxFileBytes: Int = 64 * 1024) -> FileLetterDefaultsStore {
    FileLetterDefaultsStore(directory: dir, clock: SteppingClock(), maxFileBytes: maxFileBytes)
}
private func write(_ text: String, to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(text.utf8).write(to: url)
}
private func exists(_ url: URL) -> Bool { FileManager.default.fileExists(atPath: url.path) }

/// The bytes `LetterDefaultsFileV1` writes, pinned (ADR 0019, R12).
private let golden = #"{"note":"Remote only","revision":3,"salaryExpectation":"55-60k gross","schemaVersion":1,"startDate":"From April","updatedAt":"2023-11-14T22:13:20Z"}"#
private let savedAt = Date(timeIntervalSince1970: 1_700_000_000)

private let defaultsMutations: [Mutation] = {
    var all: [Mutation] = []
    all.append(Mutation(name: "revision 0", from: #""revision":3"#, to: #""revision":0"#))
    all.append(Mutation(name: "a revision that would overflow", from: #""revision":3"#, to: #""revision":2147483648"#))
    all.append(Mutation(name: "a newer schema, read as this one", from: #""schemaVersion":1"#, to: #""schemaVersion":2"#))
    all.append(Mutation(name: "a text with a margin", from: #""salaryExpectation":"55-60k gross""#, to: #""salaryExpectation":" 55-60k gross""#))
    all.append(Mutation(name: "a text over its bound", from: #""startDate":"From April""#,
                        to: #""startDate":""# + String(repeating: "x", count: LetterDefaults.maxBytes(of: .startDate) + 1) + "\""))
    all.append(Mutation(name: "a control character", from: "From April", to: #"From\u0007 April"#))
    all.append(Mutation(name: "a line break where there must be none", from: "From April", to: #"From\nApril"#))
    all.append(Mutation(name: "a missing text", from: #""note":"Remote only","#, to: ""))
    all.append(Mutation(name: "a text that is not text", from: #""note":"Remote only""#, to: #""note":7"#))
    all.append(Mutation(name: "a missing time", from: #","updatedAt":"2023-11-14T22:13:20Z""#, to: ""))
    return all
}()

@Suite("ADR 0019 · the stored form of the letter defaults")
struct LetterDefaultsFileTests {
    @Test("defaults are written as exactly these bytes, flat under the frozen envelope, and read back as the same defaults")
    func pinned() throws {
        let stored = StoredLetterDefaults(defaults: try defaults(salary: "55-60k gross", start: "From April", note: "Remote only"), revision: 3, updatedAt: savedAt)
        #expect(String(decoding: try LetterDefaultsFileV1(stored, updatedAt: savedAt).encoded(), as: UTF8.self) == golden)
        #expect(try LetterDefaultsFileV1.read(Data(golden.utf8)) == stored)
    }

    @Test("every value that is not in its canonical, valid form is corrupt, never normalised or defaulted", arguments: defaultsMutations)
    func corrupt(mutation: Mutation) throws {
        let json = try mutation.apply(to: golden)
        #expect(throws: LetterDefaultsFileV1.Invalid.self) { try LetterDefaultsFileV1.read(Data(json.utf8)) }
    }

    @Test("{} is not a letter defaults file")
    func empty() { #expect(throws: LetterDefaultsFileV1.Invalid.self) { try LetterDefaultsFileV1.read(Data("{}".utf8)) } }
}

@Suite("ADR 0019 · letter defaults file store")
struct FileLetterDefaultsStoreTests {
    @Test("defaults that were never saved are empty, in a store that is not there yet and in one that is")
    func missing() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        #expect(try await store(dir).load() == .unsaved)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        #expect(try await store(dir).load() == .unsaved)
    }

    @Test("what was saved is what a new instance loads, and a cleared default stays cleared")
    func roundTrip() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let saved = try await store(dir).save(try defaults(salary: "55k", start: "April", note: "Remote"), expectedRevision: 0)
        #expect(try await store(dir).load() == saved)
        let cleared = try await store(dir).save(try defaults(salary: "55k", start: "April"), expectedRevision: 1)
        let loaded = try await store(dir).load()
        #expect(loaded == cleared && loaded.defaults.note.isEmpty && loaded.revision == 2)
    }

    @Test("a corrupt file is moved to the quarantine and reported with its reason, and every load reports it until a restore or a new save")
    func corruptIsRemembered() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        try write("{", to: dir.appendingPathComponent(name))
        let first = LetterDefaultsError.corrupt(file: name, reason: "no schemaVersion envelope")
        await #expect(throws: first) { _ = try await store(dir).load() }
        #expect(!exists(dir.appendingPathComponent(name)) && exists(dir.appendingPathComponent("Quarantine/\(name)")))
        // Never empty defaults: not on the next load, not on another instance, not after a restart.
        await #expect(throws: first) { _ = try await store(dir).load() }
        let again = store(dir)
        await #expect(throws: first) { _ = try await again.load() }
        await #expect(throws: first) { _ = try await again.load() }
        // New defaults replace it: the first save expects no file, and the quarantined copy stays for the user.
        let saved = try await again.save(try defaults(note: "Fresh"), expectedRevision: 0)
        #expect(try await store(dir).load() == saved && exists(dir.appendingPathComponent("Quarantine/\(name)")))
    }

    @Test("a corrupt file that stays in place for lack of a quarantine is reported by its own name and left alone")
    func quarantineFails() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        try write("{", to: dir.appendingPathComponent(name))
        try Data("x".utf8).write(to: dir.appendingPathComponent("Quarantine"))          // a file where the folder should be
        await #expect(throws: LetterDefaultsError.corrupt(file: name, reason: "no schemaVersion envelope")) { _ = try await store(dir).load() }
        #expect(exists(dir.appendingPathComponent(name)))
        await #expect(throws: LetterDefaultsError.corrupt(file: name, reason: "no schemaVersion envelope")) { _ = try await store(dir).save(.empty, expectedRevision: 0) }
    }

    @Test("a restore brings the quarantined copy back, and the defaults load again")
    func restoreCopy() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let s = store(dir)
        try write("{", to: dir.appendingPathComponent(name))
        await #expect(throws: LetterDefaultsError.self) { _ = try await s.load() }
        // The copy is repaired by hand, and restored: it passes the same read checks as any file.
        try write(golden, to: dir.appendingPathComponent("Quarantine/\(name)"))
        let restored = try await s.restore(quarantined: name)
        #expect(restored.revision == 3 && restored.defaults.salaryExpectation == "55-60k gross")
        #expect(try await s.load() == restored && !exists(dir.appendingPathComponent("Quarantine/\(name)")))
    }

    @Test("restore refuses hostile names, a copy that is still corrupt, a copy over the cap, a link, and a file already there")
    func restoreRefusals() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let s = store(dir)
        try write("{", to: dir.appendingPathComponent("Quarantine/1~\(name)"))
        for hostile in ["../\(name)", "1~../../\(name)", "../../etc/passwd", "\(name)\n", "other.json", "1~2~\(name)"] {
            await #expect(throws: LetterDefaultsError.invalidName(hostile)) { _ = try await s.restore(quarantined: hostile) }
        }
        await #expect(throws: LetterDefaultsError.corrupt(file: "1~\(name)", reason: "no schemaVersion envelope")) { _ = try await s.restore(quarantined: "1~\(name)") }
        try write(golden, to: dir.appendingPathComponent("Quarantine/1~\(name)"))
        await #expect(throws: LetterDefaultsError.tooLarge(file: "1~\(name)")) { _ = try await store(dir, maxFileBytes: 64).restore(quarantined: "1~\(name)") }
        #expect(exists(dir.appendingPathComponent("Quarantine/1~\(name)")) && !exists(dir.appendingPathComponent(name)))
        let link = "2~\(name)"
        try FileManager.default.createSymbolicLink(atPath: dir.appendingPathComponent("Quarantine/\(link)").path, withDestinationPath: dir.appendingPathComponent("Quarantine/1~\(name)").path)
        await #expect(throws: LetterDefaultsError.unreadable(file: link)) { _ = try await s.restore(quarantined: link) }
        _ = try await s.restore(quarantined: "1~\(name)")
        try write(golden, to: dir.appendingPathComponent("Quarantine/\(name)"))
        await #expect(throws: LetterDefaultsError.alreadyExists) { _ = try await s.restore(quarantined: name) }
    }

    @Test("a newer schema is left untouched and reported, on load and on save: never read as empty, never overwritten")
    func newerSchema() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let newer = golden.replacingOccurrences(of: #""schemaVersion":1"#, with: #""schemaVersion":2"#)
        try write(newer, to: dir.appendingPathComponent(name))
        await #expect(throws: LetterDefaultsError.upgradeRequired(file: name, version: 2)) { _ = try await store(dir).load() }
        await #expect(throws: LetterDefaultsError.upgradeRequired(file: name, version: 2)) { _ = try await store(dir).save(.empty, expectedRevision: 0) }
        #expect(try String(contentsOf: dir.appendingPathComponent(name), encoding: .utf8) == newer)
        #expect(!exists(dir.appendingPathComponent("Quarantine")))
    }

    @Test("an oversized file is reported without being read, and left where it is")
    func oversized() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data(count: 2048).write(to: dir.appendingPathComponent(name))
        await #expect(throws: LetterDefaultsError.tooLarge(file: name)) { _ = try await store(dir, maxFileBytes: 1024).load() }
        await #expect(throws: LetterDefaultsError.tooLarge(file: name)) { _ = try await store(dir, maxFileBytes: 1024).save(.empty, expectedRevision: 0) }
        #expect(exists(dir.appendingPathComponent(name)) && !exists(dir.appendingPathComponent("Quarantine")))
    }

    @Test("an unreadable file is reported and left in place, never quarantined, never read as empty", .enabled(if: !isRoot))
    func unreadable() async throws {
        let dir = tempDir(); defer { chmod(dir.appendingPathComponent(name).path, 0o644); try? FileManager.default.removeItem(at: dir) }
        let s = store(dir)
        _ = try await s.save(try defaults(note: "x"), expectedRevision: 0)
        chmod(dir.appendingPathComponent(name).path, 0)
        await #expect(throws: LetterDefaultsError.unreadable(file: name)) { _ = try await s.load() }
        #expect(exists(dir.appendingPathComponent(name)) && !exists(dir.appendingPathComponent("Quarantine")))
        chmod(dir.appendingPathComponent(name).path, 0o644)
        #expect(try await s.load().defaults.note == "x")
    }

    @Test("a named pipe in place of the file is unreadable, and never blocks the store", .timeLimit(.minutes(1)))
    func namedPipe() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        #expect(mkfifo(dir.appendingPathComponent(name).path, 0o600) == 0)
        await #expect(throws: LetterDefaultsError.unreadable(file: name)) { _ = try await store(dir).load() }
    }

    @Test("a save that would not read back is refused and the previous version stays")
    func wouldNotReadBack() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let s = store(dir, maxFileBytes: 400)
        let v1 = try await s.save(try defaults(salary: "55k"), expectedRevision: 0)
        let big = try defaults(note: String(repeating: "𝒜", count: 450))                                     // 1,800 bytes: valid, over this cap
        await #expect(throws: LetterDefaultsError.wouldNotReadBack(file: name)) { _ = try await s.save(big, expectedRevision: 1) }
        #expect(try await s.load() == v1)
        await #expect(throws: AuthoringError.tooLarge) { _ = try await SaveLetterDefaults(store: s)(big, over: v1) }
        #expect(try await store(dir).save(big, expectedRevision: 1).revision == 2)
    }

    @Test("a clock with fractional seconds still round-trips: the time is stored to the second")
    func fractionalClock() async throws {
        struct Fractional: TimeSource { func now() -> Date { Date(timeIntervalSince1970: 1_700_000_000.7654) } }
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let s = FileLetterDefaultsStore(directory: dir, clock: Fractional())
        let v1 = try await s.save(try defaults(note: "x"), expectedRevision: 0)
        #expect(try await s.load() == v1 && v1.updatedAt == Date(timeIntervalSince1970: 1_700_000_000))
    }

    @Test("erase removes every copy, whatever its schema or state, and the defaults read as never saved")
    func erase() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let s = store(dir)
        try write("{", to: dir.appendingPathComponent("Quarantine/\(name)"))
        try write("{", to: dir.appendingPathComponent("Quarantine/1~\(name)"))
        try write(golden.replacingOccurrences(of: #""schemaVersion":1"#, with: #""schemaVersion":3"#), to: dir.appendingPathComponent(name))
        try await s.erase()
        #expect(!exists(dir.appendingPathComponent(name)))
        #expect(try FileManager.default.contentsOfDirectory(atPath: dir.appendingPathComponent("Quarantine").path).isEmpty)
        #expect(try await s.load() == .unsaved)
    }

    @Test("erase fails when a copy cannot be inspected, rather than report every copy gone", .enabled(if: !isRoot))
    func eraseInaccessibleCopy() async throws {
        let dir = tempDir()
        let q = dir.appendingPathComponent("Quarantine")
        defer { chmod(q.path, 0o755); try? FileManager.default.removeItem(at: dir) }
        try write("{", to: q.appendingPathComponent(name))
        chmod(q.path, 0o600)                                     // names can be listed, entries cannot be inspected
        await #expect(throws: LetterDefaultsError.self) { try await store(dir).erase() }
        chmod(q.path, 0o755)
        #expect(exists(q.appendingPathComponent(name)))
    }

    @Test("the quarantine purge removes only old entries, and the copy that stands is remembered until it is purged")
    func purge() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let s = store(dir)
        try write("{", to: dir.appendingPathComponent(name))
        await #expect(throws: LetterDefaultsError.self) { _ = try await s.load() }
        try write("{", to: dir.appendingPathComponent("Quarantine/old"))
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 0)], ofItemAtPath: dir.appendingPathComponent("Quarantine/old").path)
        #expect(try await s.purgeQuarantine(olderThan: Date(timeIntervalSince1970: 1_000)) == 1)
        await #expect(throws: LetterDefaultsError.self) { _ = try await s.load() }
        #expect(try await s.purgeQuarantine(olderThan: .distantFuture) == 1)
        #expect(try await s.load() == .unsaved)
    }

    @Test("the retention period starts when the file enters the quarantine, not when it was last changed")
    func retentionStartsAtQuarantine() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        try write("{", to: dir.appendingPathComponent(name))
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 0)], ofItemAtPath: dir.appendingPathComponent(name).path)
        await #expect(throws: LetterDefaultsError.self) { _ = try await store(dir).load() }
        #expect(try await store(dir).purgeQuarantine(olderThan: Date(timeIntervalSince1970: 1_000)) == 0)
        #expect(exists(dir.appendingPathComponent("Quarantine/\(name)")))
    }

    @Test("a store that is not a directory, behind a dangling link, or gone after a save is an error, never empty defaults")
    func unavailableStore() async throws {
        let parent = tempDir(); defer { try? FileManager.default.removeItem(at: parent) }
        let flat = parent.appendingPathComponent("flat")
        try write("x", to: flat)
        await #expect(throws: LetterDefaultsError.storeUnavailable(.notADirectory)) { _ = try await store(flat).load() }
        let target = parent.appendingPathComponent("target", isDirectory: true), link = parent.appendingPathComponent("store")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        _ = try await store(link).save(try defaults(note: "x"), expectedRevision: 0)
        try FileManager.default.removeItem(at: target)
        await #expect(throws: LetterDefaultsError.storeUnavailable(.cannotList)) { _ = try await store(link).load() }
        await #expect(throws: AuthoringError.unavailable) { _ = try await LoadLetterDefaults(store: store(link))() }
    }

    @Test("a lock file that is a link is not followed: nothing is created through it, and the store is unavailable")
    func linkedLock() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let target = dir.appendingPathComponent("elsewhere")
        try FileManager.default.createSymbolicLink(at: dir.appendingPathComponent(".lock"), withDestinationURL: target)
        await #expect(throws: LetterDefaultsError.storeUnavailable(.cannotLock)) { _ = try await store(dir).save(.empty, expectedRevision: 0) }
        #expect(!exists(target))
    }

    @Test("a quarantine that is a link is never used: erase, restore and purge refuse, and a missing file is not read as empty")
    func linkedQuarantine() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let elsewhere = dir.appendingPathComponent("elsewhere", isDirectory: true)
        try FileManager.default.createDirectory(at: elsewhere, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: dir.appendingPathComponent("Quarantine"), withDestinationURL: elsewhere)
        try write("{", to: elsewhere.appendingPathComponent(name))
        let s = store(dir)
        await #expect(throws: LetterDefaultsError.storeUnavailable(.notADirectory)) { try await s.erase() }
        await #expect(throws: LetterDefaultsError.storeUnavailable(.notADirectory)) { _ = try await s.restore(quarantined: name) }
        await #expect(throws: LetterDefaultsError.storeUnavailable(.notADirectory)) { _ = try await s.purgeQuarantine(olderThan: .distantFuture) }
        await #expect(throws: LetterDefaultsError.storeUnavailable(.notADirectory)) { _ = try await s.load() }
        #expect(exists(elsewhere.appendingPathComponent(name)))
    }

    @Test("two instances on one store cannot both win a race, and a stale save is a conflict")
    func twoInstances() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let a = store(dir), b = store(dir)
        let v1 = try await a.save(try defaults(note: "x"), expectedRevision: 0)
        let wins = await withTaskGroup(of: Bool.self) { group in
            for n in 0..<40 {
                let target = n.isMultiple(of: 2) ? a : b
                group.addTask { (try? await target.save(LetterDefaults(note: "W\(n)"), expectedRevision: v1.revision)) != nil }
            }
            return await group.reduce(0) { $0 + ($1 ? 1 : 0) }
        }
        #expect(wins == 1)
        await #expect(throws: LetterDefaultsError.conflict(storedRevision: 2)) { _ = try await b.save(.empty, expectedRevision: 1) }
    }

    @Test("two instances racing for the first save leave one: the other finds a file where it expected none")
    func twoInstancesFirstSave() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let a = store(dir), b = store(dir)
        let wins = await withTaskGroup(of: Bool.self) { group in
            for n in 0..<40 {
                let target = n.isMultiple(of: 2) ? a : b
                group.addTask { (try? await target.save(LetterDefaults(note: "W\(n)"), expectedRevision: 0)) != nil }
            }
            return await group.reduce(0) { $0 + ($1 ? 1 : 0) }
        }
        #expect(wins == 1)
        #expect(try await a.load().revision == 1)
    }

    #if os(iOS)
    @Test("stored defaults have complete data protection: they cannot be read while the device is locked",
          .enabled(if: !runningInSimulator, "the simulator neither applies nor reports data protection"))
    func dataProtection() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        _ = try await store(dir).save(.empty, expectedRevision: 0)
        let attributes = try FileManager.default.attributesOfItem(atPath: dir.appendingPathComponent(name).path)
        #expect(attributes[.protectionKey] as? FileProtectionType == .complete, "protection: \(String(describing: attributes[.protectionKey]))")
    }
    #endif
}

@Suite("R10 · letter defaults store contract, file adapter")
struct FileLetterDefaultsContractTests {
    @Test("the file adapter passes")
    func file() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        try await LetterDefaultsStoreContract.verify(store(dir))
    }
}
