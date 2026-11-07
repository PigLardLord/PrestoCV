import Foundation
import PrestoCVDomain

// MARK: - Maintenance of the store: what the quarantine screen and "erase everything" need (R7, R12)

/// What presentation needs to know about a failed maintenance call, without the port's error shape (R7).
public enum MaintenanceError: Error, Equatable, Sendable {
    /// The name is not one the quarantine can hold.
    case invalidName
    /// A CV with this id is stored: nothing was changed.
    case alreadyExists
    /// The file does not decode, or is not the CV its name says.
    case corrupt
    /// The file was written by a newer version of the app.
    case upgradeRequired
    /// The file is not there, or could not be read.
    case unreadable
    case tooLarge
    /// The store cannot be reached.
    case unavailable
    /// Any other failure: a write, a removal, a move.
    case failed

    init(_ error: RepositoryError) {
        switch error {
        case .invalidName: self = .invalidName
        case .alreadyExists: self = .alreadyExists
        case .corrupt: self = .corrupt
        case .upgradeRequired: self = .upgradeRequired
        case .unreadable: self = .unreadable
        case .tooLarge: self = .tooLarge
        case .storeUnavailable: self = .unavailable
        case .notFound, .conflict, .writeFailed, .wouldNotReadBack: self = .failed
        }
    }
}

/// How long a file stays in the quarantine before the purge removes it. A constant of the application (ADR 0009).
public enum QuarantineRetention {
    public static let days = 30
    /// The span in seconds: calendar days vary with the clock changes, and a file's age is a plain time span.
    public static var seconds: TimeInterval { TimeInterval(days) * 86_400 }
}

/// Everything the review screen shows about a store that is not in order, in one value.
public struct StoreReview: Sendable, Equatable {
    public let issues: [StoreIssue], quarantined: [QuarantinedFile]
    public init(issues: [StoreIssue], quarantined: [QuarantinedFile]) { self.issues = issues; self.quarantined = quarantined }
}

/// The listing's issues plus the quarantine. Listing comes first: it is what sets a corrupt file aside.
public struct ReviewStoreIssues: Sendable {
    let repository: any CVRepository, maintenance: any CVStoreMaintenance
    public init(repository: any CVRepository, maintenance: any CVStoreMaintenance) {
        self.repository = repository; self.maintenance = maintenance
    }
    public func callAsFunction() async throws(MaintenanceError) -> StoreReview {
        do {
            let listing = try await repository.list()
            return StoreReview(issues: listing.issues, quarantined: try await maintenance.quarantined())
        } catch { throw MaintenanceError(error) }
    }
}

/// Moves a quarantined file back into the store, if it is the CV its name says and no CV has its id.
public struct RestoreQuarantinedCV: Sendable {
    let maintenance: any CVStoreMaintenance
    public init(maintenance: any CVStoreMaintenance) { self.maintenance = maintenance }
    public func callAsFunction(quarantined name: String) async throws(MaintenanceError) -> CV {
        do { return try await maintenance.restore(quarantined: name) } catch { throw MaintenanceError(error) }
    }
}

/// Removes one CV with every copy of it: the stored file and the quarantined ones.
public struct EraseCV: Sendable {
    let maintenance: any CVStoreMaintenance
    public init(maintenance: any CVStoreMaintenance) { self.maintenance = maintenance }
    public func callAsFunction(_ id: CVID) async throws(MaintenanceError) {
        do { try await maintenance.erase(id) } catch { throw MaintenanceError(error) }
    }
}

/// Removes the files that entered the quarantine more than `QuarantineRetention.days` before now. Returns how many.
public struct PurgeExpiredQuarantine: Sendable {
    let maintenance: any CVStoreMaintenance, time: any TimeSource
    public init(maintenance: any CVStoreMaintenance, time: any TimeSource) { self.maintenance = maintenance; self.time = time }
    public func callAsFunction() async throws(MaintenanceError) -> Int {
        do { return try await maintenance.purgeQuarantine(olderThan: time.now().addingTimeInterval(-QuarantineRetention.seconds)) }
        catch { throw MaintenanceError(error) }
    }
}

public enum EraseEverythingOutcome: Sendable, Equatable {
    /// Everything is gone: the number of files removed.
    case erased(Int)
    /// Some files are gone and the ones in `remaining` are not. Running it again finishes the job.
    case partial(erased: Int, remaining: [RemainingItem])
}

/// Erases everything the app stores about the person today: every CV file whatever its schema or state, the quarantine, the
/// staged copies and the import ledger (under one hold of the store lock), and the legacy source files that the importer has
/// not removed. A file that cannot be removed does not stop the others; the outcome names what remains.
/// Applications and letter defaults have no store in the new stack. When one is built, it adds its own erase-all and joins here.
public struct EraseEverything: Sendable {
    let maintenance: any CVStoreMaintenance, legacy: any LegacyStore
    public init(maintenance: any CVStoreMaintenance, legacy: any LegacyStore) { self.maintenance = maintenance; self.legacy = legacy }

    public func callAsFunction() async throws(MaintenanceError) -> EraseEverythingOutcome {
        // The sources go first: with the ledger gone, a source left behind would be imported again.
        var erased = 0, remaining: [RemainingItem] = []
        var unlisted: RepositoryError?
        do throws(RepositoryError) { try await eraseSources(erased: &erased, remaining: &remaining) } catch { unlisted = error }
        do {
            let report = try await maintenance.eraseAll()
            erased += report.erased; remaining += report.remaining
        } catch { throw MaintenanceError(error) }
        if let unlisted { throw MaintenanceError(unlisted) }
        return remaining.isEmpty ? .erased(erased) : .partial(erased: erased, remaining: remaining)
    }

    /// Removes each source while it still holds the bytes this run read. A source that changed, or that could not be read
    /// or removed, stays and is named.
    private func eraseSources(erased: inout Int, remaining: inout [RemainingItem]) async throws(RepositoryError) {
        for record in try await legacy.records() {
            let left = RemainingItem(kind: .legacySource, name: record.key.name)
            guard let version = record.version else { remaining.append(left); continue }
            do throws(RepositoryError) {
                switch try await legacy.remove(record.key, ifUnchanged: version) {
                case .removed: erased += 1
                case .alreadyGone: break
                case .changed: remaining.append(left)
                }
            } catch { remaining.append(left) }
        }
    }
}
