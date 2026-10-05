import Foundation
#if canImport(Glibc)   // outbound adapter: platform code is allowed here (R11)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif
import CVDesignCatalog

/// Every way the store can fail has its own case (R7): nothing is reported as "no design".
public enum FileDesignStoreError: Error, Equatable, Sendable {
    /// The store directory cannot be created or listed, its lock cannot be taken, or its `Designs` folder is not a
    /// real directory.
    case storeUnavailable
    /// The index cannot be read (an I/O failure, or not a regular file), is corrupt, or was written by a newer
    /// version. It is left untouched, and nothing is saved over it.
    case indexUnreadable, indexCorrupt(String), indexFromNewerVersion(Int)
    /// The origin record cannot be read (an I/O failure, or not a regular file), is corrupt, or was written by a newer
    /// version. Like the index, it is left untouched, and nothing is saved over it.
    case originsUnreadable, originsCorrupt(String), originsFromNewerVersion(Int)
    /// A listed design cannot be read, is larger than the validator accepts, or no longer passes validation.
    case designUnreadable(id: String), designTooLarge(id: String, bytes: Int), designRejected(id: String, [DesignPackageViolation])
    /// The design, once encoded, would not validate back to itself, so nothing was written.
    case wouldNotReadBack(id: String)
    case writeFailed(id: String)
}

