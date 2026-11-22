import Foundation
#if canImport(Glibc)   // outbound adapter: platform code is allowed here (R11)
import Glibc
#elseif canImport(Android)
import Android
#elseif canImport(Darwin)
import Darwin
#endif
import CVDesignCatalog

/// Every way the store can fail has its own case (R7): nothing is reported as "no design".
public enum FileDesignStoreError: Error, Equatable, Sendable {
    /// The store directory cannot be created or listed, its lock cannot be taken, or its `Designs` folder is not a
    /// real directory.
    case storeUnavailable
    /// The store's lock was held elsewhere, by another instance or another process, until the wait's deadline.
    case lockTimeout
    /// The index cannot be read (an I/O failure, or not a regular file), is corrupt, or was written by a newer
    /// version. It is left untouched, and nothing is saved over it.
    case indexUnreadable, indexCorrupt(String), indexFromNewerVersion(Int)
    /// A listed design cannot be read, is larger than the validator accepts, or no longer passes validation.
    case designUnreadable(id: String), designTooLarge(id: String, bytes: Int), designRejected(id: String, [DesignPackageViolation])
    /// The design, once encoded, would not validate back to itself, so nothing was written.
    case wouldNotReadBack(id: String)
    case writeFailed(id: String)
}

/// The design store on disk (ADR 0002, ADR 0011). The directory is injected, and the composition root keeps one
/// instance per process (ADR 0008).
///
/// - Every save of a design writes a new generation of its package file under `Designs/`, then `index.json`, which
///   lists each design with its current generation and its origin. Each write is atomic, and nothing is written after
///   the index. A save that fails before or during the index write leaves the listing, the generations and every origin
///   as they were; superseded and unlisted files are removed at the next save.
/// - Each index entry records whether the catalog's sync installed the design (`bundled`) or an import did
///   (`imported`). It is the store's own record: a package is untrusted, so it cannot say what it is. The generation
///   and the origin are committed by the one write of the index, so a design is never listed without the origin its
///   save gave it. An entry with no origin has none recorded: the store reads such an entry, and never writes one. The
///   caller decides what that means.
/// - A save never replaces a design of the other origin, and the store decides that under its lock: an import leaves an
///   installed bundled design alone (`ImportSave.keptBundled`), and a conditional save leaves alone one that is not
///   recorded as bundled (`ConditionalSave.keptImported`).
/// - A save holds an exclusive `flock` on the store and a read a shared one, so a second instance or another
///   process loses no index update. While the lock is held elsewhere the call suspends between attempts and holds no
///   thread, and it gives up with `lockTimeout` at the deadline of `lockWait`.
/// - Files on disk are untrusted input (R8): every read goes through the validator again and must match the index,
///   and a path that is not a regular file (a symbolic link, a named pipe) or a `Designs` folder that is not a real
///   directory is never used. Only validated designs leave the store.
public actor FileDesignStore: DesignStore {
    let directory: URL, validator: DesignPackageValidator, lockWait: LockWait
    /// How a file of the store is written. Tests replace it to see the order of the writes and to fail one of them.
    let writeFile: @Sendable (Data, URL) throws -> Void

    public init(directory: URL, validator: DesignPackageValidator = DesignPackageValidator(), lockWait: LockWait = .standard) {
        self.init(directory: directory, validator: validator, lockWait: lockWait, writeFile: Self.writeAtomically)
    }

    /// How the store waits while its lock is held elsewhere: it tries again after each pause, and gives up with
    /// `lockTimeout` once the pauses add up to the deadline (a pause never asks for more than what is left of it, so the wait never passes it and the sum cannot overflow). The pause suspends the caller; it never holds a thread.
    public struct LockWait: Sendable {
        public let deadline: Duration, interval: Duration
        let pause: @Sendable (Duration) async -> Void

        /// `pause` waits for about the duration it is given. Tests pass one that does not wait. An `interval` of zero or
        /// less counts as the smallest step, one millisecond, so that every pause brings the wait closer to the deadline
        /// and it stays bounded. A `deadline` of zero or less allows one attempt and no pause.
        public init(deadline: Duration, interval: Duration, pause: @escaping @Sendable (Duration) async -> Void) {
            self.deadline = deadline; self.interval = max(interval, Self.smallestInterval); self.pause = pause
        }

        static let smallestInterval = Duration.milliseconds(1)

        /// The pause after the pauses have added up to `waited`: the interval, or only what is left of the deadline, so
        /// the wait never passes the deadline and the sum never overflows; nil once the deadline is reached.
        func step(after waited: Duration) -> Duration? {
            waited < deadline ? min(interval, deadline - waited) : nil
        }

        /// What the app uses: ten seconds, in pauses of 25 milliseconds on the real clock. The pause sleeps in a task of
        /// its own, which does not inherit the caller's cancellation: a cancelled call keeps waiting until the deadline,
        /// and its only failure, a cancellation, cannot happen.
        public static let standard = LockWait(deadline: .seconds(10), interval: .milliseconds(25), pause: standardPause)

        /// The pause of `standard`, apart so that a test can run it with a shorter deadline.
        static let standardPause: @Sendable (Duration) async -> Void = { interval in
            let sleeping = Task { try await Task.sleep(for: interval) }
            _ = await sleeping.result
        }
    }

    init(directory: URL, validator: DesignPackageValidator = DesignPackageValidator(), lockWait: LockWait = .standard,
         writeFile: @escaping @Sendable (Data, URL) throws -> Void) {
        self.directory = directory; self.validator = validator; self.lockWait = lockWait; self.writeFile = writeFile
    }

    private static func writeAtomically(_ data: Data, to url: URL) throws { try data.write(to: url, options: .atomic) }

    /// The index's schema version. An index written with a new palette, font scheme or origin cannot be read by an older
    /// app: bump the index version when these change. Schema 2 is new with the origin in each entry, and no device has a
    /// schema 2 store from before (no released app built a `FileDesignStore`), so the origin record needs no migration:
    /// an entry with no `origin` is read as having none recorded, and the store never writes one.
    static let indexVersion = 2
    static let maxIndexBytes = 1024 * 1024, maxGeneration = Int(Int32.max)
    private var designsDirectory: URL { directory.appendingPathComponent("Designs", isDirectory: true) }
    private var indexFile: URL { directory.appendingPathComponent("index.json") }
    private static func fileName(_ id: String, _ generation: Int) -> String { "\(id).\(generation).mcvt" }
    private func file(_ entry: Entry) -> URL { designsDirectory.appendingPathComponent(Self.fileName(entry.manifest.id, entry.generation)) }

    /// A design file is a design package, in the format the validator reads.
    private struct PackageFile: Codable { let manifest: DesignManifest; let cssContent: String; let previewImageBase64: String? }
    /// Index schema 2: each stored design's manifest, the generation of its file and its origin (nil: none recorded).
    private struct IndexV2: Codable { let schemaVersion: Int; let designs: [Entry] }
    private struct Entry: Codable, Equatable {
        let manifest: DesignManifest, generation: Int
        let origin: OriginName?
        func with(origin: OriginName) -> Entry { Entry(manifest: manifest, generation: generation, origin: origin) }
    }
    /// How an origin is written. The catalog's `DesignOrigin` does not decide what is on disk, and a new origin does not
    /// compile until it has a name here.
    private enum OriginName: String, Codable, Equatable {
        case bundled, imported
        init(_ origin: DesignOrigin) {
            switch origin {
            case .bundled: self = .bundled
            case .imported: self = .imported
            }
        }
        var origin: DesignOrigin {
            switch self {
            case .bundled: .bundled
            case .imported: .imported
            }
        }
    }
    private struct Envelope: Decodable { let schemaVersion: Int }

    // MARK: DesignStore

    @discardableResult public func save(_ design: ValidatedDesign) async throws(FileDesignStoreError) -> ImportSave {
        switch try await saveEntry(design, as: .imported, mode: .anyway) {
        case .keptOtherOrigin: .keptBundled
        case .installed, .upgraded, .keptInstalled: .saved
        }
    }

    public func saveIfNewer(_ design: ValidatedDesign) async throws(FileDesignStoreError) -> ConditionalSave {
        switch try await saveEntry(design, as: .bundled, mode: .onlyIfNewer) {
        case .installed: .installed
        case .upgraded: .upgraded
        case .keptInstalled: .keptInstalled
        case .keptOtherOrigin: .keptImported
        }
    }

    private enum Written { case installed, upgraded, keptInstalled, keptOtherOrigin }
    /// Which installed designs a write replaces. `anyway` and `onlyIfNewer` also install a design that is not there.
    private enum Mode {
        /// An import: replaces any design that is not recorded as bundled.
        case anyway
        /// The sync: replaces a bundled design of an older version.
        case onlyIfNewer
        /// The repair: replaces a bundled design of any version, and installs nothing.
        case replaceBundled
    }

    /// The one write path, which records the design's `origin`. The installed design is judged inside the exclusive lock
    /// that the write holds, and a save never replaces a design of the other origin: an import leaves an installed bundled
    /// design alone, and a bundled save leaves alone one that the store did not record as bundled (`keptOtherOrigin`).
    /// With `onlyIfNewer`, an installed design of the same or a newer version is left alone as well. With `replaceBundled`, only a design recorded as bundled is written, whatever its version.
    private func saveEntry(_ design: ValidatedDesign, as origin: DesignOrigin, mode: Mode) async throws(FileDesignStoreError) -> Written {
        let id = design.manifest.id
        let package = try encodeReadingBack(design)
        let outcome = try await withLock(exclusive: true) { () throws(FileDesignStoreError) -> Written in
            let entries = try readIndex()
            let installed = entries.first { $0.manifest.id == id }
            switch mode {
            case .anyway:
                if installed?.origin == .bundled { return .keptOtherOrigin }
            case .onlyIfNewer:
                if let installed {
                    guard installed.origin == .bundled else { return .keptOtherOrigin }
                    if design.manifest.version <= installed.manifest.version { return .keptInstalled }
                }
            case .replaceBundled:
                guard installed?.origin == .bundled else { return .keptOtherOrigin }
            }
            try removeUnlistedFiles(keeping: entries, for: id)
            let generation = (installed?.generation ?? 0) + 1
            guard generation <= Self.maxGeneration else { throw .wouldNotReadBack(id: id) }
            let entry = Entry(manifest: design.manifest, generation: generation, origin: OriginName(origin))
            let listed = (entries.filter { $0.manifest.id != id } + [entry]).sorted { $0.manifest.id < $1.manifest.id }
            let index = try encodeIndex(listed, for: id)
            try write(package, to: file(entry), for: id)
            try write(index, to: indexFile, for: id)   // the only commit: the listing, the generation and the origin are in this one write
            return installed == nil ? .installed : .upgraded
        }
        guard let outcome else { throw .storeUnavailable }   // an exclusive lock creates the store, so it is never absent
        return outcome
    }

    public func design(id: String) async throws(FileDesignStoreError) -> ValidatedDesign? {
        guard DesignManifest.isValidID(id) else { return nil }   // never a path, such as "../x", or "Clean" on a case-insensitive volume
        return try await withLock(exclusive: false) { () throws(FileDesignStoreError) -> ValidatedDesign? in
            guard let entry = try readIndex().first(where: { $0.manifest.id == id }) else { return nil }
            return try readDesign(entry)
        } ?? nil
    }

    /// The design a listed entry's file holds, validated again, and the same as the index says.
    private func readDesign(_ entry: Entry) throws(FileDesignStoreError) -> ValidatedDesign {
        let id = entry.manifest.id
        let data: Data
        switch readRegularFile(file(entry), cap: validator.maxBytes) {
        case .data(let bytes): data = bytes
        case .absent, .unreadable: throw .designUnreadable(id: id)
        case .tooLarge(let bytes): throw .designTooLarge(id: id, bytes: bytes)
        }
        let design: ValidatedDesign
        do throws(DesignPackageRejected) { design = try validator.validate(data) } catch { throw .designRejected(id: id, error.violations) }
        guard design.manifest == entry.manifest else { throw .designRejected(id: id, [.malformed("the manifest differs from the index")]) }
        return design
    }

    public func installedDesigns() async throws(FileDesignStoreError) -> [DesignManifest] {
        try await withLock(exclusive: false) { () throws(FileDesignStoreError) in try readIndex().map(\.manifest) } ?? []
    }

    /// Records the installed design as bundled when it equals `design` and has no recorded origin. The index's manifest is
    /// compared first, then the design's own file, read and validated again. Only the index is rewritten, in one write.
    public func adoptAsBundled(_ design: ValidatedDesign) async throws(FileDesignStoreError) -> Bool {
        let id = design.manifest.id
        let adopted = try await withLock(exclusive: true) { () throws(FileDesignStoreError) -> Bool in
            let entries = try readIndex()
            guard let installed = entries.first(where: { $0.manifest.id == id }), installed.manifest == design.manifest,
                  installed.origin != .imported else { return false }
            guard try readDesign(installed) == design else { return false }
            if installed.origin == nil {
                let adopted = entries.map { $0.manifest.id == id ? $0.with(origin: .bundled) : $0 }
                try write(try encodeIndex(adopted, for: id), to: indexFile, for: id)
            }
            return true
        }
        guard let adopted else { throw .storeUnavailable }   // an exclusive lock creates the store, so it is never absent
        return adopted
    }

    /// Replaces a design recorded as bundled whatever the versions and whether or not its file can be read: the write
    /// path never reads the installed file, only the index.
    public func replaceBundled(_ design: ValidatedDesign) async throws(FileDesignStoreError) -> Bool {
        switch try await saveEntry(design, as: .bundled, mode: .replaceBundled) {
        case .upgraded: true
        case .installed, .keptInstalled, .keptOtherOrigin: false
        }
    }

    /// The origins the store has recorded, by identifier, for the designs it lists. A design whose entry has no origin has none.
    public func installedOrigins() async throws(FileDesignStoreError) -> [String: DesignOrigin] {
        try await withLock(exclusive: false) { () throws(FileDesignStoreError) -> [String: DesignOrigin] in
            Dictionary(uniqueKeysWithValues: try readIndex().compactMap { entry in entry.origin.map { (entry.manifest.id, $0.origin) } })
        } ?? [:]
    }

    // MARK: Locking

    /// Runs `body` holding the store lock. A shared lock on a store that does not exist yet returns nil and creates
    /// nothing: nothing has been saved. A store that exists but cannot be reached is unavailable, never empty (R7).
    /// While the lock is held elsewhere the call pauses between attempts, suspended, and after the pauses of
    /// `lockWait` ends in `lockTimeout`. `body` never suspends, so no other call of this actor runs while it holds the
    /// lock.
    private func withLock<T>(exclusive: Bool, _ body: () throws(FileDesignStoreError) -> T) async throws(FileDesignStoreError) -> T? {
        if exclusive {
            do { try FileManager.default.createDirectory(at: designsDirectory, withIntermediateDirectories: true) } catch { throw .storeUnavailable }
        } else {
            var status = stat()
            guard stat(directory.path, &status) == 0 else {   // follows a link: the injected directory may be one
                guard errno == ENOENT, !Self.passesThroughDanglingLink(directory.path) else { throw .storeUnavailable }
                return nil
            }
            guard (status.st_mode & S_IFMT) == S_IFDIR else { throw .storeUnavailable }
        }
        let fd = open(directory.appendingPathComponent(".lock").path, O_CREAT | O_RDWR | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw .storeUnavailable }
        defer { close(fd) }
        var status = stat()
        guard fstat(fd, &status) == 0, (status.st_mode & S_IFMT) == S_IFREG else { throw .storeUnavailable }
        var waited = Duration.zero
        while flock(fd, (exclusive ? LOCK_EX : LOCK_SH) | LOCK_NB) != 0 {
            switch errno {
            case EINTR: continue
            case EWOULDBLOCK:
                guard let step = lockWait.step(after: waited) else { throw .lockTimeout }
                await lockWait.pause(step)
                waited += step
            default: throw .storeUnavailable
            }
        }
        defer { flock(fd, LOCK_UN) }
        try checkDesignsDirectory()
        return try body()
    }

    /// Whether the path, or one of its ancestors, is a symbolic link whose target is missing: a store that was moved
    /// away, not one that was never created.
    private static func passesThroughDanglingLink(_ path: String) -> Bool {
        var current = path
        while !current.isEmpty, current != "/" {
            var link = stat(), target = stat()
            if lstat(current, &link) == 0, (link.st_mode & S_IFMT) == S_IFLNK, stat(current, &target) != 0 { return true }
            current = (current as NSString).deletingLastPathComponent
        }
        return false
    }

    /// `Designs` is a real directory of the store, or absent before the first save: never a link that would move
    /// reads and writes elsewhere.
    private func checkDesignsDirectory() throws(FileDesignStoreError) {
        var status = stat()
        guard lstat(designsDirectory.path, &status) == 0 else {
            guard errno == ENOENT else { throw .storeUnavailable }
            return
        }
        guard (status.st_mode & S_IFMT) == S_IFDIR else { throw .storeUnavailable }
    }

    // MARK: Reading

    private enum Read { case absent, data(Data), unreadable, tooLarge(Int) }

    /// Reads a regular file of at most `cap` bytes. Anything else (a symbolic link, a named pipe, a directory, an I/O
    /// failure) is unreadable, and an oversized file is reported without being read. Opening never blocks.
    private func readRegularFile(_ url: URL, cap: Int) -> Read {
        let fd = open(url.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard fd >= 0 else { return errno == ENOENT ? .absent : .unreadable }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        var status = stat()
        guard fstat(fd, &status) == 0, (status.st_mode & S_IFMT) == S_IFREG else { return .unreadable }
        guard Int(status.st_size) <= cap else { return .tooLarge(Int(status.st_size)) }
        do {
            let data = try handle.read(upToCount: cap + 1) ?? Data()
            return data.count <= cap ? .data(data) : .tooLarge(data.count)
        } catch {
            return .unreadable
        }
    }

    /// The stored designs. A missing index is an empty store; any other failure leaves it untouched.
    private func readIndex() throws(FileDesignStoreError) -> [Entry] {
        let data: Data
        switch readRegularFile(indexFile, cap: Self.maxIndexBytes) {
        case .absent: return []
        case .data(let bytes): data = bytes
        case .unreadable: throw .indexUnreadable
        case .tooLarge: throw .indexCorrupt("too large")
        }
        return try decodeIndex(data)
    }

    /// The strict reader of the index: what a read decodes, and what a write must be read back as.
    private func decodeIndex(_ data: Data) throws(FileDesignStoreError) -> [Entry] {
        let version: Int
        do { version = try JSONDecoder().decode(Envelope.self, from: data).schemaVersion } catch { throw .indexCorrupt("no schema version") }
        // Schema 1 has no migration: it was only ever written by tests, since no app built a FileDesignStore before this version.
        guard version <= Self.indexVersion else { throw .indexFromNewerVersion(version) }
        guard version == Self.indexVersion else { throw .indexCorrupt("schema version \(version)") }
        let index: IndexV2
        do { index = try JSONDecoder().decode(IndexV2.self, from: data) } catch { throw .indexCorrupt("not an index") }
        let ids = index.designs.map(\.manifest.id)
        guard ids.allSatisfy(DesignManifest.isValidID), ids == ids.sorted(), Set(ids).count == ids.count,
              index.designs.allSatisfy({ (1...Self.maxGeneration).contains($0.generation) && Self.isValid($0.manifest) }) else {
            throw .indexCorrupt("entries")
        }
        return index.designs
    }

    /// The fields an index holds are checked as the validator checks them in a package (the identifier is checked
    /// with the list, and the version, palette and font scheme are typed, so they are checked by decoding): an entry the
    /// validator would refuse is corrupt.
    private static func isValid(_ manifest: DesignManifest) -> Bool {
        DesignManifest.isValidName(manifest.name) && DesignManifest.isValidDescription(manifest.description)
            && manifest.markupContract == MarkupContract.version
    }

    // MARK: Writing

    private func encode(_ value: some Encodable, for id: String) throws(FileDesignStoreError) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        do { return try encoder.encode(value) } catch { throw .writeFailed(id: id) }
    }

    /// The design file's bytes, only if the store's own validator reads them back as the same design.
    private func encodeReadingBack(_ design: ValidatedDesign) throws(FileDesignStoreError) -> Data {
        let id = design.manifest.id
        let data = try encode(PackageFile(manifest: design.manifest, cssContent: design.stylesheet.css,
                                          previewImageBase64: design.previewPNG?.base64EncodedString()), for: id)
        let readBack: ValidatedDesign
        do throws(DesignPackageRejected) { readBack = try validator.validate(data) } catch { throw .wouldNotReadBack(id: id) }
        guard readBack == design else { throw .wouldNotReadBack(id: id) }
        return data
    }

    /// The index's bytes for the listed designs, only if they are within the cap and the strict reader reads them back as the
    /// same entries, so nothing is written that could not be read back (R12).
    private func encodeIndex(_ listed: [Entry], for id: String) throws(FileDesignStoreError) -> Data {
        let data = try encode(IndexV2(schemaVersion: Self.indexVersion, designs: listed), for: id)
        guard data.count <= Self.maxIndexBytes else { throw .wouldNotReadBack(id: id) }
        let readBack: [Entry]
        do throws(FileDesignStoreError) { readBack = try decodeIndex(data) } catch { throw .wouldNotReadBack(id: id) }
        guard readBack == listed else { throw .wouldNotReadBack(id: id) }
        return data
    }

    private func write(_ data: Data, to url: URL, for id: String) throws(FileDesignStoreError) {
        do { try writeFile(data, url) } catch { throw .writeFailed(id: id) }
    }

    /// Removes the design files the index does not list: generations a later save superseded, and files a failed
    /// save left behind. Anything else in the folder is not the store's and stays.
    private func removeUnlistedFiles(keeping entries: [Entry], for id: String) throws(FileDesignStoreError) {
        let listed = Set(entries.map { Self.fileName($0.manifest.id, $0.generation) })
        let names: [String]
        do { names = try FileManager.default.contentsOfDirectory(atPath: designsDirectory.path) } catch { throw .storeUnavailable }
        for name in names where !listed.contains(name)
            && name.range(of: #"^[a-z0-9-]{1,64}\.[1-9][0-9]{0,9}\.mcvt\z"#, options: .regularExpression) != nil {
            let path = designsDirectory.appendingPathComponent(name).path
            var status = stat()
            guard lstat(path, &status) == 0 else { throw .writeFailed(id: id) }
            guard [S_IFREG, S_IFLNK].contains(status.st_mode & S_IFMT) else { continue }   // not a file the store writes
            guard unlink(path) == 0 else { throw .writeFailed(id: id) }
        }
    }
}
