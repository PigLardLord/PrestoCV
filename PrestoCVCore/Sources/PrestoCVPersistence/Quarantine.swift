import Foundation
import PrestoCVApplication
import PrestoCVDomain

/// The `Quarantine/` folder of a store: where a corrupt file is moved aside so that it is neither read again nor lost, and
/// from where it is restored, erased, or purged after its retention period (PersistedSchema). Only a real directory of
/// the store is used, never a link.
struct Quarantine {
    let folder: URL

    init(storeDirectory: URL) { folder = storeDirectory.appendingPathComponent("Quarantine", isDirectory: true) }

    /// What is at the folder's path. A link is not a directory: it is never followed.
    private var kind: FileKind { StoreFiles.status(of: folder.path).kind }

    /// Refuses a folder that is there but is not a real directory. An absent folder is fine: nothing was quarantined yet.
    func requireUsable() throws(RepositoryError) {
        switch kind {
        case .missing, .directory: return
        case .inaccessible, .regularFile, .symbolicLink, .other: throw .storeUnavailable(.notADirectory)
        }
    }

    /// The entries of the folder. An absent folder is empty; one that is not a real directory is never used.
    func names() throws(RepositoryError) -> [String] {
        switch kind {
        case .missing: return []
        case .directory: return try entries()
        case .inaccessible, .regularFile, .symbolicLink, .other: throw .storeUnavailable(.notADirectory)
        }
    }

    /// The file called `name`, which is always a direct child of the folder: the name is validated, and this is checked again
    /// at the one place a path is built from it.
    func file(_ name: QuarantinedName) throws(RepositoryError) -> URL {
        let url = folder.appendingPathComponent(name.value)
        guard url.deletingLastPathComponent().standardizedFileURL == folder.standardizedFileURL else { throw .invalidName(name.value) }
        return url
    }

    /// Every quarantined copy of the stored file called `storedName`.
    func copies(of storedName: String) throws(RepositoryError) -> [URL] {
        try names().filter { QuarantinedName.isCopy($0, of: storedName) }.map { folder.appendingPathComponent($0) }
    }

    /// Moves `file` into the folder, stamped with the time `now` gives: the retention period starts when a file is
    /// isolated, and its own modification time says nothing about that. `now` is read only once the folder can take the
    /// file.
    ///
    /// - Throws: `RepositoryError.writeFailed` for the file, whatever the reason it could not be moved.
    func admit(_ file: URL, stampedWith now: () -> Date) throws(RepositoryError) {
        let failure = RepositoryError.writeFailed(file: file.lastPathComponent)
        do { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true) } catch { throw failure }
        guard kind == .directory else { throw failure }
        do {
            try FileManager.default.setAttributes([.modificationDate: now()], ofItemAtPath: file.path)
            try FileManager.default.moveItem(at: file, to: unusedURL(for: file.lastPathComponent))
        } catch {
            throw failure
        }
    }

    /// Removes the entries that entered the folder before `date`, and returns how many. An entry's age counts from `admit`.
    func purge(olderThan date: Date) throws(RepositoryError) -> Int {
        var removed = 0
        for name in try names() {
            let file = folder.appendingPathComponent(name)
            guard let modified = try modificationDate(of: file), modified < date else { continue }
            try StoreFiles.remove(file)
            removed += 1
        }
        return removed
    }

    private func entries() throws(RepositoryError) -> [String] {
        do { return try FileManager.default.contentsOfDirectory(atPath: folder.path) } catch { throw .storeUnavailable(.cannotList) }
    }

    private func modificationDate(of file: URL) throws(RepositoryError) -> Date? {
        do {
            return try FileManager.default.attributesOfItem(atPath: file.path)[.modificationDate] as? Date
        } catch {
            throw .unreadable(file: file.lastPathComponent)
        }
    }

    private func unusedURL(for storedName: String) -> URL {
        var candidate = folder.appendingPathComponent(storedName)
        var attempt = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent(QuarantinedName.prefixed(storedName, attempt: attempt))
            attempt += 1
        }
        return candidate
    }
}

/// The name of a file in the quarantine: the name it had in the store, with a prefix `N~` when an earlier copy of it is
/// already there. It is validated in full, so a name cannot lead out of the folder.
struct QuarantinedName {
    /// As it is in the folder.
    let value: String
    /// The name the file had in the store.
    let storedName: String
    let id: CVID

    private static let separator = "~"   // never occurs in an identifier
    private static let uuidPattern = "[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}"
    private static let prefixPattern = "^[0-9]+" + separator

    init?(_ value: String) {
        let pattern = "([0-9]+" + Self.separator + ")?" + Self.uuidPattern + NSRegularExpression.escapedPattern(for: StoredFileName.suffix)
        guard value.range(of: "^" + pattern + "\\z", options: .regularExpression) != nil else { return nil }
        let storedName = value.replacingOccurrences(of: Self.prefixPattern, with: "", options: .regularExpression)
        guard let uuid = UUID(uuidString: String(storedName.prefix(36))) else { return nil }
        self.value = value; self.storedName = storedName; id = CVID(uuid)
    }

    /// The name of a later copy of `storedName`, which takes the place of one already there.
    static func prefixed(_ storedName: String, attempt: Int) -> String { "\(attempt)" + separator + storedName }

    static func isCopy(_ name: String, of storedName: String) -> Bool { name == storedName || name.hasSuffix(separator + storedName) }
}