/// The design store on disk (ADR 0002, ADR 0011). The directory is injected, and the composition root keeps one
/// instance per process (ADR 0008).
///
/// - Every save of a design writes a new generation of its package file under `Designs/`, then `origins.json`, then
///   `index.json`, which lists each design with its current generation. Each write is atomic. A save that fails before
///   the index is written leaves the listed version untouched; superseded and unlisted files are removed at the next save.
/// - `origins.json`, next to the index, records for each design whether the catalog's sync installed it (`bundled`) or
///   an import did (`imported`). It is the store's own record: a package is untrusted, so it cannot say what it is.
///   Because it is written before the index, a save that stops early leaves, at worst, an entry for a design the index
///   does not list. Such an entry is never reported and the next save drops it. A design that has no entry (installed
///   before origins were recorded) has no origin: the caller decides what that means.
/// - A save never replaces a design of the other origin, and the store decides that under its lock: an import leaves an
///   installed bundled design alone (`ImportSave.keptBundled`), and a conditional save leaves alone one that is not
///   recorded as bundled (`ConditionalSave.keptImported`).
/// - A save holds an exclusive `flock` on the store and a read a shared one, so a second instance or another
///   process loses no index update.
/// - Files on disk are untrusted input (R8): every read goes through the validator again and must match the index,
///   and a path that is not a regular file (a symbolic link, a named pipe) or a `Designs` folder that is not a real
///   directory is never used. Only validated designs leave the store.
public actor FileDesignStore: DesignStore {
    let directory: URL, validator: DesignPackageValidator
    /// The most bytes the origin record may have, when it is read and before it is written.
    let originsCap: Int
    /// How a file of the store is written. Tests replace it to see the order of the writes and to fail one of them.
    let writeFile: @Sendable (Data, URL) throws -> Void

    public init(directory: URL, validator: DesignPackageValidator = DesignPackageValidator()) {
        self.init(directory: directory, validator: validator, originsCap: Self.maxOriginsBytes, writeFile: Self.writeAtomically)
    }

    init(directory: URL, validator: DesignPackageValidator = DesignPackageValidator(), originsCap: Int) {
        self.init(directory: directory, validator: validator, originsCap: originsCap, writeFile: Self.writeAtomically)
    }

    init(directory: URL, validator: DesignPackageValidator = DesignPackageValidator(), writeFile: @escaping @Sendable (Data, URL) throws -> Void) {
        self.init(directory: directory, validator: validator, originsCap: Self.maxOriginsBytes, writeFile: writeFile)
    }

    private init(directory: URL, validator: DesignPackageValidator, originsCap: Int, writeFile: @escaping @Sendable (Data, URL) throws -> Void) {
        self.directory = directory; self.validator = validator; self.originsCap = originsCap; self.writeFile = writeFile
    }

    private static func writeAtomically(_ data: Data, to url: URL) throws { try data.write(to: url, options: .atomic) }

    /// The index's schema version. An index written with a new palette or font scheme cannot be read by an older app:
    /// bump the index version when these change.
    static let indexVersion = 2
    /// The origin record's schema version. A record written with a new origin cannot be read by an older app: bump it
    /// when an origin is added.
    static let originsVersion = 1
    static let maxIndexBytes = 1024 * 1024, maxGeneration = Int(Int32.max)
    /// The origin record's cap. An origin entry is shorter than an index entry, so the record of designs that fit the
    /// index fits it.
    static let maxOriginsBytes = maxIndexBytes
    private var designsDirectory: URL { directory.appendingPathComponent("Designs", isDirectory: true) }
    private var indexFile: URL { directory.appendingPathComponent("index.json") }
    private var originsFile: URL { directory.appendingPathComponent("origins.json") }
    private static func fileName(_ id: String, _ generation: Int) -> String { "\(id).\(generation).mcvt" }
    private func file(_ entry: Entry) -> URL { designsDirectory.appendingPathComponent(Self.fileName(entry.manifest.id, entry.generation)) }

    /// A design file is a design package, in the format the validator reads.
    private struct PackageFile: Codable { let manifest: DesignManifest; let cssContent: String; let previewImageBase64: String? }
    /// Index schema 2: each stored design's manifest and the generation of its file.
    private struct IndexV2: Codable { let schemaVersion: Int; let designs: [Entry] }
    private struct Entry: Codable { let manifest: DesignManifest; let generation: Int }
    /// Origin record schema 1: the origin of each design that has one, ordered by identifier.
    private struct OriginsV1: Codable { let schemaVersion: Int; let designs: [OriginEntry] }
    private struct OriginEntry: Codable { let id: String; let origin: DesignOrigin }
    private struct Envelope: Decodable { let schemaVersion: Int }

    // MARK: DesignStore

    @discardableResult public func save(_ design: ValidatedDesign) async throws(FileDesignStoreError) -> ImportSave {
        switch try saveEntry(design, as: .imported, onlyIfNewer: false) {
        case .keptOtherOrigin: .keptBundled
        case .installed, .upgraded, .keptInstalled: .saved
        }
    }

    public func saveIfNewer(_ design: ValidatedDesign) async throws(FileDesignStoreError) -> ConditionalSave {
        switch try saveEntry(design, as: .bundled, onlyIfNewer: true) {
        case .installed: .installed
        case .upgraded: .upgraded
        case .keptInstalled: .keptInstalled
        case .keptOtherOrigin: .keptImported
        }
    }

    private enum Written { case installed, upgraded, keptInstalled, keptOtherOrigin }

    /// The one write path, which records the design's `origin`. The installed design is judged inside the exclusive lock
    /// that the write holds, and a save never replaces a design of the other origin: an import leaves an installed bundled
    /// design alone, and a bundled save leaves alone one that the store did not record as bundled (`keptOtherOrigin`).
    /// With `onlyIfNewer`, an installed design of the same or a newer version is left alone as well.
    private func saveEntry(_ design: ValidatedDesign, as origin: DesignOrigin, onlyIfNewer: Bool) throws(FileDesignStoreError) -> Written {
        let id = design.manifest.id
        let package = try encodeReadingBack(design)
        let outcome = try withLock(exclusive: true) { () throws(FileDesignStoreError) -> Written in
            let entries = try readIndex()
            var origins = try readOrigins()
            let installed = entries.first { $0.manifest.id == id }
            if let installed {
                if onlyIfNewer {
                    guard origins[id] == .bundled else { return .keptOtherOrigin }
                    if design.manifest.version <= installed.manifest.version { return .keptInstalled }
                } else if origins[id] == .bundled {
                    return .keptOtherOrigin
                }
            }
            try removeUnlistedFiles(keeping: entries, for: id)
            let generation = (installed?.generation ?? 0) + 1
            guard generation <= Self.maxGeneration else { throw .wouldNotReadBack(id: id) }
            let entry = Entry(manifest: design.manifest, generation: generation)
            let listed = (entries.filter { $0.manifest.id != id } + [entry]).sorted { $0.manifest.id < $1.manifest.id }
            let index = try encode(IndexV2(schemaVersion: Self.indexVersion, designs: listed), for: id)
            guard index.count <= Self.maxIndexBytes else { throw .wouldNotReadBack(id: id) }
            origins[id] = origin
            let record = try encodeOrigins(origins, listing: listed, for: id)
            try write(package, to: file(entry), for: id)
            try write(record, to: originsFile, for: id)
            try write(index, to: indexFile, for: id)
            return installed == nil ? .installed : .upgraded
        }
        guard let outcome else { throw .storeUnavailable }   // an exclusive lock creates the store, so it is never absent
        return outcome
    }

    public func design(id: String) async throws(FileDesignStoreError) -> ValidatedDesign? {
        guard DesignManifest.isValidID(id) else { return nil }   // never a path, such as "../x", or "Clean" on a case-insensitive volume
        return try withLock(exclusive: false) { () throws(FileDesignStoreError) -> ValidatedDesign? in
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
        try withLock(exclusive: false) { () throws(FileDesignStoreError) in try readIndex().map(\.manifest) } ?? []
    }

    /// Records the installed design as bundled when it equals `design` and has no recorded origin. The index's manifest is
    /// compared first, then the design's own file, read and validated again. Only the record is written.
    public func adoptAsBundled(_ design: ValidatedDesign) async throws(FileDesignStoreError) -> Bool {
        let id = design.manifest.id
        let adopted = try withLock(exclusive: true) { () throws(FileDesignStoreError) -> Bool in
            let entries = try readIndex()
            var origins = try readOrigins()
            guard let installed = entries.first(where: { $0.manifest.id == id }), installed.manifest == design.manifest,
                  origins[id] != .imported else { return false }
            guard try readDesign(installed) == design else { return false }
            if origins[id] == nil {
                origins[id] = .bundled
                try write(try encodeOrigins(origins, listing: entries, for: id), to: originsFile, for: id)
            }
            return true
        }
        guard let adopted else { throw .storeUnavailable }   // an exclusive lock creates the store, so it is never absent
        return adopted
    }

    /// The origins the store has recorded, by identifier, for the designs it lists. A design with no entry has no origin.
    public func installedOrigins() async throws(FileDesignStoreError) -> [String: DesignOrigin] {
        try withLock(exclusive: false) { () throws(FileDesignStoreError) -> [String: DesignOrigin] in
            let listed = Set(try readIndex().map(\.manifest.id))
            return try readOrigins().filter { listed.contains($0.key) }
        } ?? [:]
    }

    // MARK: Locking

    /// Runs `body` holding the store lock. A shared lock on a store that does not exist yet returns nil and creates
    /// nothing: nothing has been saved. A store that exists but cannot be reached is unavailable, never empty (R7).
    private func withLock<T>(exclusive: Bool, _ body: () throws(FileDesignStoreError) -> T) throws(FileDesignStoreError) -> T? {
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
        while flock(fd, exclusive ? LOCK_EX : LOCK_SH) != 0 {
            guard errno == EINTR else { throw .storeUnavailable }
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
        let version: Int
        do { version = try JSONDecoder().decode(Envelope.self, from: data).schemaVersion } catch { throw .indexCorrupt("no schema version") }
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

    /// The recorded origins. A missing record is an empty one; any other failure leaves it untouched.
    private func readOrigins() throws(FileDesignStoreError) -> [String: DesignOrigin] {
        let data: Data
        switch readRegularFile(originsFile, cap: originsCap) {
        case .absent: return [:]
        case .data(let bytes): data = bytes
        case .unreadable: throw .originsUnreadable
        case .tooLarge: throw .originsCorrupt("too large")
        }
        return try decodeOrigins(data)
    }

    /// The strict reader of the origin record: what a read decodes, and what a write must be read back as.
    private func decodeOrigins(_ data: Data) throws(FileDesignStoreError) -> [String: DesignOrigin] {
        let version: Int
        do { version = try JSONDecoder().decode(Envelope.self, from: data).schemaVersion } catch { throw .originsCorrupt("no schema version") }
        guard version <= Self.originsVersion else { throw .originsFromNewerVersion(version) }
        guard version == Self.originsVersion else { throw .originsCorrupt("schema version \(version)") }
        let record: OriginsV1
        do { record = try JSONDecoder().decode(OriginsV1.self, from: data) } catch { throw .originsCorrupt("not an origin record") }
        let ids = record.designs.map(\.id)
        guard ids.allSatisfy(DesignManifest.isValidID), ids == ids.sorted(), Set(ids).count == ids.count else { throw .originsCorrupt("entries") }
        return Dictionary(uniqueKeysWithValues: record.designs.map { ($0.id, $0.origin) })
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

    /// The record of the origins of the listed designs, ordered by identifier. A design with no origin has no entry. The
    /// bytes are returned only if they are within the cap and the strict reader reads them back as the same origins, so
    /// nothing is written that could not be read back (R12).
    private func encodeOrigins(_ origins: [String: DesignOrigin], listing entries: [Entry], for id: String) throws(FileDesignStoreError) -> Data {
        let listed = entries.map(\.manifest.id)
        let recorded = listed.compactMap { id in origins[id].map { OriginEntry(id: id, origin: $0) } }
        let data = try encode(OriginsV1(schemaVersion: Self.originsVersion, designs: recorded), for: id)
        guard data.count <= originsCap else { throw .wouldNotReadBack(id: id) }
        let readBack: [String: DesignOrigin]
        do throws(FileDesignStoreError) { readBack = try decodeOrigins(data) } catch { throw .wouldNotReadBack(id: id) }
        guard readBack == Dictionary(uniqueKeysWithValues: recorded.map { ($0.id, $0.origin) }) else { throw .wouldNotReadBack(id: id) }
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
