import Foundation
import PrestoCVDomain
import PrestoCVApplication

/// The person's letter defaults on disk (ADR 0019, ADR 0009, R12): one `LetterDefaultsFileV1` file, in a directory of its own
/// with its own lock and its own `Quarantine/`, on the same store mechanics as the CV repository. A save is conditional on the
/// revision under an exclusive `flock`, so it holds across instances and processes, and the first save expects no file.
///
/// A missing file is empty defaults, and nothing else is: a file that is newer, unreadable, oversized or corrupt is reported
/// by its own outcome, never read as empty (R7). A corrupt file is moved to the quarantine, and the store remembers it by the
/// copy that stands there: while a copy stands and no file replaces it, every load reports `corrupt`, until the user restores
/// the copy or saves new defaults, or the copy is purged or erased. The revision restarts after a quarantine or an erase, since
/// the file is gone, so a window that still holds an old revision N can overwrite once the counter reaches N again: rare, and a
/// known limitation. The composition root keeps one instance per process (ADR 0008). Waiting for the lock blocks a thread of
/// the cooperative pool: #111.
public actor FileLetterDefaultsStore: LetterDefaultsStore, LetterDefaultsMaintenance {
    private let store: StoreDirectory<LetterDefaultsError>

    public init(directory: URL, clock: any TimeSource, maxFileBytes: Int = 64 * 1024) {
        store = StoreDirectory(directory: directory, clock: clock, maxFileBytes: maxFileBytes)
    }

    static let fileName = "letter-defaults.json"
    private static let namePattern = "letter-defaults\\.json"
    private var file: URL { store.directory.appendingPathComponent(Self.fileName) }

    private func read(_ url: URL) -> StoredFile<StoredLetterDefaults> {
        StoredFile<StoredLetterDefaults>.read(url, maxBytes: store.maxFileBytes, supportedVersion: LetterDefaultsFileV1.version, decode: LetterDefaultsFileV1.read)
    }

    /// Writes only what this store will be able to read back: the encoded file must be within the size cap and must decode,
    /// through the same strict path as a read, to the same defaults.
    private func write(_ stored: StoredLetterDefaults) throws(LetterDefaultsError) {
        guard let updated = stored.updatedAt else { throw .writeFailed(file: Self.fileName) }
        try store.write(Self.fileName, encoded: { try LetterDefaultsFileV1(stored, updatedAt: updated).encoded() },
                        readsBack: { data in try LetterDefaultsFileV1.read(data) == stored })
    }

    /// The corrupt copy that stands in the quarantine, if one does, as the error that reports it: the newest, by the time it entered
    /// the quarantine and, within the same second, by its number, which a later copy of the same name gets higher (`10~` is newer
    /// than `2~`, and a name with no number is the oldest). Call it under the lock.
    private func standingCopy() throws(LetterDefaultsError) -> LetterDefaultsError? {
        var newest: (name: String, stamp: Date, number: Int)?
        for name in try store.quarantineNames() where name.range(of: "^(\\d+~)?" + Self.namePattern + "\\z", options: .regularExpression) != nil {
            let stamp: Date
            do { stamp = try FileManager.default.attributesOfItem(atPath: store.quarantine.appendingPathComponent(name).path)[.modificationDate] as? Date ?? .distantPast }
            catch { throw .unreadable(file: name) }
            let number = Int(name.prefix { $0.isNumber }) ?? 0
            if let current = newest, (current.stamp, current.number) >= (stamp, number) { continue }
            newest = (name, stamp, number)
        }
        guard let copy = newest else { return nil }
        var reason = "quarantined"
        if case .corrupt(let found) = read(store.quarantine.appendingPathComponent(copy.name)) { reason = found }
        return .corrupt(file: copy.name, reason: reason)
    }

    // MARK: LetterDefaultsStore

    public func load() async throws(LetterDefaultsError) -> StoredLetterDefaults {
        // Only a store that does not exist yet means "empty". Anything else is an error.
        switch store.state() {
        case .absent: return .unsaved
        case .unavailable(let failure): throw .storeUnavailable(failure)
        case .present: break
        }
        return try store.withLock { () throws(LetterDefaultsError) -> StoredLetterDefaults in
            switch read(file) {
            case .value(let stored): return stored
            case .absent:
                if let remembered = try standingCopy() { throw remembered }
                return .unsaved
            case .newer(let version): throw .upgradeRequired(file: Self.fileName, version: version)
            case .unreadable: throw .unreadable(file: Self.fileName)
            case .tooLarge: throw .tooLarge(file: Self.fileName)
            case .corrupt(let reason):
                guard let moved = store.moveToQuarantine(file) else { throw .quarantineFailed(file: Self.fileName) }
                throw .corrupt(file: moved.lastPathComponent, reason: reason)
            }
        }
    }

    public func save(_ defaults: LetterDefaults, expectedRevision: Int) async throws(LetterDefaultsError) -> StoredLetterDefaults {
        try store.withLock { () throws(LetterDefaultsError) -> StoredLetterDefaults in
            let existing = try store.current(file, read: { read($0) })
            let storedRevision = existing?.revision ?? 0
            guard storedRevision == expectedRevision else { throw .conflict(storedRevision: storedRevision) }
            let stored = StoredLetterDefaults(defaults: defaults, revision: storedRevision + 1, updatedAt: store.now())
            try write(stored)
            return stored
        }
    }

    public func erase() async throws(LetterDefaultsError) {
        try store.withLock { () throws(LetterDefaultsError) in try store.eraseCopies(of: Self.fileName) }
    }

    // MARK: LetterDefaultsMaintenance

    public func restore(quarantined name: String) async throws(LetterDefaultsError) -> StoredLetterDefaults {
        try store.restore(quarantined: name, pattern: Self.namePattern, taken: { _ in .alreadyExists }, read: { source, _ in read(source) })
    }

    public func purgeQuarantine(olderThan date: Date) async throws(LetterDefaultsError) -> Int {
        try store.purgeQuarantine(olderThan: date)
    }
}
