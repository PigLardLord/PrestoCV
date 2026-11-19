import Foundation
import PrestoCVDomain

// MARK: - One-time import of the released legacy store (ADR 0022)

/// What the importer drops from a legacy CV because the domain does not accept it. Reported per CV, never silent.
public enum LegacyDrop: Sendable, Equatable, Hashable {
    case look, email, phone, website, skillLevel, certificationYear, certificationLink, profile, documentLanguage, period
}

/// A legacy CV as the domain sees it: revision 0 and the times the legacy file carried, plus what was dropped.
public struct LegacyCV: Sendable, Equatable {
    public let cv: CV
    public let drops: [LegacyDrop]
    public init(cv: CV, drops: [LegacyDrop]) { self.cv = cv; self.drops = drops }
}

/// Why a candidate file is not a legacy CV: it is not the JSON of one, it has no usable id, or its name is not its id's.
public enum LegacyInvalid: Sendable, Equatable, Hashable {
    case json, id, name
}

public enum LegacyContent: Sendable, Equatable {
    case cv(LegacyCV)
    /// Not a legacy CV file the importer can trust: the reason is a code, never content.
    case invalid(LegacyInvalid)
    case unreadable
}

public struct LegacyRecord: Sendable, Equatable {
    /// Names a record in its store. Opaque: only the store that listed it knows how it is kept.
    public struct Key: Sendable, Hashable {
        package let name: String
        package init(name: String) { self.name = name }
    }

    /// The exact bytes the store read for this record. Opaque: only the store that listed it can compare it with what is
    /// kept now. It is the bytes, never the decoded content, which can differ between two reads of the same file (a missing
    /// date is filled from the clock).
    public struct Version: Sendable, Hashable {
        package let bytes: Data
        package init(bytes: Data) { self.bytes = bytes }
    }

    /// A record as one run read it: the name and the bytes a later removal must still find.
    public struct Source: Sendable, Equatable {
        public let key: Key, version: Version
        public init(key: Key, version: Version) { self.key = key; self.version = version }
    }

    public let key: Key
    public let content: LegacyContent
    /// Nil for a record whose bytes could not be read: such a record is never removed.
    public let version: Version?
    public init(key: Key, content: LegacyContent, version: Version? = nil) { self.key = key; self.content = content; self.version = version }
}

/// What a conditional removal found.
public enum LegacyRemoval: Sendable, Equatable {
    /// The record held the bytes of the version, and is gone.
    case removed
    /// The record was not there any more: counts as removed.
    case alreadyGone
    /// The record holds other bytes (or is no longer a regular file within the cap): left where it is.
    case changed
}

public protocol LegacyStore: Sendable {
    /// Every candidate file of the legacy store. A store that is not there is empty.
    func records() async throws(RepositoryError) -> [LegacyRecord]
    /// Removes the record only while it still holds the bytes of `version`. A record that is gone is `.alreadyGone`, one that
    /// holds other bytes is left and `.changed`. Throws only for an I/O failure.
    func remove(_ key: LegacyRecord.Key, ifUnchanged version: LegacyRecord.Version) async throws(RepositoryError) -> LegacyRemoval
}

public enum Adoption: Sendable, Equatable {
    /// Stored as revision 1, with the times it carried, and read back from the store.
    case stored(CV)
    /// A CV with this id is already stored: left as it is.
    case existing
    /// The store was erased after the import began: nothing was written.
    case storeErased
}

/// Which erase of the store an import began after. An import holds the records it read; an erase that comes after it began
/// removes the CVs and the ledger, and nothing the import still holds may be stored after it.
public struct ImportTicket: Sendable, Equatable {
    public let generation: Int
    public init(generation: Int) { self.generation = generation }
}

public protocol LegacyImportTarget: Sendable {
    /// Taken before the import reads its records, so that no erase falls between the two unseen.
    func beginImport() async throws(RepositoryError) -> ImportTicket
    /// Stores a legacy CV once, unless the store was erased since `ticket` was taken: then nothing is written and the answer
    /// is `.storeErased`. The check and the write are one step under the store's lock, so an erase is either before both or
    /// after both.
    func adopt(_ cv: CV, under ticket: ImportTicket) async throws(RepositoryError) -> Adoption
}

