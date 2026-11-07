import Foundation
import Synchronization
import PrestoCVDomain
import PrestoCVApplication

/// The in-memory CV store, with the maintenance port (`InMemoryCVRepository+Maintenance.swift`): the double the contract suite
/// runs on beside the file store.
public actor InMemoryCVRepository: CVRepository, CVStoreMaintenance, LegacyImportTarget {
    var store: [CVID: CV] = [:]
    /// The quarantine: a file that is a CV (`cv`) or does not decode (nil), and when it entered.
    struct Held: Sendable { var id: CVID; var cv: CV?; var enteredAt: Date }
    var held: [String: Held] = [:]
    /// Stored files that do not decode: the next listing sets them aside.
    var corruptLive: Set<CVID> = []
    /// The ids the importer adopted: the ledger, which outlives a deletion so that a source is not imported again.
    var adopted: Set<CVID> = []
    let clock: any TimeSource
    public init(clock: any TimeSource = SteppingClock()) { self.clock = clock }
    public func create(_ cv: CV) async throws(RepositoryError) -> CV {
        guard store[cv.id] == nil else { throw .alreadyExists(cv.id) }
        let s = cv.stored(revision: 1, at: clock.now()); store[cv.id] = s; return s
    }
    public func update(_ cv: CV) async throws(RepositoryError) -> CV {
        guard let existing = store[cv.id] else { throw .notFound(cv.id) }
        guard existing.revision == cv.revision else { throw .conflict(cv.id, storedRevision: existing.revision) }
        let s = cv.stored(revision: cv.revision + 1, at: clock.now()); store[cv.id] = s; return s
    }
    public func load(_ id: CVID) async throws(RepositoryError) -> CV { guard let cv = store[id] else { throw .notFound(id) }; return cv }
    public func list() async throws(RepositoryError) -> CVListing {
        CVListing(cvs: store.values.sorted { ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast) }, issues: quarantineCorruptLive())
    }
    public func delete(_ id: CVID, revision: Int) async throws(RepositoryError) {
        guard let existing = store[id] else { throw .notFound(id) }
        guard existing.revision == revision else { throw .conflict(id, storedRevision: existing.revision) }
        store[id] = nil
    }
}

extension InMemoryCVRepository {
    /// Stores a legacy CV once: a CV the ledger knows is `.existing`, also after it was deleted.
    public func adopt(_ cv: CV) async throws(RepositoryError) -> Adoption {
        if adopted.contains(cv.id) { return .existing }
        adopted.insert(cv.id)
        if store[cv.id] != nil { return .existing }
        let copy = cv.adoptedAsRevisionOne
        store[cv.id] = copy
        return .stored(copy)
    }
}

/// Each call returns a later instant: deterministic ordering without the wall clock.
public final class SteppingClock: TimeSource {
    private let tick = Mutex(0)
    public init() {}
    public func now() -> Date { Date(timeIntervalSince1970: 1_700_000_000 + Double(tick.withLock { $0 += 1; return $0 })) }
}

public final class SequentialIDGenerator: IDGenerator {
    private let n = Mutex(0)
    public init() {}
    public func next() -> CVID {
        let value = String(n.withLock { $0 += 1; return $0 })
        let hex = String(repeating: "0", count: max(0, 12 - value.count)) + value
        guard let uuid = UUID(uuidString: "00000000-0000-0000-0000-" + hex) else { preconditionFailure("more than 10^12 ids in a test") }
        return CVID(uuid)
    }
}

public enum CVRepositoryContract {
    public struct Failure: Error, CustomStringConvertible { public let description: String }

    static func expect(_ error: RepositoryError, _ body: () async throws -> Void, _ what: String) async throws {
        do { try await body() } catch let e as RepositoryError {
            guard e == error else { throw Failure(description: "\(what): got \(e)") }
            return
        }
        throw Failure(description: "\(what): expected \(error)")
    }

