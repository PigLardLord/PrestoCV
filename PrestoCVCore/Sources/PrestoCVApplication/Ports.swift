import Foundation
import PrestoCVDomain

// MARK: - Outbound ports (R3). Every method is atomic within the repository's serialisation boundary,
// across instances and processes (the file adapter locks the store). Repository operations are short,
// synchronous I/O and are not cancellable: they complete or fail.

public protocol CVRepository: Sendable {
    /// Stores a never-saved CV (revision 0) as revision 1. Fails with `alreadyExists`.
    func create(_ cv: CV) async throws(RepositoryError) -> CV
    /// Replaces the stored CV only if its revision equals `cv.revision`; returns it at revision + 1.
    func update(_ cv: CV) async throws(RepositoryError) -> CV
    func load(_ id: CVID) async throws(RepositoryError) -> CV
    /// Healthy CVs, most recently changed first, plus every issue found. Never fails because of one file.
    func list() async throws(RepositoryError) -> CVListing
    func delete(_ id: CVID, revision: Int) async throws(RepositoryError)
}

/// Recovery and erasure, reachable from the UI (quarantine review, "delete everything about this CV").
public protocol CVStoreMaintenance: Sendable {
    /// The files in the quarantine, oldest first. A file stays listed across restarts until it is restored, erased or purged.
    func quarantined() async throws(RepositoryError) -> [QuarantinedFile]
    func restore(quarantined name: String) async throws(RepositoryError) -> CV
    /// Removes every copy of a CV: the stored file whatever its schema, and quarantined copies (GDPR erasure).
    func erase(_ id: CVID) async throws(RepositoryError)
    /// Deletes quarantined files older than `date`. Returns how many were removed.
    func purgeQuarantine(olderThan date: Date) async throws(RepositoryError) -> Int
    /// Removes everything the store holds, in one hold of the store lock: every CV file whatever its schema or state, the
    /// quarantine, the staged copies and, unless `keepingLedger`, the import ledger. The ledger holds only the ids of the
    /// CVs the importer adopted, never content; while a legacy source is left, it must stay, or that source would be
    /// imported again. A ledger that is kept is named in `remaining`, so the outcome is partial and a second call, with
    /// `keepingLedger` false, finishes the job. A file that cannot be removed does not stop the others; it is reported in
    /// `remaining`, and a second call finishes the job. Only a store that cannot be reached throws.
    func eraseAll(keepingLedger: Bool) async throws(RepositoryError) -> EraseAllReport
}

/// A file in the quarantine, as the review screen shows it.
public struct QuarantinedFile: Sendable, Equatable {
    /// Why the store set a file aside. A code, never content.
    public enum Reason: Sendable, Equatable { case corrupt }

    /// What `restore(quarantined:)` takes.
    public let name: String
    /// The CV the file was named after when it was set aside.
    public let id: CVID
    /// When the file entered the quarantine: the retention period counts from here.
    public let enteredAt: Date
    public let reason: Reason
    public init(name: String, id: CVID, enteredAt: Date, reason: Reason = .corrupt) {
        self.name = name; self.id = id; self.enteredAt = enteredAt; self.reason = reason
    }

    /// The CV a quarantine name belongs to; nil unless the name is `[<n>~]<UUID>.cv.json` and nothing else.
    public static func id(inName name: String) -> CVID? {
        var rest = Substring(name)
        if let tilde = rest.firstIndex(of: "~") {
            let digits = rest[..<tilde]
            guard !digits.isEmpty, digits.allSatisfy({ $0 >= "0" && $0 <= "9" }) else { return nil }
            rest = rest[rest.index(after: tilde)...]
        }
        guard rest.hasSuffix(".cv.json") else { return nil }
        let text = rest.dropLast(".cv.json".count)
        // UUID(uuidString:) also takes lower case; the store writes upper case only, and so does a name it accepts.
        guard text.count == 36, text == text.uppercased(), let uuid = UUID(uuidString: String(text)) else { return nil }
        return CVID(uuid)
    }
}

/// What a file in the store is, for the person's list of what remains: never a path (R7).
public enum StoredFileKind: Sendable, Hashable {
    case cv, quarantined, staged, ledger, legacySource, other
}

/// A file that an erase could not remove: its kind and its name.
public struct RemainingItem: Sendable, Hashable {
    public let kind: StoredFileKind, name: String
    public init(kind: StoredFileKind, name: String) { self.kind = kind; self.name = name }
}

