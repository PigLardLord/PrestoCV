import Testing
import Foundation
import PrestoCVDomain
import PrestoCVApplication
@testable import PrestoCVPersistence
import PrestoCVCoreTestSupport

/// Text that enters a CV through a stored file meets the same rule as typed text (R8): the reader builds the CV
/// through the domain's initialisers, so a file cannot bring hidden characters back, and does not become corrupt for them.
@Suite("R8 · stored text and the text rule")
struct StoredTextRulesTests {
    private func write(_ json: String, in dir: URL, id: CVID = id1) throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data(json.utf8).write(to: dir.appendingPathComponent(fileName(id)))
    }

    @Test("a file with U+202E in the name reads clean and is not quarantined")
    func overrideInName() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        try write(fileJSON(personal: personal("fullName", #""Ada‮Lovelace""#)), in: dir)
        let listing = try await repo(dir).list()
        #expect(listing.issues.isEmpty)
        #expect(listing.cvs.map(\.personal.fullName) == ["AdaLovelace"])
    }

    @Test("a file with a tab in a description reads with a space; CR and CRLF read as LF")
    func tabAndCarriageReturn() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let experience = #"[{"role":"r\tx","company":"c","location":"","description":"a\tb\r\nc\rd","current":false}]"#
        try write(fileJSON(personal: personal("summary", #""x\r\ny""#), sections: ["experiences": experience]), in: dir)
        let cv = try await repo(dir).load(id1)
        #expect(cv.sections.experiences.first?.description == "a b\nc\nd")
        #expect(cv.sections.experiences.first?.role == "r x")
        #expect(cv.personal.summary == "x\ny")
    }

    @Test("an interest with a tab reads clean and is not corrupt")
    func interestWithTab() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        try write(fileJSON(sections: ["interests": #"["chess\tclub", "‮go"]"#]), in: dir)
        #expect(try await repo(dir).load(id1).sections.interests == ["chess club", "go"])
    }

    @Test("a cleaned CV saves and reads back the same: the read-back comparison holds")
    func roundTrip() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        try write(fileJSON(personal: personal("summary", #""a\tb‮""#)), in: dir)
        let r = repo(dir)
        let read = try await r.load(id1)
        let saved = try await SaveCV(repository: r)(read)
        #expect(saved.personal.summary == "a b")
        #expect(try await r.load(id1) == saved)
    }

    // MARK: Interests the text rule cleans, merges or drops

    @Test("interests the text rule cleans, merges or drops read healthy, save, and reload stable",
          arguments: [(#"["go", "‮go"]"#, ["go"]), (#"["‮"]"#, [String]()), (#"["‮ chess"]"#, ["chess"])])
    func interestsTheRuleChanges(stored: String, cleaned: [String]) async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        try write(fileJSON(sections: ["interests": stored]), in: dir)
        let r = repo(dir)
        let listing = try await r.list()
        #expect(listing.issues.isEmpty)
        #expect(listing.cvs.first?.sections.interests == cleaned)
        #expect(!FileManager.default.fileExists(atPath: dir.appendingPathComponent("Quarantine").path))
        let read = try await r.load(id1)
        #expect(read.sections.interests == cleaned)
        let saved = try await SaveCV(repository: r)(read)
        #expect(saved.sections.interests == cleaned)
        let reloaded = try await r.load(id1)
        #expect(reloaded == saved)
        let again = try await SaveCV(repository: r)(reloaded)
        #expect(try await r.load(id1) == again)
        #expect(again.sections.interests == cleaned)
        #expect(try await r.list().issues.isEmpty)
    }

    @Test("interests that break the stored rule without the text rule are still corrupt",
          arguments: [#"[" go"]"#, #"["go", "Go"]"#, #"[""]"#, #"["go", "go"]"#])
    func interestsBreakingTheStoredRule(stored: String) async throws {
        #expect(throws: (any Error).self) { try decode(fileJSON(sections: ["interests": stored])) }
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        try write(fileJSON(sections: ["interests": stored]), in: dir)
        let listing = try await repo(dir).list()
        #expect(listing.cvs.isEmpty)
        #expect(listing.issues.count == 1)
    }
}
