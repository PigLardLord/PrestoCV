import Foundation
#if canImport(Glibc)
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
    private typealias Entry = DesignIndex.Entry

    private let directory: StoreDirectory, validator: DesignPackageValidator

    public init(directory: URL, validator: DesignPackageValidator = DesignPackageValidator()) {
        self.directory = StoreDirectory(url: directory)
        self.validator = validator
    }

    private var indexFile: URL { directory.url.appendingPathComponent("index.json") }

    /// A design file is a design package, in the format the validator reads.
    private struct PackageFile: Codable { let manifest: DesignManifest; let cssContent: String; let previewImageBase64: String? }

    // MARK: DesignStore

    public func save(_ design: ValidatedDesign) async throws(FileDesignStoreError) {
        let id = design.manifest.id
        let package = try encodeReadingBack(design)
        try directory.withExclusiveLock { () throws(FileDesignStoreError) in
            let entries = try readIndex()
            try removeUnlistedFiles(keeping: entries, for: id)
            let entry = Entry(manifest: design.manifest, generation: try nextGeneration(after: entries, for: id))
            let listed = (entries.filter { $0.manifest.id != id } + [entry]).sorted { $0.manifest.id < $1.manifest.id }
            let index = try encode(DesignIndex(designs: listed), for: id)
            guard index.count <= DesignIndex.maxBytes else { throw .wouldNotReadBack(id: id) }
            try write(package, to: file(entry), for: id)
            try write(index, to: indexFile, for: id)
        }
    }

    public func design(id: String) async throws(FileDesignStoreError) -> ValidatedDesign? {
        guard DesignManifest.isValidID(id) else { return nil }   // never a path, such as "../x", or "Clean" on a case-insensitive volume
        return try directory.withSharedLock { () throws(FileDesignStoreError) -> ValidatedDesign? in
            guard let entry = try readIndex().first(where: { $0.manifest.id == id }) else { return nil }
            return try readDesign(entry)
        } ?? nil
    }

    public func installedDesigns() async throws(FileDesignStoreError) -> [DesignManifest] {
        try directory.withSharedLock { () throws(FileDesignStoreError) in try readIndex().map(\.manifest) } ?? []
    }

    // MARK: Reading

    /// The stored designs. A missing index is an empty store; any other failure leaves it untouched.
    private func readIndex() throws(FileDesignStoreError) -> [Entry] {
        switch RegularFile.read(indexFile, cap: DesignIndex.maxBytes) {
        case .absent: return []
        case .data(let bytes): return try DesignIndex.entries(from: bytes)
        case .unreadable: throw .indexUnreadable
        case .tooLarge: throw .indexCorrupt("too large")
        }
    }

    private func readDesign(_ entry: Entry) throws(FileDesignStoreError) -> ValidatedDesign {
        let id = entry.manifest.id
        let data = try designBytes(of: entry)
        let design: ValidatedDesign
        do throws(DesignPackageRejected) { design = try validator.validate(data) } catch { throw .designRejected(id: id, error.violations) }
        guard design.manifest == entry.manifest else { throw .designRejected(id: id, [.malformed("the manifest differs from the index")]) }
        return design
    }

    private func designBytes(of entry: Entry) throws(FileDesignStoreError) -> Data {
        switch RegularFile.read(file(entry), cap: validator.maxBytes) {
        case .data(let bytes): return bytes
        case .absent, .unreadable: throw .designUnreadable(id: entry.manifest.id)
        case .tooLarge(let bytes): throw .designTooLarge(id: entry.manifest.id, bytes: bytes)
        }
    }

    // MARK: Writing

    private func nextGeneration(after entries: [Entry], for id: String) throws(FileDesignStoreError) -> Int {
        let generation = (entries.first { $0.manifest.id == id }?.generation ?? 0) + 1
        guard generation <= DesignIndex.maxGeneration else { throw .wouldNotReadBack(id: id) }
        return generation
    }

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

    // MARK: Design files

    private func file(_ entry: Entry) -> URL {
        directory.designsURL.appendingPathComponent(GenerationFileName.make(id: entry.manifest.id, generation: entry.generation))
    }

    /// Removes the design files the index does not list: generations a later save superseded, and files a failed
    /// save left behind. Anything else in the folder is not the store's and stays.
    private func removeUnlistedFiles(keeping entries: [Entry], for id: String) throws(FileDesignStoreError) {
        let listed = Set(entries.map { GenerationFileName.make(id: $0.manifest.id, generation: $0.generation) })
        let names: [String]
        do { names = try FileManager.default.contentsOfDirectory(atPath: directory.designsURL.path) } catch { throw .storeUnavailable }
        for name in names where !listed.contains(name) && GenerationFileName.matches(name) { try remove(name, for: id) }
    }

    private func remove(_ name: String, for id: String) throws(FileDesignStoreError) {
        let path = directory.designsURL.appendingPathComponent(name).path
        guard let status = FileStatus.ofLink(path: path) else { throw .writeFailed(id: id) }
        guard status.isRegularFile || status.isSymbolicLink else { return }   // not a file the store writes
        guard unlink(path) == 0 else { throw .writeFailed(id: id) }
    }
}

/// The name of a design file: the design's identifier and the generation of the save that wrote it.
private enum GenerationFileName {
    static func make(id: String, generation: Int) -> String { "\(id).\(generation).mcvt" }

    static func matches(_ name: String) -> Bool {
        name.range(of: #"^[a-z0-9-]{1,64}\.[1-9][0-9]{0,9}\.mcvt\z"#, options: .regularExpression) != nil
    }
}