    /// Every CVRepository adapter must pass this (R10).
    public static func verify(_ repo: some CVRepository) async throws {
        let id = CVID(UUID(uuidString: "11111111-1111-1111-1111-111111111111")!)
        let v1 = try await repo.create(CV(id: id, personal: PersonalDetails(fullName: "Ada")))
        guard v1.revision == 1, v1.createdAt != nil, v1.createdAt == v1.updatedAt, try await repo.load(id) == v1 else {
            throw Failure(description: "create/load round trip with timestamps")
        }
        try await expect(.alreadyExists(id), { _ = try await repo.create(CV(id: id, personal: PersonalDetails(fullName: "Ada"))) }, "create twice")

        var edit = v1; edit.rename("Updated")
        let v2 = try await repo.update(edit)
        guard v2.revision == 2, v2.createdAt == v1.createdAt, let u1 = v1.updatedAt, let u2 = v2.updatedAt, u2 > u1,
              try await repo.list().cvs == [v2] else { throw Failure(description: "update must bump revision and updatedAt, keep createdAt, not duplicate") }

        var stale = v1; stale.rename("Stale window")
        try await expect(.conflict(id, storedRevision: 2), { _ = try await repo.update(stale) }, "stale update")
        guard try await repo.load(id).title == "Updated" else { throw Failure(description: "stale update overwrote") }

        // Concurrency on one instance: N updates from the same revision leave exactly one success.
        let successes = await withTaskGroup(of: Bool.self) { group in
            for n in 0..<50 {
                group.addTask { var c = v2; c.rename("Racer \(n)"); return (try? await repo.update(c)) != nil }
            }
            return await group.reduce(0) { $0 + ($1 ? 1 : 0) }
        }
        guard successes == 1 else { throw Failure(description: "\(successes) concurrent updates from one revision succeeded") }
        let v3 = try await repo.load(id)

        try await expect(.conflict(id, storedRevision: 3), { try await repo.delete(id, revision: 1) }, "stale delete")
        try await repo.delete(id, revision: v3.revision)
        try await expect(.notFound(id), { _ = try await repo.update(v3) }, "update after delete must not resurrect")
        guard try await repo.list().cvs.isEmpty else { throw Failure(description: "deleted CV came back") }
        try await expect(.notFound(id), { try await repo.delete(id, revision: 3) }, "delete missing")

        // Listing order: most recently changed first.
        let a = try await repo.create(CV(id: CVID(UUID(uuidString: "22222222-2222-2222-2222-222222222222")!), personal: PersonalDetails(fullName: "A")))
        let b = try await repo.create(CV(id: CVID(UUID(uuidString: "33333333-3333-3333-3333-333333333333")!), personal: PersonalDetails(fullName: "B")))
        var a2 = a; a2.rename("touched"); let a3 = try await repo.update(a2)
        guard try await repo.list().cvs.map(\.id) == [a3.id, b.id] else { throw Failure(description: "list must be sorted by last change") }
    }
}

/// Sample CVs from memory, for the use cases that start from a sample.
public struct InMemorySampleCVSource: SampleCVSource {
    let cvs: [CV]
    public init(_ cvs: [CV]) { self.cvs = cvs }
    public func samples() async throws(RepositoryError) -> [CV] { cvs }
}

/// A CV with every field populated, so completeness tests (mappers, persistence) see every leaf.
public enum FixtureCV {
    public static func full(id: CVID = CVID(UUID(uuidString: "11111111-1111-1111-1111-111111111111")!)) -> CV {
        func link(_ s: String) -> WebLink { WebLink(s)! }
        let period = Period(start: PartialDate(year: 2019, month: 3)!, end: .current)!
        let ended = Period(start: PartialDate(year: 2012, month: 9)!, end: .date(PartialDate(year: 2015, month: 7)!))!
        return CV(
            id: id,
            title: "iOS roles",
            personal: PersonalDetails(fullName: "Ada Lovelace", professionalTitle: "iOS Engineer", email: EmailAddress("ada@example.com"),
                                      phone: PhoneNumber("+39 06 1234567"), location: "Roma", website: link("https://ada.example"),
                                      summary: "Builds careful software."),
            sections: CVSections(
                experiences: [Experience(role: "Engineer", company: "Analytical", location: "London", period: period, description: "Engines")],
                education: [Education(degree: "Mathematics", school: "Home", period: ended, description: "Tutored")],
                skills: [Skill(name: "Swift", level: SkillLevel(5)), Skill(name: "Git", level: SkillLevel(3))],
                languages: [LanguageSkill(language: "Italian", proficiency: .native), LanguageSkill(language: "English", proficiency: .c1)],
                certifications: [Certification(name: "Swift Certified", issuer: "Apple", issued: PartialDate(year: 2021, month: 6),
                                               link: link("https://cert.example/1"), description: "Concurrency")],
                profiles: [ProfileLink(platform: "GitHub", link: link("https://github.com/ada"))],
                interests: ["Chess", "Running"]
            ),
            design: DesignChoice(design: "modern", palette: "ocean", fonts: "classic"),
            language: DocumentLanguage("it")
        )
    }
}

/// The leaves of a value, walked with Mirror: strings, integers, booleans and enum cases without a payload. A nil is
/// `missing` and an empty collection is `empty`, so a completeness test can require a fixture to populate every field,
/// and the mapper test (R10) can check that each leaf reaches the document.
public enum FieldLeaves {
    public static let missing = "<nil>", empty = "<empty>"

    public static func of(_ value: Any, skipping: Set<String> = []) -> [String] {
        let mirror = Mirror(reflecting: value)
        switch mirror.displayStyle {
        case .optional?: return mirror.children.first.map { of($0.value, skipping: skipping) } ?? [missing]
        case .collection?, .set?, .dictionary?: if mirror.children.isEmpty { return [empty] }
        case .enum? where mirror.children.isEmpty: return [String(describing: value)]
        default: break
        }
        switch value {
        case let text as String: return [text]
        case let number as Int: return [String(number)]
        case let flag as Bool: return [String(flag)]
        case is Date, is UUID: return []
        default: return mirror.children.filter { !skipping.contains($0.label ?? "") }.flatMap { of($0.value, skipping: skipping) }
        }
    }
}
