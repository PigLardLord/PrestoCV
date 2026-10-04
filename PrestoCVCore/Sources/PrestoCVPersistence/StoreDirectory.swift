import Foundation
#if canImport(Glibc)   // outbound adapter: platform code is allowed here (R11)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif
import PrestoCVDomain
import PrestoCVApplication

/// A failure of the store itself, with no identity of a stored value. Each store's own error type maps it (R7).
enum StoreFault: Equatable {
    case unavailable(StoreFailure), unreadable(file: String), writeFailed(file: String), invalidName(String)
    case corrupt(file: String, reason: String), tooLarge(file: String), upgradeRequired(file: String, version: Int), wouldNotReadBack(file: String)
}

protocol StoreFaultConvertible: Error { init(_ fault: StoreFault) }

extension RepositoryError: StoreFaultConvertible {
    init(_ fault: StoreFault) {
        switch fault {
        case .unavailable(let failure): self = .storeUnavailable(failure)
        case .unreadable(let file): self = .unreadable(file: file)
        case .writeFailed(let file): self = .writeFailed(file: file)
        case .invalidName(let name): self = .invalidName(name)
        case .corrupt(let file, _): self = .corrupt(file: file)
        case .tooLarge(let file): self = .tooLarge(file: file)
        case .upgradeRequired(let file, let version): self = .upgradeRequired(file: file, version: version)
        case .wouldNotReadBack(let file): self = .wouldNotReadBack(file: file)
        }
    }
}

extension ApplicationRepositoryError: StoreFaultConvertible {
    init(_ fault: StoreFault) {
        switch fault {
        case .unavailable(let failure): self = .storeUnavailable(failure)
        case .unreadable(let file): self = .unreadable(file: file)
        case .writeFailed(let file): self = .writeFailed(file: file)
        case .invalidName(let name): self = .invalidName(name)
        case .corrupt(let file, _): self = .corrupt(file: file)
        case .tooLarge(let file): self = .tooLarge(file: file)
        case .upgradeRequired(let file, let version): self = .upgradeRequired(file: file, version: version)
        case .wouldNotReadBack(let file): self = .wouldNotReadBack(file: file)
        }
    }
}

extension LetterDefaultsError: StoreFaultConvertible {
    init(_ fault: StoreFault) {
        switch fault {
        case .unavailable(let failure): self = .storeUnavailable(failure)
        case .unreadable(let file): self = .unreadable(file: file)
        case .writeFailed(let file): self = .writeFailed(file: file)
        case .invalidName(let name): self = .invalidName(name)
        case .corrupt(let file, let reason): self = .corrupt(file: file, reason: reason)
        case .tooLarge(let file): self = .tooLarge(file: file)
        case .upgradeRequired(let file, let version): self = .upgradeRequired(file: file, version: version)
        case .wouldNotReadBack(let file): self = .wouldNotReadBack(file: file)
        }
    }
}

/// The store itself: absent before the first save; unavailable when it cannot be reached, sits behind a link whose
/// target is gone, or is not a directory. The store may be reached through a link.
enum StoreState { case present, absent, unavailable(StoreFailure) }

enum StoreNames {
    static let uuidPattern = "[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}"
}

/// Atomic, and on Apple platforms unreadable while the device is locked. The simulator does not apply protection.
enum StoreWriting { static let options: Data.WritingOptions = [.atomic, .completeFileProtection] }

/// The directory of one store and what R12 asks of it, shared by every file store of this target: the exclusive lock,
/// reading a store that may not be there, the quarantine and its retention, erasure of every copy, and writing only what
/// can be read back. Whatever is specific to a store's files stays with the store: its names, its schema and its identity.
/// `Failure` is the store's own error type.
struct StoreDirectory<Failure: StoreFaultConvertible>: Sendable {
    let directory: URL
    let clock: any TimeSource
    let maxFileBytes: Int
    var quarantine: URL { directory.appendingPathComponent("Quarantine", isDirectory: true) }

    // MARK: Locking

