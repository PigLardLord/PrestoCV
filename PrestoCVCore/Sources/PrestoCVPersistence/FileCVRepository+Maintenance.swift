import Foundation
import PrestoCVDomain
import PrestoCVApplication

extension FileCVRepository {
    /// The quarantine's files, oldest first, named as `restore(quarantined:)` takes them. The date is the one stamped on entry.
    /// A file whose name is none a quarantine makes (put there by hand) is not listed: it cannot be restored, and the purge
    /// removes it when it is old.
    public func quarantined() async throws(RepositoryError) -> [QuarantinedFile] {
        switch storeState() {
        case .absent: return []
        case .unavailable(let failure): throw .storeUnavailable(failure)
        case .present: break
        }
        return try withStoreLock { () throws(RepositoryError) -> [QuarantinedFile] in
            var files: [QuarantinedFile] = []
            for name in try quarantineNames() {
                guard let id = QuarantinedFile.id(inName: name) else { continue }
                let modified: Date?
                do { modified = try FileManager.default.attributesOfItem(atPath: quarantine.appendingPathComponent(name).path)[.modificationDate] as? Date }
                catch { throw .unreadable(file: name) }
                guard let modified else { throw .unreadable(file: name) }
                files.append(QuarantinedFile(name: name, id: id, enteredAt: modified))
            }
            return files.sorted { ($0.enteredAt, $0.name) < ($1.enteredAt, $1.name) }
        }
    }

    /// Removes everything in the store but its lock file and its erase generation, in one hold of the lock. The generation
    /// moves first, so an import that began before the erase stores nothing after it; if it cannot move, nothing is removed.
    /// One file that cannot be removed does not keep the others: it is named in the report, and the next call finishes. With
    /// `keepingLedger` the import ledger stays and is named in the report (if it exists), so the erase is partial until a
    /// call without it. A store that was never created is created to hold the generation (an import may have begun before
    /// it existed) and reports nothing erased.
    public func eraseAll(keepingLedger: Bool) async throws(RepositoryError) -> EraseAllReport {
        if case .unavailable(let failure) = storeState() { throw .storeUnavailable(failure) }
        return try withStoreLock { () throws(RepositoryError) -> EraseAllReport in
            try bumpEraseGeneration()
            var report = EraseAllReport(erased: 0)
            let names: [String]
            do { names = try FileManager.default.contentsOfDirectory(atPath: directory.path) } catch { throw .storeUnavailable(.cannotList) }
            for name in names.sorted() where name != ".lock" && name != Self.eraseGenerationName {
                if keepingLedger, name == Self.legacyLedgerName {
                    report.remaining.append(RemainingItem(kind: .ledger, name: name))
                } else if name == "Quarantine", Self.isRealDirectory(quarantine) == true { eraseQuarantine(into: &report) }
                else { remove(directory.appendingPathComponent(name), kind: Self.kind(ofStoreEntry: name), into: &report) }
            }
            return report
        }
    }

    /// The files of the quarantine, then the folder once it is empty. A link or a file where the folder should be is removed
    /// as itself (the target of a link is never touched).
    private func eraseQuarantine(into report: inout EraseAllReport) {
        let names: [String]
        do { names = try FileManager.default.contentsOfDirectory(atPath: quarantine.path) }
        catch { report.remaining.append(RemainingItem(kind: .quarantined, name: quarantine.lastPathComponent)); return }
        for name in names.sorted() { remove(quarantine.appendingPathComponent(name), kind: .quarantined, into: &report) }
        guard report.remaining.allSatisfy({ $0.kind != .quarantined }) else { return }   // a folder that still holds files stays
        var folder = EraseAllReport(erased: 0)
        remove(quarantine, kind: .quarantined, into: &folder)
        report.remaining += folder.remaining
    }

    /// Removes one entry (a link as a link) and counts it, or names it in the report.
    private func remove(_ url: URL, kind: StoredFileKind, into report: inout EraseAllReport) {
        do { try FileManager.default.removeItem(at: url); report.erased += 1 }
        catch let error as CocoaError where error.code == .fileNoSuchFile { return }   // another process removed it first
        catch { report.remaining.append(RemainingItem(kind: kind, name: url.lastPathComponent)) }
    }

    private static func kind(ofStoreEntry name: String) -> StoredFileKind {
        if name.hasSuffix(suffix) { return .cv }
        if name.hasSuffix(stagedSuffix) { return .staged }
        if name == legacyLedgerName { return .ledger }
        return name == "Quarantine" ? .quarantined : .other
    }
}
