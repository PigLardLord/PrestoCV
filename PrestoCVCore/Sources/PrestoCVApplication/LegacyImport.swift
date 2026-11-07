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

    public let key: Key
    public let content: LegacyContent
    public init(key: Key, content: LegacyContent) { self.key = key; self.content = content }
}

public protocol LegacyStore: Sendable {
    /// Every candidate file of the legacy store. A store that is not there is empty.
    func records() async throws(RepositoryError) -> [LegacyRecord]
    func remove(_ key: LegacyRecord.Key) async throws(RepositoryError)
}

public enum Adoption: Sendable, Equatable {
    /// Stored as revision 1, with the times it carried, and read back from the store.
    case stored(CV)
    /// A CV with this id is already stored: left as it is.
    case existing
}

public protocol LegacyImportTarget: Sendable {
    func adopt(_ cv: CV) async throws(RepositoryError) -> Adoption
}

public struct LegacyImportFailure: Sendable, Equatable {
    public enum Reason: Sendable, Equatable {
        case invalid(LegacyInvalid), unreadable, notStored(RepositoryError), didNotReadBack, sourceNotRemoved(RepositoryError)
    }
    public let key: LegacyRecord.Key, reason: Reason
    public init(key: LegacyRecord.Key, reason: Reason) { self.key = key; self.reason = reason }
}

public struct LegacyImportReport: Sendable, Equatable {
    public var imported: [CVID] = [], alreadyStored: [CVID] = [], removedSources: [LegacyRecord.Key] = []
    public var drops: [CVID: [LegacyDrop]] = [:]
    public var failures: [LegacyImportFailure] = []
    public init() {}
}

public struct ImportLegacyStore: Sendable {
    let source: any LegacyStore, target: any LegacyImportTarget, removingVerifiedSources: Bool
    public init(source: any LegacyStore, target: any LegacyImportTarget, removingVerifiedSources: Bool = true) {
        self.source = source; self.target = target; self.removingVerifiedSources = removingVerifiedSources
    }

    /// Adopts every legacy CV the store holds. A source goes only once its copy is stored and reads back as what was mapped;
    /// whatever fails is reported and left where it was. Only a source that cannot be listed fails the run.
    public func run() async throws(RepositoryError) -> LegacyImportReport {
        var report = LegacyImportReport()
        for record in try await source.records() { await handle(record, into: &report) }
        return report
    }

    private func handle(_ record: LegacyRecord, into report: inout LegacyImportReport) async {
        switch record.content {
        case .invalid(let reason): report.failures.append(.init(key: record.key, reason: .invalid(reason)))
        case .unreadable: report.failures.append(.init(key: record.key, reason: .unreadable))
        case .cv(let legacy): await adopt(legacy, from: record.key, into: &report)
        }
    }

    private func adopt(_ legacy: LegacyCV, from key: LegacyRecord.Key, into report: inout LegacyImportReport) async {
        let adoption: Adoption
        do throws(RepositoryError) { adoption = try await target.adopt(legacy.cv) } catch {
            report.failures.append(.init(key: key, reason: .notStored(error))); return
        }
        switch adoption {
        case .existing: report.alreadyStored.append(legacy.cv.id)
        case .stored(let copy) where copy == legacy.cv.adoptedAsRevisionOne:
            report.imported.append(legacy.cv.id)
            if !legacy.drops.isEmpty { report.drops[legacy.cv.id] = legacy.drops }
        case .stored: report.failures.append(.init(key: key, reason: .didNotReadBack)); return
        }
        await removeSource(key, into: &report)
    }

    private func removeSource(_ key: LegacyRecord.Key, into report: inout LegacyImportReport) async {
        guard removingVerifiedSources else { return }
        do throws(RepositoryError) { try await source.remove(key); report.removedSources.append(key) } catch {
            report.failures.append(.init(key: key, reason: .sourceNotRemoved(error)))
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
