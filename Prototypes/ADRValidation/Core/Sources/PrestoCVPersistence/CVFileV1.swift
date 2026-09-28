import Foundation
#if canImport(Glibc)   // adapter target: platform code allowed here (R11)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif
import PrestoCVDomain
import PrestoCVApplication

/// On-disk DTO, separate from the domain (ADR 0009). Strict: no defaults, no invented values.
/// The envelope is frozen: `schemaVersion` is a top-level integer in every future version.
struct CVFileV1: Codable {
    static let version = 1
    static let maxText = 10_000, maxItems = 500
    let schemaVersion: Int
    let id: UUID
    let revision: Int
    let createdAt: Date
    let updatedAt: Date
    let title: String
    let fullName: String
    let email: String?
    let experiences: [ExperienceV1]
    let skills: [SkillV1]
    struct ExperienceV1: Codable { let role, company, description: String; let start: DateV1?; let end: DateV1?; let current: Bool }
    struct SkillV1: Codable { let name: String; let level: Int? }
    struct DateV1: Codable { let year: Int; let month: Int? }

    struct Invalid: Error { let reason: String }

    init(_ cv: CV, createdAt: Date, updatedAt: Date) {
        schemaVersion = Self.version; id = cv.id.raw; revision = cv.revision; self.createdAt = createdAt; self.updatedAt = updatedAt
        title = cv.title; fullName = cv.fullName; email = cv.email?.value
        experiences = cv.experiences.map { e in
            let start = e.period.map { DateV1(year: $0.start.year, month: $0.start.month) }
            switch e.period?.end {
            case .date(let d): return ExperienceV1(role: e.role, company: e.company, description: e.description, start: start, end: DateV1(year: d.year, month: d.month), current: false)
            case .current: return ExperienceV1(role: e.role, company: e.company, description: e.description, start: start, end: nil, current: true)
            case .unknown, nil: return ExperienceV1(role: e.role, company: e.company, description: e.description, start: start, end: nil, current: false)
            }
        }
        skills = cv.skills.map { SkillV1(name: $0.name, level: $0.level?.value) }
    }

    func toDomain() throws(Invalid) -> CV {
        guard schemaVersion == Self.version else { throw Invalid(reason: "version") }
        guard (1...Int(Int32.max)).contains(revision) else { throw Invalid(reason: "revision") }    // no overflow on +1
        let texts = [title, fullName, email ?? ""] + experiences.flatMap { [$0.role, $0.company, $0.description] } + skills.map(\.name)
        guard texts.allSatisfy({ $0.count <= Self.maxText }), experiences.count <= Self.maxItems, skills.count <= Self.maxItems else {
            throw Invalid(reason: "size limits")
        }
        var exps: [Experience] = []
        for e in experiences {
            do throws(PeriodError) {
                let period = try Period.make(start: e.start.map { ($0.year, $0.month) }, end: e.end.map { ($0.year, $0.month) }, current: e.current)
                exps.append(Experience(role: e.role, company: e.company, period: period, description: e.description))
            } catch { throw Invalid(reason: "period: \(error)") }
        }
        var sk: [Skill] = []
        for s in skills {
            guard let l = s.level else { sk.append(Skill(name: s.name)); continue }
            guard let level = SkillLevel(l) else { throw Invalid(reason: "skill level \(l)") }
            sk.append(Skill(name: s.name, level: level))
        }
        var mail: EmailAddress?
        if let raw = email { guard let e = EmailAddress(raw), e.value == raw else { throw Invalid(reason: "email") }; mail = e }
        return CV(id: CVID(id), revision: revision, createdAt: createdAt, updatedAt: updatedAt, title: title, fullName: fullName,
                  email: mail, experiences: exps, skills: sk)
    }
}