public struct LegacyImportFailure: Sendable, Equatable {
    public enum Reason: Sendable, Equatable {
        case invalid(LegacyInvalid), unreadable, notStored(RepositoryError), didNotReadBack, sourceNotRemoved(RepositoryError)
        /// The source holds other bytes than the run read: it stays, and a later run reads it as it is.
        case sourceChanged
    }
    public let key: LegacyRecord.Key, reason: Reason
    public init(key: LegacyRecord.Key, reason: Reason) { self.key = key; self.reason = reason }
}

public struct LegacyImportReport: Sendable, Equatable {
    public var imported: [CVID] = [], alreadyStored: [CVID] = [], removedSources: [LegacyRecord.Key] = []
    /// What each CV lost in the mapping, for every CV this run finds stored (`imported` or `alreadyStored`): an earlier run
    /// may have stored it and stopped before its report.
    public var drops: [CVID: [LegacyDrop]] = [:]
    /// The source of each CV with drops. `run()` keeps it: the source is the durable record of the loss, so it goes only
    /// when the caller calls `acknowledgeLosses(of:)` after the person has seen what was lost. A run that stops before that
    /// leaves the source, and the next run reports the same drops again. Each entry holds the bytes the run read: the
    /// acknowledgement removes the source only while it still holds them.
    public var awaitingAcknowledgement: [CVID: LegacyRecord.Source] = [:]
    public var failures: [LegacyImportFailure] = []
    /// The store was erased while the run went on, and the run stopped: what it had stored went with the store, so the report
    /// holds nothing else. The next run reads whatever the erase left.
    public var storeErased = false
    public init() {}
}

/// What `acknowledgeLosses(of:)` did: the sources it removed (one already gone counts as removed) and the ones it could not
/// (a source that changed since the report stays, as `sourceChanged`).
public struct LegacyAcknowledgement: Sendable, Equatable {
    public var removedSources: [LegacyRecord.Key] = []
    public var failures: [LegacyImportFailure] = []
    public init() {}
}

/// What the import of the legacy store did at a launch. A run that could not list the legacy store, or begin the import,
/// imported nothing and left every legacy file: the next launch runs again.
public enum LegacyImportOutcome: Sendable, Equatable {
    case ran(LegacyImportReport)
    case failed(RepositoryError)
}

extension LegacyImportOutcome {
    /// The legacy CVs the new store holds after the run: those it stored and those an earlier run had.
    public var imported: Int {
        switch self {
        case .ran(let report): report.imported.count + report.alreadyStored.count
        case .failed: 0
        }
    }

    /// The legacy CVs the run left out of the new store, their files kept for the next launch; nil when the run stopped
    /// before it knew them all. A CV that was stored but whose file stayed is imported, not failed.
    public var failed: Int? {
        switch self {
        case .ran(let report) where report.storeErased: nil
        case .ran(let report): report.failures.filter(\.reason.leavesTheCVOut).count
        case .failed: nil
        }
    }
}

extension LegacyImportFailure.Reason {
    /// Whether the CV is missing from the new store, rather than stored with its legacy file left in place.
    var leavesTheCVOut: Bool {
        switch self {
        case .invalid, .unreadable, .notStored, .didNotReadBack: true
        case .sourceNotRemoved, .sourceChanged: false
        }
    }
}

public struct ImportLegacyStore: Sendable {
    let source: any LegacyStore, target: any LegacyImportTarget, removingVerifiedSources: Bool
    public init(source: any LegacyStore, target: any LegacyImportTarget, removingVerifiedSources: Bool = true) {
        self.source = source; self.target = target; self.removingVerifiedSources = removingVerifiedSources
    }

    /// Adopts every legacy CV the store holds. A source goes only once its copy is stored and reads back as what was mapped,
    /// only while it still holds the exact bytes the run read, and only if its CV lost nothing: the source of a CV with drops stays (`awaitingAcknowledgement`) until
    /// `acknowledgeLosses(of:)`. Whatever fails is reported and left where it was. Only a source that cannot be listed, or a
    /// store that cannot say which erase it is at, fails the run. An erase of the store after the run began stops it: nothing
    /// more is stored and no source goes, and the report says only `storeErased`.
    public func run() async throws(RepositoryError) -> LegacyImportReport {
        var report = LegacyImportReport()
        let ticket = try await target.beginImport()   // before the records are read: an erase after this point is seen
        for record in try await source.records() {
            guard await handle(record, under: ticket, into: &report) else {
                var erased = LegacyImportReport()
                erased.storeErased = true
                return erased
            }
        }
        return report
    }

