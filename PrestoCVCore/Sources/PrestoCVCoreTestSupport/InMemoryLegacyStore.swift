import Foundation
import PrestoCVDomain
import PrestoCVApplication

/// The released app's store in memory, for the tests of what reads the import's report: a file per CV and damaged files,
/// with the keys and the bytes only this package can make. A file whose removal was made to fail throws when removed.
public actor InMemoryLegacyStore: LegacyStore {
    private var files: [String: (content: LegacyContent, bytes: Data)] = [:]
    private var failing: Set<String> = []

    /// One file for each CV, and `damaged` files that are no CV.
    public init(_ cvs: [LegacyCV], damaged: Int = 0) {
        for cv in cvs { files[Self.name(of: cv.cv.id)] = (.cv(cv), Data(cv.cv.id.raw.uuidString.utf8)) }
        for number in 0..<damaged { files["damaged_\(number).json"] = (.invalid(.json), Data("\(number)".utf8)) }
    }

    /// The files the store holds, by name.
    public var names: [String] { files.keys.sorted() }

    /// The name of the CV's file.
    public static func name(of id: CVID) -> String { "cv_\(id.raw.uuidString).json" }

    /// The removal of the CV's file throws from now on.
    public func failRemoving(_ id: CVID) { failing.insert(Self.name(of: id)) }

    public func records() async throws(RepositoryError) -> [LegacyRecord] {
        files.keys.sorted().compactMap { name in
            files[name].map { LegacyRecord(key: .init(name: name), content: $0.content, version: .init(bytes: $0.bytes)) }
        }
    }

    public func remove(_ key: LegacyRecord.Key, ifUnchanged version: LegacyRecord.Version) async throws(RepositoryError) -> LegacyRemoval {
        guard let file = files[key.name] else { return .alreadyGone }
        if failing.contains(key.name) { throw .storeUnavailable(.cannotLock) }
        guard file.bytes == version.bytes else { return .changed }
        files[key.name] = nil
        return .removed
    }
}
