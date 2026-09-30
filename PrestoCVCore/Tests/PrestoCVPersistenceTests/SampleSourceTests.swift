import Testing
import Foundation
import PrestoCVDomain
import PrestoCVApplication
@testable import PrestoCVPersistence
import PrestoCVCoreTestSupport

/// The samples the app ships, read from the repository: this file is PrestoCVCore/Tests/PrestoCVPersistenceTests/….
func bundledSamples() -> URL {
    var root = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { root.deleteLastPathComponent() }
    return root.appendingPathComponent("PrestoCV/Resources/Samples", isDirectory: true)
}

@Suite("DirectorySampleCVSource (#87)")
struct SampleSourceTests {
    @Test("the bundled samples decode through the store's strict decoder, each with the content a first run shows")
    func bundled() async throws {
        let samples = try await DirectorySampleCVSource(directory: bundledSamples()).samples()
        #expect(samples.count == 5)
        #expect(Set(samples.map(\.id)).count == 5)
        for cv in samples {
            #expect(cv.canBeSaved && !cv.title.isEmpty, "\(cv.title)")
            #expect(!cv.sections.experiences.isEmpty && !cv.sections.education.isEmpty && !cv.sections.skills.isEmpty, "\(cv.title)")
            #expect(cv.language?.tag == "en" && cv.personal.email != nil, "\(cv.title)")
        }
    }

    @Test("a sample started on first run is saved into the store like any new CV")
    func startAndSave() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let use = StartFromSample(samples: DirectorySampleCVSource(directory: bundledSamples()), ids: SequentialIDGenerator())
        let sample = try #require(try await use.available().first)
        let started = use(sample)
        let saved = try await SaveCV(repository: repo(dir))(started)
        #expect(saved.revision == 1 && saved.id != sample.id && saved.sections == sample.sections)
        #expect(try await repo(dir).load(saved.id) == saved)
    }

    @Test("only .cv.json files are samples, in file-name order")
    func order() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data(fileJSON(id: id2.raw.uuidString).utf8).write(to: dir.appendingPathComponent("b.cv.json"))
        try Data(fileJSON(id: id1.raw.uuidString).utf8).write(to: dir.appendingPathComponent("a.cv.json"))
        try Data("notes".utf8).write(to: dir.appendingPathComponent("README.txt"))
        #expect(try await DirectorySampleCVSource(directory: dir).samples().map(\.id) == [id1, id2])
    }

    @Test("a sample that cannot be used is an error, never skipped: the samples ship with the app")
    func broken() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data(fileJSON().utf8).write(to: dir.appendingPathComponent("a.cv.json"))
        try Data("{".utf8).write(to: dir.appendingPathComponent("b.cv.json"))
        await #expect(throws: RepositoryError.corrupt(file: "b.cv.json")) { _ = try await DirectorySampleCVSource(directory: dir).samples() }
        try Data(fileJSON(version: 2).utf8).write(to: dir.appendingPathComponent("b.cv.json"))
        await #expect(throws: RepositoryError.upgradeRequired(file: "b.cv.json", version: 2)) { _ = try await DirectorySampleCVSource(directory: dir).samples() }
        await #expect(throws: RepositoryError.storeUnavailable(.cannotList)) {
            _ = try await DirectorySampleCVSource(directory: dir.appendingPathComponent("missing")).samples()
        }
    }
}
