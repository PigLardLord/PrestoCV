import Foundation
import PrestoCVDomain
import PrestoCVApplication

/// The sample CVs offered on first run, read from an injected directory: every `.cv.json` file, in file-name order,
/// in the stored format and through the store's own reader (PersistedSchema). The samples ship with the app, so one that cannot
/// be used is an error, never skipped. Starting from a sample gives it a fresh identity (`StartFromSample`), so the
/// identifiers inside the files only need to differ from each other.
public struct DirectorySampleCVSource: SampleCVSource {
    let directory: URL, maxFileBytes: Int

    public init(directory: URL, maxFileBytes: Int = 5 * 1024 * 1024) {
        self.directory = directory; self.maxFileBytes = maxFileBytes
    }

    public func samples() async throws(RepositoryError) -> [CV] {
        var samples: [CV] = []
        for name in try sampleFileNames() {
            let file = StoredCVFile.read(directory.appendingPathComponent(name), maxBytes: maxFileBytes)
            samples.append(try file.requireCV(named: name))
        }
        return samples
    }

    private func sampleFileNames() throws(RepositoryError) -> [String] {
        do {
            return try FileManager.default.contentsOfDirectory(atPath: directory.path).filter { $0.hasSuffix(StoredFileName.suffix) }.sorted()
        } catch {
            throw .storeUnavailable(.cannotList)
        }
    }
}
