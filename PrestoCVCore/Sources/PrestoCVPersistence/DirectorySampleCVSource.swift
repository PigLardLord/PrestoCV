import Foundation
import PrestoCVDomain
import PrestoCVApplication

/// The sample CVs offered on first run, read from an injected directory: every `.cv.json` file, in file-name order,
/// in the stored format and through the store's own reader (R12). The samples ship with the app, so one that cannot
/// be used is an error, never skipped. Starting from a sample gives it a fresh identity (`StartFromSample`), so the
/// identifiers inside the files only need to differ from each other.
public struct DirectorySampleCVSource: SampleCVSource {
    let directory: URL, maxFileBytes: Int

    public init(directory: URL, maxFileBytes: Int = 5 * 1024 * 1024) {
        self.directory = directory; self.maxFileBytes = maxFileBytes
    }

    public func samples() async throws(RepositoryError) -> [CV] {
        let names: [String]
        do { names = try FileManager.default.contentsOfDirectory(atPath: directory.path) } catch { throw .storeUnavailable(.cannotList) }
        var samples: [CV] = []
        for name in names.sorted() where name.hasSuffix(".cv.json") {
            switch StoredFile<CV>.read(directory.appendingPathComponent(name), maxBytes: maxFileBytes, supportedVersion: CVFileV1.version,
                                       decode: CVFileV1.read) {
            case .value(let cv): samples.append(cv)
            case .absent, .unreadable: throw .unreadable(file: name)
            case .newer(let version): throw .upgradeRequired(file: name, version: version)
            case .corrupt: throw .corrupt(file: name)
            case .tooLarge: throw .tooLarge(file: name)
            }
        }
        return samples
    }
}
