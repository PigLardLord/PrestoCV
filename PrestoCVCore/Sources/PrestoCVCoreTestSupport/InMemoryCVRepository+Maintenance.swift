import Foundation
import PrestoCVDomain
import PrestoCVApplication

extension InMemoryCVRepository {
    // MARK: Test seams

    /// A stored file that does not decode. The next listing sets it aside, as the file store does.
    public func plantCorrupt(_ id: CVID) { corruptLive.insert(id) }

    /// A file in the quarantine: a CV that can be restored, or (nil) one that does not decode. Returns its quarantine name.
    public func plantQuarantined(_ id: CVID, cv: CV?, enteredAt: Date) -> String {
        enter(Held(id: id, cv: cv, enteredAt: enteredAt))
    }

    func enter(_ file: Held) -> String {
        let base = file.id.raw.uuidString + ".cv.json"
        var name = base, n = 1
        while held[name] != nil { name = "\(n)~" + base; n += 1 }
        held[name] = file
        return name
    }

    func quarantineCorruptLive() -> [StoreIssue] {
        let ids = corruptLive.sorted { $0.raw.uuidString < $1.raw.uuidString }
        corruptLive = []
        return ids.map { id in
            _ = enter(Held(id: id, cv: nil, enteredAt: clock.now()))
            return .corrupt(file: id.raw.uuidString + ".cv.json", reason: "does not decode")
        }
    }

    // MARK: CVStoreMaintenance

    public func quarantined() async throws(RepositoryError) -> [QuarantinedFile] {
        _ = quarantineCorruptLive()
        return held.compactMap { name, file in
            QuarantinedFile.id(inName: name).map { QuarantinedFile(name: name, id: $0, enteredAt: file.enteredAt) }
        }.sorted { ($0.enteredAt, $0.name) < ($1.enteredAt, $1.name) }
    }

    public func restore(quarantined name: String) async throws(RepositoryError) -> CV {
        guard let id = QuarantinedFile.id(inName: name) else { throw .invalidName(name) }
        guard store[id] == nil else { throw .alreadyExists(id) }
        guard let file = held[name] else { throw .unreadable(file: name) }
        guard let cv = file.cv else { throw .corrupt(file: name) }
        store[id] = cv
        held[name] = nil
        return cv
    }

    public func erase(_ id: CVID) async throws(RepositoryError) {
        store[id] = nil
        corruptLive.remove(id)
        for (name, file) in held where file.id == id { held[name] = nil }
    }

    public func purgeQuarantine(olderThan date: Date) async throws(RepositoryError) -> Int {
        let old = held.filter { $0.value.enteredAt < date }.map(\.key)
        for name in old { held[name] = nil }
        return old.count
    }

    public func eraseAll(keepingLedger: Bool) async throws(RepositoryError) -> EraseAllReport {
        eraseGeneration += 1
        let ledgerFiles = keepingLedger || adopted.isEmpty ? 0 : 1
        let count = store.count + corruptLive.count + held.count + ledgerFiles
        store = [:]; corruptLive = []; held = [:]
        guard keepingLedger else { adopted = []; return EraseAllReport(erased: count) }
        let kept = adopted.isEmpty ? [] : [RemainingItem(kind: .ledger, name: Self.ledgerName)]
        return EraseAllReport(erased: count, remaining: kept)
    }

    // MARK: Import ledger

    static let ledgerName = ".legacy-imported.json"
}