    func withLock<T>(_ body: () throws(Failure) -> T) throws(Failure) -> T {
        do { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
        catch { throw Failure(.unavailable(.cannotLock)) }
        // Never through a link, and never on anything but a regular file: opening does not block.
        let fd = open(directory.appendingPathComponent(".lock").path, O_CREAT | O_RDWR | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw Failure(.unavailable(.cannotLock)) }
        defer { close(fd) }
        var status = stat()
        guard fstat(fd, &status) == 0, (status.st_mode & S_IFMT) == S_IFREG else { throw Failure(.unavailable(.cannotLock)) }
        while flock(fd, LOCK_EX) != 0 {
            guard errno == EINTR else { throw Failure(.unavailable(.cannotLock)) }
        }
        defer { flock(fd, LOCK_UN) }
        return try body()
    }

    // MARK: The store and its entries

    /// Whether anything is at `url`, a link included, without following it. Only ENOENT means nothing is there.
    func exists(_ url: URL) throws(Failure) -> Bool {
        var status = stat()
        if lstat(url.path, &status) == 0 { return true }
        guard errno == ENOENT else { throw Failure(.unreadable(file: url.lastPathComponent)) }
        return false
    }

    func state() -> StoreState {
        var status = stat()
        guard stat(directory.path, &status) == 0 else {
            return errno == ENOENT && !Self.passesThroughDanglingLink(directory.path) ? .absent : .unavailable(.cannotList)
        }
        return (status.st_mode & S_IFMT) == S_IFDIR ? .present : .unavailable(.notADirectory)
    }

    /// Whether `url` is a real directory, not a link to one; nil when nothing is there.
    static func isRealDirectory(_ url: URL) -> Bool? {
        var status = stat()
        guard lstat(url.path, &status) == 0 else { return errno == ENOENT ? nil : false }
        return (status.st_mode & S_IFMT) == S_IFDIR
    }

    /// The quarantine's entries. An absent quarantine is empty; one that is not a real directory is never used.
    func quarantineNames() throws(Failure) -> [String] {
        switch Self.isRealDirectory(quarantine) {
        case nil: return []
        case false?: throw Failure(.unavailable(.notADirectory))
        case true?:
            do { return try FileManager.default.contentsOfDirectory(atPath: quarantine.path) } catch { throw Failure(.unavailable(.cannotList)) }
        }
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

    /// Timestamps are stored with whole-second precision (ISO 8601), so they are normalised before use;
    /// otherwise a fractional clock would make every write fail its read-back check.
    func now() -> Date { Date(timeIntervalSince1970: clock.now().timeIntervalSince1970.rounded(.down)) }

    // MARK: Reading

    /// The stored value at `url`, or nil when nothing is there in a store that can be reached; otherwise a missing store
    /// would read as a deleted value.
    func current<Value>(_ url: URL, read: (URL) -> StoredFile<Value>) throws(Failure) -> Value? {
        let name = url.lastPathComponent
        switch read(url) {
        case .absent:
            if case .unavailable(let failure) = state() { throw Failure(.unavailable(failure)) }
            return nil
        case .value(let value): return value
        case .newer(let version): throw Failure(.upgradeRequired(file: name, version: version))
        case .corrupt(let reason): throw Failure(.corrupt(file: name, reason: reason))
        case .unreadable: throw Failure(.unreadable(file: name))
        case .tooLarge: throw Failure(.tooLarge(file: name))
        }
    }

    /// The files of the store that end in `suffix`, in name order.
    func entries(suffix: String) throws(Failure) -> [URL] {
        let files: [URL]
        do { files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) }
        catch { throw Failure(.unavailable(.cannotList)) }
        return files.filter { $0.lastPathComponent.hasSuffix(suffix) }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// Every stored value of the files that end in `suffix`, and every issue found: a corrupt file is quarantined, and a
    /// failed quarantine is reported while the listing goes on. Call it under the lock.
    func scan<Value>(suffix: String, read: (URL) -> StoredFile<Value>) throws(Failure) -> (values: [Value], issues: [StoreIssue]) {
        var values: [Value] = [], issues: [StoreIssue] = []
        for file in try entries(suffix: suffix) {
            let name = file.lastPathComponent
            switch read(file) {
            case .absent: continue                                   // removed since the directory was listed
            case .value(let value): values.append(value)
            case .newer(let version): issues.append(.upgradeRequired(file: name, version: version))
            case .unreadable: issues.append(.unreadable(file: name))
            case .tooLarge(let bytes): issues.append(.tooLarge(file: name, bytes: bytes))
            case .corrupt(let reason):
                issues.append(moveToQuarantine(file) != nil ? .corrupt(file: name, reason: reason) : .quarantineFailed(file: name))
            }
        }
        return (values, issues)
    }

    // MARK: Writing

    /// Writes only what the store will be able to read back: the encoded file must be within the size cap and must decode,
    /// through the same strict path as a read, to what was meant. Otherwise nothing is written and the previous version stays.
    func write(_ name: String, encoded: () throws -> Data, readsBack: (Data) throws -> Bool) throws(Failure) {
        let data: Data
        do { data = try encoded() } catch { throw Failure(.writeFailed(file: name)) }
        guard data.count <= maxFileBytes else { throw Failure(.wouldNotReadBack(file: name)) }
        let reads: Bool
        do { reads = try readsBack(data) } catch { throw Failure(.wouldNotReadBack(file: name)) }
        guard reads else { throw Failure(.wouldNotReadBack(file: name)) }
        do { try data.write(to: directory.appendingPathComponent(name), options: StoreWriting.options) } catch { throw Failure(.writeFailed(file: name)) }
    }

    // MARK: Quarantine

    /// Moves a corrupt file into the quarantine, which must be a real directory of the store, never a link. Returns where it
    /// went, or nil when it could not be moved.
    func moveToQuarantine(_ file: URL) -> URL? {
        do {
            try FileManager.default.createDirectory(at: quarantine, withIntermediateDirectories: true)
            guard Self.isRealDirectory(quarantine) == true else { return nil }
            // The retention period starts now: the file's own modification time says nothing about when it was isolated.
            try FileManager.default.setAttributes([.modificationDate: now()], ofItemAtPath: file.path)
            var target = quarantine.appendingPathComponent(file.lastPathComponent)
            var n = 1
            while FileManager.default.fileExists(atPath: target.path) {
                target = quarantine.appendingPathComponent("\(n)~" + file.lastPathComponent); n += 1   // "~" never occurs in a name
            }
            try FileManager.default.moveItem(at: file, to: target)
            return target
        } catch { return nil }
    }

    /// Brings a quarantined file back, only through the read checks. `pattern` is the whole name a quarantined file of this
    /// store may have, so the name cannot leave the quarantine folder. `taken` is the error for a stored file already under
    /// the original name, nil when the name carries no identity. A failed restore leaves both folders unchanged.
    func restore<Value>(quarantined name: String, pattern: String, taken: (_ original: String) -> Failure?,
                        read: (_ source: URL, _ original: String) -> StoredFile<Value>) throws(Failure) -> Value {
        guard name.range(of: "^(\\d+~)?" + pattern + "\\z", options: .regularExpression) != nil else { throw Failure(.invalidName(name)) }
        return try withLock { () throws(Failure) -> Value in
            if Self.isRealDirectory(quarantine) == false { throw Failure(.unavailable(.notADirectory)) }
            let source = quarantine.appendingPathComponent(name)
            let original = name.replacingOccurrences(of: #"^\d+~"#, with: "", options: .regularExpression)
            let target = directory.appendingPathComponent(original)
            guard source.deletingLastPathComponent().standardizedFileURL == quarantine.standardizedFileURL else { throw Failure(.invalidName(name)) }
            guard let alreadyThere = taken(original) else { throw Failure(.invalidName(name)) }
            guard !FileManager.default.fileExists(atPath: target.path) else { throw alreadyThere }
            let value: Value
            switch read(source, original) {
            case .value(let v): value = v
            case .absent: throw Failure(.unreadable(file: name))
            case .tooLarge: throw Failure(.tooLarge(file: name))
            case .unreadable: throw Failure(.unreadable(file: name))
            case .newer(let version): throw Failure(.upgradeRequired(file: name, version: version))
            case .corrupt(let reason): throw Failure(.corrupt(file: name, reason: reason))
            }
            do { try FileManager.default.moveItem(at: source, to: target) } catch { throw Failure(.writeFailed(file: original)) }
            return value
        }
    }

    /// Removes every copy of the file called `name`: the stored file whatever its schema, and its quarantined copies. The stored
    /// file goes first, and every copy that can be removed goes even when another cannot, or when the quarantine cannot be used.
    /// It fails with the first copy that it could not inspect or remove, rather than report every copy gone. Call it under the lock.
    func eraseCopies(of name: String) throws(Failure) {
        var failure: Failure?
        var victims = [directory.appendingPathComponent(name)]
        do throws(Failure) { victims += try quarantineNames().filter { $0 == name || $0.hasSuffix("~" + name) }.map { quarantine.appendingPathComponent($0) } }
        catch { failure = error }
        for victim in victims {
            do throws(Failure) {
                guard try exists(victim) else { continue }
                do { try FileManager.default.removeItem(at: victim) } catch { throw Failure(.writeFailed(file: victim.lastPathComponent)) }
            } catch { failure = failure ?? error }
        }
        if let failure { throw failure }
    }

    /// A file's age in the quarantine counts from when it entered it: quarantining stamps it with the clock.
    func purgeQuarantine(olderThan date: Date) throws(Failure) -> Int {
        try withLock { () throws(Failure) -> Int in
            var removed = 0
            for name in try quarantineNames() {
                let url = quarantine.appendingPathComponent(name)
                let modified: Date?
                do { modified = try FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date }
                catch { throw Failure(.unreadable(file: name)) }
                guard let modified, modified < date else { continue }
                do { try FileManager.default.removeItem(at: url); removed += 1 } catch { throw Failure(.writeFailed(file: name)) }
            }
            return removed
        }
    }
}