/// File adapter. One file per CV named from its id. Every mutating operation holds an exclusive
/// `flock` on the store, so revision checks hold across repository instances and processes.
public actor FileCVRepository: CVRepository, CVStoreMaintenance {
    let directory: URL
    let clock: any TimeSource
    let maxFileBytes: Int
    var quarantine: URL { directory.appendingPathComponent("Quarantine", isDirectory: true) }

    public init(directory: URL, clock: any TimeSource, maxFileBytes: Int = 5 * 1024 * 1024) {
        self.directory = directory; self.clock = clock; self.maxFileBytes = maxFileBytes
    }

    static let suffix = ".cv.json"
    static let uuidPattern = "[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}"
    private static let writeOptions: Data.WritingOptions = [.atomic, .completeFileProtection]
    private func url(_ id: CVID) -> URL { directory.appendingPathComponent(id.raw.uuidString + Self.suffix) }

    private static let encoder: JSONEncoder = { let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e }()
    private static let decoder: JSONDecoder = { let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d }()

    // MARK: Locking

    private func withStoreLock<T>(_ body: () throws(RepositoryError) -> T) throws(RepositoryError) -> T {
        do { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
        catch { throw .storeUnavailable(.cannotLock) }
        let fd = open(directory.appendingPathComponent(".lock").path, O_CREAT | O_RDWR, 0o600)
        guard fd >= 0 else { throw .storeUnavailable(.cannotLock) }
        defer { close(fd) }
        guard flock(fd, LOCK_EX) == 0 else { throw .storeUnavailable(.cannotLock) }
        defer { flock(fd, LOCK_UN) }
        return try body()
    }

    // MARK: Reading one file

    private enum Read { case cv(CV), newer(Int), corrupt(String), unreadable, tooLarge(Int) }

    /// Distinguishes what must not be touched (I/O failure, symlink, too large, newer schema) from what is
    /// genuinely corrupt. Only the latter is ever quarantined.
    private func read(_ u: URL, asName name: String? = nil) -> Read {
        let attributes: [FileAttributeKey: Any]
        do { attributes = try FileManager.default.attributesOfItem(atPath: u.path) } catch { return .unreadable }
        if attributes[.type] as? FileAttributeType == .typeSymbolicLink { return .unreadable }
        let size = (attributes[.size] as? NSNumber)?.intValue ?? 0
        guard size <= maxFileBytes else { return .tooLarge(size) }
        let data: Data
        do { data = try Data(contentsOf: u) } catch { return .unreadable }
        // The frozen envelope: a newer integer schemaVersion is valid data from a newer build.
        struct Peek: Decodable { let schemaVersion: Int }
        do {
            let peek = try JSONDecoder().decode(Peek.self, from: data)
            if peek.schemaVersion > CVFileV1.version { return .newer(peek.schemaVersion) }
        } catch { return .corrupt("no schemaVersion envelope") }
        do {
            let cv = try Self.decoder.decode(CVFileV1.self, from: data).toDomain()
            guard (name ?? u.lastPathComponent) == cv.id.raw.uuidString + Self.suffix else { return .corrupt("id does not match file name") }
            return .cv(cv)
        } catch let invalid as CVFileV1.Invalid { return .corrupt(invalid.reason) }
        catch { return .corrupt("not a CV file") }
    }

    private func current(_ id: CVID) throws(RepositoryError) -> CV? {
        let u = url(id)
        guard FileManager.default.fileExists(atPath: u.path) else { return nil }
        switch read(u) {
        case .cv(let cv): return cv
        case .newer(let v): throw .upgradeRequired(file: u.lastPathComponent, version: v)
        case .corrupt: throw .corrupt(file: u.lastPathComponent)
        case .unreadable: throw .unreadable(file: u.lastPathComponent)
        case .tooLarge: throw .tooLarge(file: u.lastPathComponent)
        }
    }

    /// Writes only what this repository will be able to read back: the encoded file must be within the size
    /// cap and must decode, through the same strict path as a read, to the same CV. Otherwise nothing is
    /// written and the previous version stays (review round 2: the writer accepted what the reader rejects).
    private func write(_ cv: CV) throws(RepositoryError) {
        let name = url(cv.id).lastPathComponent
        guard let created = cv.createdAt, let updated = cv.updatedAt else { throw .writeFailed(file: name) }
        let data: Data
        do { data = try Self.encoder.encode(CVFileV1(cv, createdAt: created, updatedAt: updated)) } catch { throw .writeFailed(file: name) }
        guard data.count <= maxFileBytes else { throw .wouldNotReadBack(file: name) }
        do {
            guard try Self.decoder.decode(CVFileV1.self, from: data).toDomain() == cv else { throw RepositoryError.wouldNotReadBack(file: name) }
        } catch { throw .wouldNotReadBack(file: name) }
        do { try data.write(to: url(cv.id), options: Self.writeOptions) } catch { throw .writeFailed(file: name) }
    }

    /// Timestamps are stored with whole-second precision (ISO 8601), so they are normalised before use;
    /// otherwise a fractional clock would make every write fail its read-back check.
    private func now() -> Date { Date(timeIntervalSince1970: clock.now().timeIntervalSince1970.rounded(.down)) }

    // MARK: CVRepository

    public func create(_ cv: CV) async throws(RepositoryError) -> CV {
        try withStoreLock { () throws(RepositoryError) -> CV in
            guard try current(cv.id) == nil else { throw .alreadyExists(cv.id) }
            let stored = cv.stored(revision: 1, at: now()); try write(stored); return stored
        }
    }

    public func update(_ cv: CV) async throws(RepositoryError) -> CV {
        try withStoreLock { () throws(RepositoryError) -> CV in
            guard let existing = try current(cv.id) else { throw .notFound(cv.id) }
            guard existing.revision == cv.revision else { throw .conflict(cv.id, storedRevision: existing.revision) }
            let stored = cv.stored(revision: cv.revision + 1, at: now())
            try write(CV(id: stored.id, revision: stored.revision, createdAt: existing.createdAt, updatedAt: stored.updatedAt,
                         title: stored.title, fullName: stored.fullName, email: stored.email, experiences: stored.experiences, skills: stored.skills))
            return try current(cv.id) ?? stored
        }
    }

    public func load(_ id: CVID) async throws(RepositoryError) -> CV {
        guard let cv = try current(id) else { throw .notFound(id) }
        return cv
    }

    public func delete(_ id: CVID, revision: Int) async throws(RepositoryError) {
        try withStoreLock { () throws(RepositoryError) in
            guard let existing = try current(id) else { throw .notFound(id) }
            guard existing.revision == revision else { throw .conflict(id, storedRevision: existing.revision) }
            do { try FileManager.default.removeItem(at: url(id)) } catch { throw .writeFailed(file: url(id).lastPathComponent) }
        }
    }

    public func list() async throws(RepositoryError) -> CVListing {
        var isDir: ObjCBool = false
        // Only a store that does not exist yet means "empty" (first run). Anything else is an error.
        guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDir) else { return CVListing(cvs: [], issues: []) }
        guard isDir.boolValue else { throw .storeUnavailable(.notADirectory) }
        return try withStoreLock { () throws(RepositoryError) -> CVListing in
            let files: [URL]
            do { files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) }
            catch { throw .storeUnavailable(.cannotList) }
            var cvs: [CV] = [], issues: [StoreIssue] = []
            for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) where file.lastPathComponent.hasSuffix(Self.suffix) {
                let name = file.lastPathComponent
                switch read(file) {
                case .cv(let cv): cvs.append(cv)
                case .newer(let v): issues.append(.upgradeRequired(file: name, version: v))
                case .unreadable: issues.append(.unreadable(file: name))
                case .tooLarge(let n): issues.append(.tooLarge(file: name, bytes: n))
                case .corrupt(let reason):
                    issues.append(moveToQuarantine(file) ? .corrupt(file: name, reason: reason) : .quarantineFailed(file: name))
                }
            }
            return CVListing(cvs: cvs.sorted { ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast) }, issues: issues)
        }
    }

    private func moveToQuarantine(_ file: URL) -> Bool {
        do {
            try FileManager.default.createDirectory(at: quarantine, withIntermediateDirectories: true)
            var target = quarantine.appendingPathComponent(file.lastPathComponent)
            var n = 1
            while FileManager.default.fileExists(atPath: target.path) {
                target = quarantine.appendingPathComponent("\(n)~" + file.lastPathComponent); n += 1   // "~" never occurs in a UUID
            }
            try FileManager.default.moveItem(at: file, to: target)
            return true
        } catch { return false }
    }

    // MARK: CVStoreMaintenance

    public func restore(quarantined name: String) async throws(RepositoryError) -> CV {
        // The name is validated in full, so it cannot leave the quarantine folder.
        guard name.range(of: "^(\\d+~)?" + Self.uuidPattern + "\\.cv\\.json\\z", options: .regularExpression) != nil else {
            throw .invalidName(name)
        }
        return try withStoreLock { () throws(RepositoryError) -> CV in
            let source = quarantine.appendingPathComponent(name)
            let original = name.replacingOccurrences(of: #"^\d+~"#, with: "", options: .regularExpression)
            let target = directory.appendingPathComponent(original)
            guard source.deletingLastPathComponent().standardizedFileURL == quarantine.standardizedFileURL else { throw .invalidName(name) }
            guard let uuid = UUID(uuidString: String(original.prefix(36))) else { throw .invalidName(name) }
            guard !FileManager.default.fileExists(atPath: target.path) else { throw .alreadyExists(CVID(uuid)) }
            let cv: CV
            switch read(source, asName: original) {
            case .cv(let c): cv = c
            case .tooLarge: throw .tooLarge(file: name)
            case .unreadable: throw .unreadable(file: name)
            case .newer(let v): throw .upgradeRequired(file: name, version: v)
            case .corrupt: throw .corrupt(file: name)
            }
            do { try FileManager.default.moveItem(at: source, to: target) } catch { throw .writeFailed(file: original) }
            return cv
        }
    }

    /// Quarantine entries; an absent quarantine is empty, an unreadable one is an error.
    private func quarantineNames() throws(RepositoryError) -> [String] {
        guard FileManager.default.fileExists(atPath: quarantine.path) else { return [] }
        do { return try FileManager.default.contentsOfDirectory(atPath: quarantine.path) } catch { throw .storeUnavailable(.cannotList) }
    }

    public func erase(_ id: CVID) async throws(RepositoryError) {
        try withStoreLock { () throws(RepositoryError) in
            let name = id.raw.uuidString + Self.suffix
            var victims = [directory.appendingPathComponent(name)]
            let quarantined = try quarantineNames()
            victims += quarantined.filter { $0 == name || $0.hasSuffix("~" + name) }.map { quarantine.appendingPathComponent($0) }
            for v in victims where FileManager.default.fileExists(atPath: v.path) {
                do { try FileManager.default.removeItem(at: v) } catch { throw .writeFailed(file: v.lastPathComponent) }
            }
        }
    }

    public func purgeQuarantine(olderThan date: Date) async throws(RepositoryError) -> Int {
        try withStoreLock { () throws(RepositoryError) -> Int in
            var removed = 0
            for n in try quarantineNames() {
                let u = quarantine.appendingPathComponent(n)
                let modified: Date?
                do { modified = try FileManager.default.attributesOfItem(atPath: u.path)[.modificationDate] as? Date } catch { throw .unreadable(file: n) }
                guard let modified, modified < date else { continue }
                do { try FileManager.default.removeItem(at: u); removed += 1 } catch { throw .writeFailed(file: n) }
            }
            return removed
        }
    }
}
