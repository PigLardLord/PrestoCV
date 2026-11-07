import Testing
import Foundation
import PrestoCVDomain
import PrestoCVApplication
@testable import PrestoCVPersistence
import PrestoCVCoreTestSupport

@Suite("R6 · stored CVs and the size limits")
struct StoredLimitsTests {
    private func write(_ json: String, in dir: URL, id: CVID = id1) throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data(json.utf8).write(to: dir.appendingPathComponent(fileName(id)))
    }

    @Test("an over-limit file reads and lists as a healthy CV, is never cut, and saving it is refused")
    func overLimitFile() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let long = String(repeating: "é", count: 9_000)          // 18,000 bytes: over the text limit, under the file's cap
        let skills = (0..<250).map { #"{"name":"s\#($0)"}"# }.joined(separator: ",")
        try write(fileJSON(personal: personal("summary", "\"\(long)\""), sections: ["skills": "[\(skills)]"]), in: dir)
        let r = repo(dir)
        let listing = try await r.list()
        #expect(listing.issues.isEmpty && listing.cvs.count == 1)
        let cv = try await r.load(id1)
        #expect(cv.personal.summary == long && cv.sections.skills.count == 250)
        #expect(cv.saveCheck() == .textTooLong(.summary))
        await #expect(throws: AuthoringError.textTooLong(.summary)) { _ = try await SaveCV(repository: r)(cv) }
    }

    @Test("the bundled samples are not altered by the rule, and each can be saved (#87)")
    func samplesUnchanged() async throws {
        let directory = bundledSamples()
        let names = try FileManager.default.contentsOfDirectory(atPath: directory.path).filter { $0.hasSuffix(".cv.json") }
        #expect(names.count == 5)
        func strings(_ value: Any) -> [String] {
            if let s = value as? String { return [s] }
            if let a = value as? [Any] { return a.flatMap(strings) }
            if let d = value as? [String: Any] { return d.values.flatMap(strings) }
            return []
        }
        for name in names {
            let json = try JSONSerialization.jsonObject(with: Data(contentsOf: directory.appendingPathComponent(name)))
            for s in strings(json) { #expect(TextRules.multiLine(s) == s, "\(name): \(s)") }
        }
        for cv in try await DirectorySampleCVSource(directory: directory).samples() { #expect(cv.saveCheck() == .ok, "\(cv.title)") }
    }
}
