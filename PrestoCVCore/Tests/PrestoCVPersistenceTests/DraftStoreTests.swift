import Testing
import Foundation
import PrestoCVDomain
import PrestoCVApplication
@testable import PrestoCVPersistence
import PrestoCVCoreTestSupport

/// A schema-1 file with one experience and two interests, and `draft` as its draft block.
private func fileWithDraft(_ draft: String, id: String = id1.raw.uuidString) -> String {
    fileJSON(id: id, sections: ["experiences": #"[{"role":"r","company":"c","location":"","description":"","current":false}]"#,
                                "interests": #"["Chess","Running"]"#],
             extra: #","draft":\#(draft)"#)
}

private let imported = #"{"kind":"imported"}"#

/// Draft blocks that must make the file corrupt, each with the reason it is quarantined with.
let corruptDrafts: [(draft: String, reason: String)] = [
    (#"{"version":0,"origins":[],"notPlaced":[{"text":"Chess"}]}"#, "draft version"),
    (#"{"version":1,"origins":[],"notPlaced":[]}"#, "draft empty"),
    (#"{"version":1,"origins":[{"field":"personal.age","origin":\#(imported)}],"notPlaced":[]}"#, "draft field"),
    (#"{"version":1,"origins":[{"field":"certifications.link","entry":0,"origin":\#(imported)}],"notPlaced":[]}"#, "draft field"),
    (#"{"version":1,"origins":[{"field":"personal.fullName","origin":{"kind":"cloud"}}],"notPlaced":[]}"#, "draft origin"),
    (#"{"version":1,"origins":[{"field":"personal.fullName","entry":0,"origin":\#(imported)}],"notPlaced":[]}"#, "draft place"),
    (#"{"version":1,"origins":[{"field":"experiences.role","origin":\#(imported)}],"notPlaced":[]}"#, "draft place"),
    (#"{"version":1,"origins":[{"field":"experiences.role","entry":1,"origin":\#(imported)}],"notPlaced":[]}"#, "draft place"),
    (#"{"version":1,"origins":[{"field":"interests","entry":-1,"origin":\#(imported)}],"notPlaced":[]}"#, "draft place"),
    (#"{"version":1,"origins":[{"field":"skills.name","entry":0,"origin":\#(imported)}],"notPlaced":[]}"#, "draft place"),
    (#"{"version":1,"origins":[{"field":"interests","entry":1,"origin":\#(imported)},{"field":"interests","entry":1,"origin":\#(imported)}],"notPlaced":[]}"#,
     "draft duplicate place"),
    (#"{"version":1,"origins":[],"notPlaced":[{"text":"One\r\ntwo"}]}"#, "draft not-placed text"),
    (#"{"version":1,"origins":[],"notPlaced":[{"text":" \n "}]}"#, "draft not-placed text"),
    (#"{"version":1,"origins":[],"notPlaced":[{"text":"Chess","heading":"Other\nnotes"}]}"#, "draft not-placed text"),
    (#"{"version":1,"origins":[],"notPlaced":[{"text":"Chess","heading":""}]}"#, "draft not-placed text"),
    (#"{"version":1,"origins":[],"notPlaced":[{"text":"\#(String(repeating: "x", count: 10_001))"}]}"#, "size limits"),
    (#"{"version":1,"origins":[],"notPlaced":[{"text":"Chess","heading":"\#(String(repeating: "x", count: 10_001))"}]}"#, "size limits"),
    (#"{"version":1,"origins":[],"notPlaced":[\#((0...500).map { #"{"text":"t\#($0)"}"# }.joined(separator: ","))]}"#, "size limits"),
]

@Suite("ADR 0009 · the draft block in the stored file")
struct DraftStoreTests {
    @Test("a schema-1 file written before the draft existed reads, and is written again byte for byte, with no draft key")
    func noDraftUnchanged() throws {
        let golden = #"{"certifications":[],"createdAt":"2024-01-01T00:00:00Z","education":[],"experiences":[],"#
            + #""id":"11111111-1111-1111-1111-111111111111","interests":["Chess"],"languages":[],"#
            + #""personal":{"fullName":"Ada","location":"","professionalTitle":"","summary":""},"profiles":[],"revision":1,"#
            + #""schemaVersion":1,"skills":[{"level":3,"name":"Swift"}],"title":"","updatedAt":"2024-01-01T00:00:00Z"}"#
        let cv = try decode(golden)
        let written = try CVFileV1(cv, createdAt: try #require(cv.createdAt), updatedAt: try #require(cv.updatedAt)).encoded()
        #expect(String(decoding: written, as: UTF8.self) == golden)
    }

    @Test("marks in every kind of place and a text without a heading survive a save and a load")
    func roundTrip() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        var cv = FixtureCV.full()
        let origins: [ValuePlace: ValueOrigin] = [.personal(.website): .imported, .entry(.interest, index: 1): .imported,
                                                  .entry(.profileLink, index: 0): .imported, .entry(.certificationIssued, index: 0): .imported]
        try cv.setDraft(DraftBlock(origins: origins, notPlaced: [try #require(NotPlacedText(text: "Plays the organ.", heading: nil))]))
        let saved = try await repo(dir).create(cv)
        #expect(try await repo(dir).load(saved.id).draft == cv.draft)
    }

    @Test("update keeps the draft: the repository rebuilds the CV it writes, and must not leave the draft behind")
    func updateKeepsTheDraft() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let r = repo(dir)
        var cv = try await r.create(FixtureCV.full())
        cv.rename("Renamed")
        let updated = try await r.update(cv)
        #expect(updated.draft == FixtureCV.full().draft)
        #expect(try await r.load(cv.id).draft == FixtureCV.full().draft)
    }

    @Test("every invalid value of a draft is corrupt, with its reason, never defaulted or normalised", arguments: corruptDrafts)
    func corruptDraft(draft: String, reason: String) {
        #expect(throws: CVFileV1.Invalid(reason: reason)) { try decode(fileWithDraft(draft)) }
    }

    @Test("a corrupt draft quarantines its file with the reason; a draft without its arrays or its version is corrupt too")
    func quarantined() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let third = CVID(UUID(uuidString: "33333333-3333-3333-3333-333333333333")!)
        let files: [(CVID, String)] = [
            (id1, fileWithDraft(#"{"version":1,"origins":[{"field":"skills.name","entry":0,"origin":\#(imported)}],"notPlaced":[]}"#, id: id1.raw.uuidString)),
            (id2, fileWithDraft(#"{"version":1,"origins":[]}"#, id: id2.raw.uuidString)),
            (third, fileWithDraft(#"{"origins":[],"notPlaced":[{"text":"Chess"}]}"#, id: third.raw.uuidString)),
        ]
        for (id, json) in files { try Data(json.utf8).write(to: dir.appendingPathComponent(fileName(id))) }
        let listing = try await repo(dir).list()
        #expect(listing.cvs.isEmpty)
        #expect(listing.issues == [.corrupt(file: fileName(id1), reason: "draft place"), .corrupt(file: fileName(id2), reason: "not a CV file"),
                                   .corrupt(file: fileName(third), reason: "no draft version envelope")])
        #expect(try FileManager.default.contentsOfDirectory(atPath: dir.appendingPathComponent("Quarantine").path).count == 3)
    }

    @Test("a newer draft version is upgradeRequired: listed, never decoded, the file the same after list, update and delete")
    func newerDraft() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let r = repo(dir)
        let name = fileName(id1), file = dir.appendingPathComponent(fileName(id1))
        let newer = fileJSON(extra: #","draft":{"version":2,"slots":5}"#)
        try Data(newer.utf8).write(to: file)
        #expect(try await r.list() == CVListing(cvs: [], issues: [.upgradeRequired(file: name, version: 2)]))
        let stored = named("A").stored(revision: 1, at: Date(timeIntervalSince1970: 0))
        await #expect(throws: RepositoryError.upgradeRequired(file: name, version: 2)) { _ = try await r.update(stored) }
        await #expect(throws: RepositoryError.upgradeRequired(file: name, version: 2)) { try await r.delete(id1, revision: 1) }
        await #expect(throws: RepositoryError.upgradeRequired(file: name, version: 2)) { _ = try await r.load(id1) }
        #expect(try String(contentsOf: file, encoding: .utf8) == newer)
    }

    @Test("erase and erase-everything reach a CV with a draft, whatever the draft's version")
    func erased() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let r = repo(dir)
        _ = try await r.create(FixtureCV.full())
        try await r.erase(id1)
        #expect(!FileManager.default.fileExists(atPath: dir.appendingPathComponent(fileName(id1)).path))
        try Data(fileJSON(extra: #","draft":{"version":2}"#).utf8).write(to: dir.appendingPathComponent(fileName(id1)))
        try await r.erase(id1)
        #expect(!FileManager.default.fileExists(atPath: dir.appendingPathComponent(fileName(id1)).path))
        _ = try await r.create(FixtureCV.full(id: id2))
        try Data(fileJSON(extra: #","draft":{"version":2}"#).utf8).write(to: dir.appendingPathComponent(fileName(id1)))
        let report = try await r.eraseAll(keepingLedger: false)
        #expect(report.remaining.isEmpty)
        #expect(try FileManager.default.contentsOfDirectory(atPath: dir.path).filter { $0.hasSuffix(".cv.json") }.isEmpty)
    }

    @Test("a key the supported draft version does not know is read past, and a rewrite drops it: a new field needs a new version")
    func unknownKeysDropped() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let draft = #"{"version":1,"origins":[{"field":"interests","entry":1,"origin":{"kind":"imported","fitted":true}}],"#
            + #""notPlaced":[],"slots":[{"kind":"employer"}]}"#
        try Data(fileWithDraft(draft + #","future":1"#).utf8).write(to: dir.appendingPathComponent(fileName(id1)))
        let r = repo(dir)
        var cv = try await r.load(id1)
        #expect(cv.draft == DraftBlock(origins: [.entry(.interest, index: 1): .imported], notPlaced: []))
        cv.rename("Renamed")
        _ = try await r.update(cv)
        let written = try String(contentsOf: dir.appendingPathComponent(fileName(id1)), encoding: .utf8)
        #expect(!written.contains("slots") && !written.contains("future") && !written.contains("fitted"))
        #expect(written.contains(#""draft":{"notPlaced":[],"origins":[{"entry":1,"field":"interests","origin":{"kind":"imported"}}],"version":1}"#))
    }

    @Test("the marks are written sorted by field and entry, so the same draft is always the same bytes")
    func sortedOrigins() throws {
        let cv = FixtureCV.full().stored(revision: 1, at: Date(timeIntervalSince1970: 0))
        let file = try CVFileV1.decode(try CVFileV1(cv, createdAt: try #require(cv.createdAt), updatedAt: try #require(cv.updatedAt)).encoded())
        let written = try #require(file.draft).origins.map { "\($0.field) \($0.entry.map(String.init) ?? "-")" }
        #expect(written == ["experiences.company 0", "experiences.role 0", "interests 1", "personal.email -", "personal.fullName -",
                            "personal.professionalTitle -", "personal.summary -", "skills.name 0", "skills.name 1"])
    }

    @Test("a draft too large to read back is refused, and the previous version stays")
    func oversizedDraft() async throws {
        let dir = tempDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let small = repo(dir, clock: SteppingClock(), maxFileBytes: 4096), roomy = repo(dir)
        let v1 = try await small.create(named("Ada"))
        func with(_ text: String) throws -> CV {
            var cv = v1
            try cv.setDraft(DraftBlock(origins: [:], notPlaced: [try #require(NotPlacedText(text: text, heading: nil))]))
            return cv
        }
        await #expect(throws: RepositoryError.wouldNotReadBack(file: fileName(id1))) { _ = try await small.update(try with(String(repeating: "𝒜", count: 2000))) }
        await #expect(throws: RepositoryError.wouldNotReadBack(file: fileName(id1))) { _ = try await roomy.update(try with(String(repeating: "x", count: 10_001))) }
        #expect(try await roomy.load(id1) == v1)
    }
}
