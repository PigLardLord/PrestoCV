import Testing
import Foundation
import PrestoCVDomain
import PrestoCVApplication
import PrestoCVCoreTestSupport
@testable import PrestoCVPersistence

/// One entry of each section, with `@` where its index goes, so that every entry of a list is its own.
private let sectionItems: [(key: String, item: String)] = [
    ("experiences", #"{"role":"r","company":"c","location":"","description":"","current":false}"#),
    ("education", #"{"degree":"d","school":"s","description":"","current":false}"#),
    ("skills", #"{"name":"x"}"#),
    ("languages", #"{"language":"Italian","proficiency":"native"}"#),
    ("certifications", #"{"name":"n","issuer":"i","description":""}"#),
    ("profiles", #"{"platform":"GitHub","link":"https://github.com/ada"}"#),
    ("interests", "\"i@\""),
]

@Suite("PersistedSchema · size caps")
struct StoreLimitsTests {
    @Test("a text of exactly 10,000 characters is accepted, and one more is corrupt")
    func textCap() throws {
        let atCap = String(repeating: "x", count: 10_000)
        #expect(try decode(fileJSON(personal: personal("summary", "\"" + atCap + "\""))).personal.summary == atCap)
        #expect(throws: CVFileV1.Invalid(reason: "size limits")) { try decode(fileJSON(personal: personal("summary", "\"" + atCap + "x\""))) }
    }

    @Test("a list of exactly 500 entries is accepted, and one more is corrupt", arguments: sectionItems)
    func listCap(key: String, item: String) throws {
        func list(_ count: Int) -> String { "[" + (0..<count).map { item.replacingOccurrences(of: "@", with: String($0)) }.joined(separator: ",") + "]" }
        _ = try decode(fileJSON(sections: [key: list(500)]))
        #expect(throws: CVFileV1.Invalid(reason: "size limits")) { try decode(fileJSON(sections: [key: list(501)])) }
    }

    @Test("a file of exactly the size cap is read, and one byte more is reported without being read")
    func fileCapOnRead() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let json = Data(fileJSON().utf8)
        try json.write(to: dir.appendingPathComponent(fileName(id1)))
        let atCap = FileCVRepository(directory: dir, clock: SteppingClock(), maxFileBytes: json.count)
        #expect(try await atCap.list().cvs.map(\.id) == [id1])
        let below = FileCVRepository(directory: dir, clock: SteppingClock(), maxFileBytes: json.count - 1)
        #expect(try await below.list().issues == [.tooLarge(file: fileName(id1), bytes: json.count)])
    }

    @Test("a CV whose file is exactly the size cap is written, and one byte more is refused")
    func fileCapOnWrite() async throws {
        let probe = tempDir(); defer { try? FileManager.default.removeItem(at: probe) }
        _ = try await repo(probe).create(named("Ada"))
        let size = try Data(contentsOf: probe.appendingPathComponent(fileName(id1))).count
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let atCap = FileCVRepository(directory: dir, clock: SteppingClock(), maxFileBytes: size)
        #expect(try await atCap.create(named("Ada")).id == id1)
        let below = FileCVRepository(directory: tempDir(), clock: SteppingClock(), maxFileBytes: size - 1)
        await #expect(throws: RepositoryError.wouldNotReadBack(file: fileName(id1))) { _ = try await below.create(named("Ada")) }
    }
}
