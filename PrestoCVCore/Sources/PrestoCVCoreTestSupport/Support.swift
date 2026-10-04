import Foundation
import Synchronization
import PrestoCVDomain
import PrestoCVApplication

public actor InMemoryCVRepository: CVRepository {
    var store: [CVID: CV] = [:]
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
        CVListing(cvs: store.values.sorted { ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast) }, issues: [])
    }
    public func delete(_ id: CVID, revision: Int) async throws(RepositoryError) {
        guard let existing = store[id] else { throw .notFound(id) }
        guard existing.revision == revision else { throw .conflict(id, storedRevision: existing.revision) }
        store[id] = nil
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
    public func next() -> CVID { CVID(sequential(prefix: "00000000-0000-0000-0000-")) }
    /// Applications count on their own scale, so that an application never has the identifier of a CV.
    public func nextApplication() -> ApplicationID { ApplicationID(sequential(prefix: "00000000-0000-0000-0001-")) }

    private func sequential(prefix: String) -> UUID {
        let value = String(n.withLock { $0 += 1; return $0 })
        let hex = String(repeating: "0", count: max(0, 12 - value.count)) + value
        guard let uuid = UUID(uuidString: prefix + hex) else { preconditionFailure("more than 10^12 ids in a test") }
        return uuid
    }
}

/// What a contract suite reports when an adapter breaks a rule of its port.
public struct ContractFailure: Error, CustomStringConvertible { public let description: String }

/// Runs `body`, which must fail with exactly `error`.
private func expectFailure<E: Error & Equatable>(_ error: E, _ body: () async throws -> Void, _ what: String) async throws {
    do { try await body() } catch let e as E {
        guard e == error else { throw ContractFailure(description: "\(what): got \(e)") }
        return
    }
    throw ContractFailure(description: "\(what): expected \(error)")
}

func expect(_ error: RepositoryError, _ body: () async throws -> Void, _ what: String) async throws {
    try await expectFailure(error, body, what)
}

func expect(_ error: ApplicationRepositoryError, _ body: () async throws -> Void, _ what: String) async throws {
    try await expectFailure(error, body, what)
}

public enum CVRepositoryContract {
    public typealias Failure = ContractFailure

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

/// A cover letter with every part populated, so completeness tests (mappers, persistence) see every leaf.
public enum FixtureLetter {
    public static func full() -> CoverLetter {
        do {
            let recipient = try LetterRecipient(company: "Acme S.r.l.", contactName: "Maria Rossi", formOfAddress: .ms, title: "Dott.ssa", surname: "Rossi",
                                                role: "Head of Engineering", address: ["Via Roma 1", "00100 Roma"])
            return try CoverLetter(recipient: recipient, reference: "Ref. 2026-17", position: "iOS Engineer", subject: "Application for iOS Engineer",
                                   opening: "I am writing about the iOS Engineer role.", paragraphs: ["I ship careful software.", "I have led a team of five."],
                                   closing: "I would be glad to talk.", attachments: ["Curriculum vitae"])
        } catch { preconditionFailure("the fixture letter is valid: \(error)") }
    }
}

/// Where an application came from, with every part populated, so completeness tests see every leaf.
public enum FixtureProvenance {
    public static let sourceCV = CVID(UUID(uuidString: "99999999-9999-9999-9999-999999999999")!)

    public static func full(jobID: String = "job-0001", sourceCV: CVID = FixtureProvenance.sourceCV) -> ApplicationProvenance {
        do {
            typealias P = ApplicationProvenance
            let snapshot = [try P.SourceExperience(statements: ["Led a team of five", "Shipped the app"]),
                            try P.SourceExperience(statements: ["Wrote the build scripts"])]
            let report = try P.Report(argument: "A careful engineer who ships", cut: ["Old jobs"], moved: ["Skills up"], reworded: ["Led a team"])
            var questions: [P.Question] = []
            questions.append(try P.Question(code: "evidence.missing", values: ["SwiftUI"], scope: .experience(0), answer: "Used it daily"))
            questions.append(try P.Question(code: "letter.field", values: ["salary"], scope: .letterField(.salaryExpectation), answer: "60k"))
            questions.append(try P.Question(code: "evidence.missing", values: ["Kotlin"], scope: .skills, answer: "Two years"))
            questions.append(try P.Question(code: "summary.claim", values: ["leadership"], scope: .summary, answer: "Five reports"))
            let override = try LetterDefaults(salaryExpectation: "60k", startDate: "May", note: "Part time")
            let sources = [P.LineSources(experience: 0, line: 1, statements: [P.StatementPosition(experience: 0, line: 0), P.StatementPosition(experience: 1, line: 0)], answers: [0, 1])]
            return try P(jobID: JobID(jobID), sourceCV: sourceCV, snapshot: snapshot, report: report, questions: questions, letterOverride: override,
                         letterDefaults: override, promptVersion: "tailor-3", providerAlias: "provider-a", modelAlias: "model-small", lineSources: sources)
        } catch { preconditionFailure("the fixture provenance is valid: \(error)") }
    }
}

/// An application with every field populated, never saved, so completeness tests (mappers, persistence) see every leaf.
public enum FixtureApplication {
    public static let id = ApplicationID(UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!)
    public static let cvID = CVID(UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!)

    public static func full(id: ApplicationID = FixtureApplication.id, cvID: CVID = FixtureApplication.cvID, jobID: String = "job-0001") -> Application {
        do {
            return try Application(id: id, cv: FixtureCV.full(id: cvID), letter: FixtureLetter.full(),
                                   advert: Advert(company: "Acme S.r.l.", role: "iOS Engineer", text: "We look for an iOS engineer.\nSwiftUI is a plus."),
                                   provenance: FixtureProvenance.full(jobID: jobID))
        } catch { preconditionFailure("the fixture application is valid: \(error)") }
    }
}
