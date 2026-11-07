import Testing
import Foundation
import PrestoCVDomain
import PrestoCVApplication
@testable import PrestoCVPersistence
import PrestoCVCoreTestSupport

private let idA = CVID(UUID(uuidString: LegacyFixtures.idA)!)
private let idB = CVID(UUID(uuidString: LegacyFixtures.idB)!)

private struct World {
    let legacy: URL, store: URL
    let repository: FileCVRepository
    var source: DirectoryLegacyStore { DirectoryLegacyStore(directory: legacy, clock: SteppingClock()) }
    func importer(removing: Bool = true) -> ImportLegacyStore {
        ImportLegacyStore(source: source, target: repository, removingVerifiedSources: removing)
    }
    func legacyFile(_ id: String) -> URL { legacy.appendingPathComponent(LegacyFixtures.fileName(id)) }
}

private func world(_ files: [String: String]) throws -> World {
    let legacy = try legacyDir(files), store = tempDir()
    return World(legacy: legacy, store: store, repository: repo(store))
}

private func standard() throws -> World {
    try world([LegacyFixtures.fileName(LegacyFixtures.idA): LegacyFixtures.v10(),
               LegacyFixtures.fileName(LegacyFixtures.idB): LegacyFixtures.v101()])
}

@Suite("Importing the legacy store once")
struct LegacyImportTests {
    @Test("both released shapes are imported with their times, and the list keeps its order")
    func importsBoth() async throws {
        let w = try standard()
        let report = try await w.importer().run()
        #expect(Set(report.imported) == [idA, idB] && report.failures.isEmpty)
        let listing = try await w.repository.list()
        #expect(listing.issues.isEmpty)
        #expect(listing.cvs.map(\.id) == [idB, idA])   // 1.0.1 was changed later
        let a = try await w.repository.load(idA)
        #expect(a.revision == 1 && a.title == "Lab roles")
        #expect(a.updatedAt == ISO8601DateFormatter().date(from: "2026-09-20T10:00:00Z"))
        let b = try await w.repository.load(idB)
        #expect(b.design == DesignChoice(design: "modern", palette: "ocean", fonts: "classic"))
    }

