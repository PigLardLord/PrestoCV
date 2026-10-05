import Foundation
#if canImport(Glibc)   // outbound adapter: platform code is allowed here (PlatformAdapters)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif
import CVDesignCatalog

/// Every way the store can fail has its own case (CleanErrors): nothing is reported as "no design".
public enum FileDesignStoreError: Error, Equatable, Sendable {
    /// The store directory cannot be created or listed, its lock cannot be taken, or its `Designs` folder is not a
    /// real directory.
    case storeUnavailable
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
///   lists each design with its current generation. Both writes are atomic. A save that fails before the index is
///   written leaves the listed version untouched; superseded and unlisted files are removed at the next save.
/// - A save holds an exclusive `flock` on the store and a read a shared one, so a second instance or another
///   process loses no index update.
/// - Files on disk are untrusted input (ValidatingBoundary): every read goes through the validator again and must match the index,
///   and a path that is not a regular file (a symbolic link, a named pipe) or a `Designs` folder that is not a real
///   directory is never used. Only validated designs leave the store.
public actor FileDesignStore: DesignStore {
    let directory: URL, validator: DesignPackageValidator

    public init(directory: URL, validator: DesignPackageValidator = DesignPackageValidator()) {
        self.directory = directory; self.validator = validator
    }

    static let indexVersion = 1, maxIndexBytes = 1024 * 1024, maxGeneration = Int(Int32.max)
    private var designsDirectory: URL { directory.appendingPathComponent("Designs", isDirectory: true) }
    private var indexFile: URL { directory.appendingPathComponent("index.json") }
    private static func fileName(_ id: String, _ generation: Int) -> String { "\(id).\(generation).mcvt" }
    private func file(_ entry: Entry) -> URL { designsDirectory.appendingPathComponent(Self.fileName(entry.manifest.id, entry.generation)) }

    /// A design file is a design package, in the format the validator reads.
    private struct PackageFile: Codable { let manifest: DesignManifest; let cssContent: String; let previewImageBase64: String? }
    /// Index schema 1: each stored design's manifest and the generation of its file.
    private struct IndexV1: Codable { let schemaVersion: Int; let designs: [Entry] }
    private struct Entry: Codable { let manifest: DesignManifest; let generation: Int }

    // MARK: DesignStore

    public func save(_ design: ValidatedDesign) async throws(FileDesignStoreError) {
        let id = design.manifest.id
        let package = try encodeReadingBack(design)
        _ = try withLock(exclusive: true) { () throws(FileDesignStoreError) in
            let entries = try readIndex()
            try removeUnlistedFiles(keeping: entries, for: id)
            let generation = (entries.first { $0.manifest.id == id }?.generation ?? 0) + 1
            guard generation <= Self.maxGeneration else { throw .wouldNotReadBack(id: id) }
            let entry = Entry(manifest: design.manifest, generation: generation)
            let listed = (entries.filter { $0.manifest.id != id } + [entry]).sorted { $0.manifest.id < $1.manifest.id }
            let index = try encode(IndexV1(schemaVersion: Self.indexVersion, designs: listed), for: id)
            guard index.count <= Self.maxIndexBytes else { throw .wouldNotReadBack(id: id) }
            try write(package, to: file(entry), for: id)
            try write(index, to: indexFile, for: id)
        }
    }

    public func design(id: String) async throws(FileDesignStoreError) -> ValidatedDesign? {
        guard DesignManifest.isValidID(id) else { return nil }   // never a path, such as "../x", or "Clean" on a case-insensitive volume
        return try withLock(exclusive: false) { () throws(FileDesignStoreError) -> ValidatedDesign? in
            guard let entry = try readIndex().first(where: { $0.manifest.id == id }) else { return nil }
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
        } ?? nil
    }

    public func installedDesigns() async throws(FileDesignStoreError) -> [DesignManifest] {
        try withLock(exclusive: false) { () throws(FileDesignStoreError) in try readIndex().map(\.manifest) } ?? []
    }

    // MARK: Locking

    /// Runs `body` holding the store lock. A shared lock on a store that does not exist yet returns nil and creates
    /// nothing: nothing has been saved. A store that exists but cannot be reached is unavailable, never empty (CleanErrors).
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
        struct Envelope: Decodable { let schemaVersion: Int }
        let version: Int
        do { version = try JSONDecoder().decode(Envelope.self, from: data).schemaVersion } catch { throw .indexCorrupt("no schema version") }
        guard version <= Self.indexVersion else { throw .indexFromNewerVersion(version) }
        guard version == Self.indexVersion else { throw .indexCorrupt("schema version \(version)") }
        let index: IndexV1
        do { index = try JSONDecoder().decode(IndexV1.self, from: data) } catch { throw .indexCorrupt("not an index") }
        let ids = index.designs.map(\.manifest.id)
        guard ids.allSatisfy(DesignManifest.isValidID), ids == ids.sorted(), Set(ids).count == ids.count,
              index.designs.allSatisfy({ (1...Self.maxGeneration).contains($0.generation) }) else {
            throw .indexCorrupt("entries")
        }
        return index.designs
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

    private func write(_ data: Data, to url: URL, for id: String) throws(FileDesignStoreError) {
        do { try data.write(to: url, options: .atomic) } catch { throw .writeFailed(id: id) }
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