/// What `eraseAll` did: the files it removed and the ones that remain.
public struct EraseAllReport: Sendable, Equatable {
    public var erased: Int, remaining: [RemainingItem]
    public init(erased: Int, remaining: [RemainingItem] = []) { self.erased = erased; self.remaining = remaining }
}

public struct CVListing: Sendable, Equatable {
    public var cvs: [CV], issues: [StoreIssue]
    public init(cvs: [CV], issues: [StoreIssue]) { self.cvs = cvs; self.issues = issues }
}

public enum StoreIssue: Sendable, Equatable {
    case corrupt(file: String, reason: String)       // quarantined, restorable
    case upgradeRequired(file: String, version: Int) // left untouched
    case unreadable(file: String)                    // I/O failure or symlink: left untouched, retried next time
    case tooLarge(file: String, bytes: Int)          // left untouched, never read
    case quarantineFailed(file: String)              // corrupt, but could not be moved aside
}

public enum StoreFailure: Sendable, Equatable {
    case notADirectory, cannotList, cannotLock
    /// The store's lock was held elsewhere, by another instance or another process, until the wait's deadline.
    case lockTimeout
}

/// The error under a failed call, as codes only: its domain and its code, never a path or a message (R7).
public struct FailureCause: Sendable, Equatable, CustomStringConvertible {
    public enum Domain: Sendable, Equatable {
        /// `NSCocoaErrorDomain`: Foundation's own file errors, such as a write without permission.
        case cocoa
        /// `NSPOSIXErrorDomain`: the code is the `errno` value.
        case posix
        /// Any other domain, or a Swift error that has none.
        case other
    }

    public let domain: Domain, code: Int
    /// The `errno` under the error, when Foundation reports one. A Cocoa code covers several of them: `cocoa 513` is
    /// both a folder that cannot be written to (`posix 13`) and a file the device has locked, so only the pair tells
    /// them apart. Foundation on Apple platforms reports it; swift-corelibs-foundation on Linux does not.
    public let underlyingPOSIX: Int?
    public init(domain: Domain, code: Int, underlyingPOSIX: Int? = nil) {
        self.domain = domain; self.code = code; self.underlyingPOSIX = underlyingPOSIX
    }

    /// `posix 13`, or `cocoa 513 (posix 13)`: the form a failed test and a printed error show.
    public var description: String {
        underlyingPOSIX.map { "\(domain) \(code) (posix \($0))" } ?? "\(domain) \(code)"
    }
}

/// No paths or free-form strings: file names only, and coded failures (R7).
public enum RepositoryError: Error, Equatable, Sendable {
    case notFound(CVID), alreadyExists(CVID), conflict(CVID, storedRevision: Int)
    case corrupt(file: String), unreadable(file: String), upgradeRequired(file: String, version: Int), tooLarge(file: String)
    case invalidName(String), storeUnavailable(StoreFailure), writeFailed(file: String, cause: FailureCause)
    /// Refused before writing: the file would exceed the size cap, or would not read back (the previous version is kept).
    case wouldNotReadBack(file: String)
}

public protocol IDGenerator: Sendable { func next() -> CVID }
/// Named to avoid shadowing Swift.Clock.
public protocol TimeSource: Sendable { func now() -> Date }

/// The sample CVs offered on first run, in the stored format (docs/architecture/modules.md).
public protocol SampleCVSource: Sendable {
    func samples() async throws(RepositoryError) -> [CV]
}

/// Reads which language a text is written in (#407). The rule that decides the CV's language is
/// `DetectDocumentLanguage`; this port only reads.
public protocol TextLanguageReading: Sendable {
    /// What the reader finds in `text`: the language it finds on its own, and how likely each of `languages` is.
    func reading(of text: String, among languages: [DocumentLanguage]) -> LanguageReading
}

/// What a `TextLanguageReading` finds in a text.
public struct LanguageReading: Equatable, Sendable {
    /// The language the reader finds on its own, among every language it knows; nil when it finds none.
    public let dominant: DocumentLanguage?
    /// How likely each language it was given is, from 0 to 1. A language it gives no likelihood for is not likely.
    public let likelihoods: [DocumentLanguage: Double]
    public init(dominant: DocumentLanguage?, likelihoods: [DocumentLanguage: Double]) {
        self.dominant = dominant; self.likelihoods = likelihoods
    }
}