    /// Removes the sources `run()` kept for their losses, once the caller says the person has seen them. Removes nothing
    /// when `removingVerifiedSources` is false. A source it cannot remove stays and is reported as `sourceNotRemoved`; one that
    /// no longer holds the bytes its report read stays and is reported as `sourceChanged`: the person saw the losses of the
    /// earlier file, not of this one, and the next run reports it again.
    public func acknowledgeLosses(of report: LegacyImportReport) async -> LegacyAcknowledgement {
        var done = LegacyAcknowledgement()
        guard removingVerifiedSources else { return done }
        for entry in report.awaitingAcknowledgement.values {
            do throws(RepositoryError) {
                switch try await source.remove(entry.key, ifUnchanged: entry.version) {
                case .removed, .alreadyGone: done.removedSources.append(entry.key)
                case .changed: done.failures.append(.init(key: entry.key, reason: .sourceChanged))
                }
            } catch {
                done.failures.append(.init(key: entry.key, reason: .sourceNotRemoved(error)))
            }
        }
        return done
    }

    /// Handles one record; false once the store was erased after the run began, and the run stops.
    private func handle(_ record: LegacyRecord, under ticket: ImportTicket, into report: inout LegacyImportReport) async -> Bool {
        switch record.content {
        case .invalid(let reason): report.failures.append(.init(key: record.key, reason: .invalid(reason)))
        case .unreadable: report.failures.append(.init(key: record.key, reason: .unreadable))
        case .cv(let legacy):
            guard let version = record.version else { report.failures.append(.init(key: record.key, reason: .unreadable)); return true }
            return await adopt(legacy, from: .init(key: record.key, version: version), under: ticket, into: &report)
        }
        return true
    }

    private func adopt(_ legacy: LegacyCV, from source: LegacyRecord.Source, under ticket: ImportTicket,
                       into report: inout LegacyImportReport) async -> Bool {
        let key = source.key
        let adoption: Adoption
        do throws(RepositoryError) { adoption = try await target.adopt(legacy.cv, under: ticket) } catch {
            report.failures.append(.init(key: key, reason: .notStored(error))); return true
        }
        switch adoption {
        case .storeErased: return false
        case .existing: report.alreadyStored.append(legacy.cv.id)
        case .stored(let copy) where copy == legacy.cv.adoptedAsRevisionOne: report.imported.append(legacy.cv.id)
        case .stored: report.failures.append(.init(key: key, reason: .didNotReadBack)); return true
        }
        // Reported for every CV found stored, also one an earlier run stored: that run may have stopped before its report.
        // The source of a CV with drops is the durable record of the loss, so it stays until `acknowledgeLosses(of:)`; a run
        // that stops before then reports the same drops again. A loss reported twice is the safe way to fail; never is not.
        if legacy.drops.isEmpty { await removeSource(source, into: &report); return true }
        report.drops[legacy.cv.id] = legacy.drops
        report.awaitingAcknowledgement[legacy.cv.id] = source
        return true
    }

    private func removeSource(_ entry: LegacyRecord.Source, into report: inout LegacyImportReport) async {
        guard removingVerifiedSources else { return }
        do throws(RepositoryError) {
            switch try await source.remove(entry.key, ifUnchanged: entry.version) {
            case .removed, .alreadyGone: report.removedSources.append(entry.key)
            case .changed: report.failures.append(.init(key: entry.key, reason: .sourceChanged))
            }
        } catch {
            report.failures.append(.init(key: entry.key, reason: .sourceNotRemoved(error)))
        }
    }
}

extension CV {
    /// What a store holds after adopting this CV: revision 1, with the times it carries.
    package var adoptedAsRevisionOne: CV {
        CV(id: id, revision: 1, createdAt: createdAt, updatedAt: updatedAt, title: title, personal: personal,
           sections: sections, design: design, language: language)
    }
}