    @Test("what was dropped is reported for the CV it was dropped from")
    func reportsDrops() async throws {
        let w = try world([LegacyFixtures.fileName(LegacyFixtures.idA): LegacyFixtures.minimal(#""look":{"palette":"ocean"}"#)])
        let report = try await w.importer().run()
        #expect(report.drops[idA] == [.look])
    }

    @Test("a source is removed only once its copy is stored, and the copy reads back")
    func removesVerifiedSources() async throws {
        let w = try standard()
        let report = try await w.importer().run()
        #expect(Set(report.removedSources) == [LegacyFixtures.fileName(LegacyFixtures.idA), LegacyFixtures.fileName(LegacyFixtures.idB)])
        #expect(!FileManager.default.fileExists(atPath: w.legacyFile(LegacyFixtures.idA).path))
        let cvs = try await w.repository.list().cvs
        #expect(cvs.count == 2)
    }

    @Test("with removal off, the sources stay")
    func keepsSourcesWhenAsked() async throws {
        let w = try standard()
        let report = try await w.importer(removing: false).run()
        #expect(report.removedSources.isEmpty && report.imported.count == 2)
        #expect(FileManager.default.fileExists(atPath: w.legacyFile(LegacyFixtures.idA).path))
    }

    @Test("a second run imports nothing and never overwrites a CV the person has changed since")
    func idempotent() async throws {
        let w = try standard()
        _ = try await w.importer(removing: false).run()
        var edited = try await w.repository.load(idA)
        edited.rename("Edited since")
        _ = try await w.repository.update(edited)
        let again = try await w.importer(removing: false).run()
        #expect(again.imported.isEmpty && Set(again.alreadyStored) == [idA, idB] && again.failures.isEmpty)
        let kept = try await w.repository.load(idA)
        #expect(kept.title == "Edited since" && kept.revision == 2)
    }

    @Test("a run after a complete run finds nothing to do")
    func rerunAfterRemoval() async throws {
        let w = try standard()
        _ = try await w.importer().run()
        let again = try await w.importer().run()
        #expect(again == LegacyImportReport())
    }

    @Test("one bad file does not stop the others, and it stays where it was, byte for byte")
    func partialFailure() async throws {
        let bad = "{ this is not json"
        let w = try world([LegacyFixtures.fileName(LegacyFixtures.idA): LegacyFixtures.v10(), LegacyFixtures.fileName(LegacyFixtures.idB): bad])
        let report = try await w.importer().run()
        #expect(report.imported == [idA])
        #expect(report.failures == [LegacyImportFailure(fileName: LegacyFixtures.fileName(LegacyFixtures.idB), reason: .invalid("json"))])
        let kept = try String(contentsOf: w.legacyFile(LegacyFixtures.idB), encoding: .utf8)
        #expect(kept == bad)
        #expect(!FileManager.default.fileExists(atPath: w.legacyFile(LegacyFixtures.idA).path))
    }

    @Test("a file whose id is outside the pattern, or does not match its name, is reported and left alone")
    func idOutsidePattern() async throws {
        let files = ["cv_not-a-uuid.json": #"{"id":"not-a-uuid"}"#,
                     LegacyFixtures.fileName(LegacyFixtures.idA): LegacyFixtures.v10(id: LegacyFixtures.idB),
                     "cv_../../escape.json": "{}"]
        let w = try world(files.filter { !$0.key.contains("/") })
        let report = try await w.importer().run()
        #expect(report.imported.isEmpty && report.failures.count == 2)
        #expect(report.failures.allSatisfy { if case .invalid = $0.reason { true } else { false } })
        let left = try FileManager.default.contentsOfDirectory(atPath: w.legacy.path)
        #expect(left.count == 2)
        let listing = try await w.repository.list()
        #expect(listing.cvs.isEmpty)
    }

    @Test("a file too large, and a link, are never read; they stay")
    func hostileFiles() async throws {
        let w = try world([LegacyFixtures.fileName(LegacyFixtures.idA): String(repeating: " ", count: 2_000)])
        let target = w.legacy.appendingPathComponent("elsewhere.json")
        try Data(LegacyFixtures.v101().utf8).write(to: target)
        try FileManager.default.createSymbolicLink(at: w.legacyFile(LegacyFixtures.idB), withDestinationURL: target)
        let source = DirectoryLegacyStore(directory: w.legacy, clock: SteppingClock(), maxFileBytes: 1_000)
        let report = try await ImportLegacyStore(source: source, target: w.repository).run()
        #expect(report.imported.isEmpty && report.failures.count == 2)
        #expect(FileManager.default.fileExists(atPath: w.legacyFile(LegacyFixtures.idA).path))
        let listing = try await w.repository.list()
        #expect(listing.cvs.isEmpty)
    }

    @Test("a legacy store that is not there is an empty import")
    func noLegacyStore() async throws {
        let w = try world([:])
        try FileManager.default.removeItem(at: w.legacy)
        let report = try await w.importer().run()
        #expect(report == LegacyImportReport())
    }

    @Test("legacy files in the new store are neither listed nor quarantined: they are not schema 1")
    func legacyIsNotSchemaOne() async throws {
        let dir = try legacyDir([LegacyFixtures.fileName(LegacyFixtures.idA): LegacyFixtures.v10(),
                                 LegacyFixtures.fileName(LegacyFixtures.idB): LegacyFixtures.v101()])
        let listing = try await repo(dir).list()
        #expect(listing.cvs.isEmpty && listing.issues.isEmpty)
        let files = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        #expect(files.filter { $0.hasPrefix("cv_") }.count == 2 && !files.contains { $0.hasSuffix(".cv.json") })
        #expect(!FileManager.default.fileExists(atPath: dir.appendingPathComponent("Quarantine").path))
    }

    @Test("a legacy file that holds a schemaVersion is still not read as schema 1 by the store")
    func legacyWithEnvelopeKey() async throws {
        let dir = try legacyDir([LegacyFixtures.fileName(LegacyFixtures.idA): LegacyFixtures.minimal(#""schemaVersion":1,"revision":1"#)])
        let listing = try await repo(dir).list()
        #expect(listing.cvs.isEmpty && listing.issues.isEmpty)
    }
}

// MARK: - The source is kept until the new copy is verified

private struct FakeSource: LegacyStore {
    let recordsToServe: [LegacyRecord]
    let removed = Recorder()
    func records() async throws(RepositoryError) -> [LegacyRecord] { recordsToServe }
    func remove(_ fileName: String) async throws(RepositoryError) { removed.add(fileName) }
}

private final class Recorder: @unchecked Sendable {
    private let lock = NSLock()
    private var names: [String] = []
    func add(_ name: String) { lock.lock(); names.append(name); lock.unlock() }
    var all: [String] { lock.lock(); defer { lock.unlock() }; return names }
}

private struct FakeTarget: LegacyImportTarget {
    let answer: @Sendable (CV) throws(RepositoryError) -> Adoption
    func adopt(_ cv: CV) async throws(RepositoryError) -> Adoption { try answer(cv) }
}

private func oneRecord() -> LegacyRecord {
    let cv = CV(id: idA, revision: 0, createdAt: Date(timeIntervalSince1970: 100), updatedAt: Date(timeIntervalSince1970: 200), title: "T",
                personal: PersonalDetails(fullName: "N"), sections: CVSections(), design: nil, language: nil)
    return LegacyRecord(fileName: "cv_x.json", content: .cv(LegacyCV(cv: cv, drops: [])))
}

@Suite("The source is kept until the new copy is verified")
struct LegacySourceKeptTests {
    private func run(_ answer: @escaping @Sendable (CV) throws(RepositoryError) -> Adoption) async throws -> (LegacyImportReport, [String]) {
        let source = FakeSource(recordsToServe: [oneRecord()])
        let report = try await ImportLegacyStore(source: source, target: FakeTarget(answer: answer)).run()
        return (report, source.removed.all)
    }

    @Test("a copy that reads back as what was mapped lets the source go")
    func verified() async throws {
        let (report, removed) = try await run { cv throws(RepositoryError) in .stored(cv.adoptedAsRevisionOne) }
        #expect(report.imported == [idA] && removed == ["cv_x.json"])
    }

    @Test("a copy that reads back as something else keeps the source")
    func differentCopy() async throws {
        let (report, removed) = try await run { cv throws(RepositoryError) in
            var other = cv.adoptedAsRevisionOne
            other.rename("changed on the way")
            return .stored(other)
        }
        #expect(report.imported.isEmpty && removed.isEmpty)
        #expect(report.failures.map(\.reason) == [.didNotReadBack])
    }

    @Test("a write that fails keeps the source")
    func failedWrite() async throws {
        let (report, removed) = try await run { _ throws(RepositoryError) in throw .storeUnavailable(.cannotLock) }
        #expect(removed.isEmpty && report.failures.map(\.reason) == [.notStored(.storeUnavailable(.cannotLock))])
    }

    @Test("a CV that is already stored is not touched, and its source goes: the store holds it")
    func existingCopy() async throws {
        let (report, removed) = try await run { _ throws(RepositoryError) in .existing }
        #expect(report.alreadyStored == [idA] && removed == ["cv_x.json"])
    }

    @Test("a source that cannot be removed is reported, and the run goes on")
    func removalFails() async throws {
        struct Stubborn: LegacyStore {
            func records() async throws(RepositoryError) -> [LegacyRecord] { [oneRecord(), oneRecord()] }
            func remove(_ fileName: String) async throws(RepositoryError) { throw .unreadable(file: fileName) }
        }
        let target = FakeTarget { cv throws(RepositoryError) in .stored(cv.adoptedAsRevisionOne) }
        let report = try await ImportLegacyStore(source: Stubborn(), target: target).run()
        #expect(report.failures.count == 2 && report.removedSources.isEmpty)
    }

    @Test("a source that cannot be listed fails the run before anything is touched")
    func listingFails() async {
        struct Broken: LegacyStore {
            func records() async throws(RepositoryError) -> [LegacyRecord] { throw .storeUnavailable(.cannotList) }
            func remove(_ fileName: String) async throws(RepositoryError) {}
        }
        let target = FakeTarget { _ throws(RepositoryError) in .existing }
        await #expect(throws: RepositoryError.storeUnavailable(.cannotList)) { try await ImportLegacyStore(source: Broken(), target: target).run() }
    }
}
