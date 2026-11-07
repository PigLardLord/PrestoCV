import Foundation
import PrestoCVDomain
import PrestoCVApplication

/// The released app's store: `cv_<UUID>.json` files in one directory (ADR 0022). Only regular files up to a size cap are
/// read, never through a link; anything else is reported as unreadable and left where it is.
public struct DirectoryLegacyStore: LegacyStore {
    let directory: URL
    let clock: any TimeSource
    let maxFileBytes: Int

    public init(directory: URL, clock: any TimeSource, maxFileBytes: Int = 5 * 1024 * 1024) {
        self.directory = directory; self.clock = clock; self.maxFileBytes = maxFileBytes
    }

    public func records() async throws(RepositoryError) -> [LegacyRecord] {
        let names = try candidateNames()
        let fallback = Date(timeIntervalSince1970: clock.now().timeIntervalSince1970.rounded(.down))
        return names.map { LegacyRecord(fileName: $0, content: content(of: $0, fallback: fallback)) }
    }

    public func remove(_ fileName: String) async throws(RepositoryError) {
        guard Self.isCandidate(fileName) else { throw .invalidName(fileName) }
        let url = directory.appendingPathComponent(fileName)
        do { try FileManager.default.removeItem(at: url) }
        catch let error as CocoaError where error.code == .fileNoSuchFile { return }   // already gone: nothing to remove
        catch { throw .writeFailed(file: fileName, cause: FailureCause(error)) }
    }

    // MARK: Listing

    private static func isCandidate(_ name: String) -> Bool {
        name.hasPrefix("cv_") && name.hasSuffix(".json") && !name.contains("/")
    }

    /// A directory that is not there is an empty store: the person never had the released app.
    private func candidateNames() throws(RepositoryError) -> [String] {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory) else { return [] }
        guard isDirectory.boolValue else { throw .storeUnavailable(.cannotList) }
        do { return try FileManager.default.contentsOfDirectory(atPath: directory.path).filter(Self.isCandidate).sorted() }
        catch { throw .storeUnavailable(.cannotList) }
    }

    // MARK: Reading

    private func content(of name: String, fallback: Date) -> LegacyContent {
        guard let data = readBounded(directory.appendingPathComponent(name)) else { return .unreadable }
        return LegacyCVFile.read(data, fileName: name, fallback: fallback)
    }

    /// The bytes of a regular file within the cap, opened without following a link; nil for anything else.
    private func readBounded(_ url: URL) -> Data? {
        let fd = open(url.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard fd >= 0 else { return nil }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        var status = stat()
        guard fstat(fd, &status) == 0, (status.st_mode & S_IFMT) == S_IFREG, status.st_size <= maxFileBytes else { return nil }
        do { return try handle.read(upToCount: maxFileBytes + 1) } catch { return nil }
    }
}

extension FileCVRepository: LegacyImportTarget {
    /// Stores a legacy CV as revision 1 with the times it carried, unless the store already holds that id; under the
    /// store lock, so a run racing another process or the app cannot overwrite a CV. Returns what reads back.
    public func adopt(_ cv: CV) async throws(RepositoryError) -> Adoption {
        try withStoreLock { () throws(RepositoryError) -> Adoption in
            guard try current(cv.id) == nil else { return .existing }
            let adopted = cv.adoptedAsRevisionOne
            try write(adopted)
            return .stored(try current(cv.id) ?? adopted)
        }
    }
}
