import Testing
import Foundation
import PrestoCVApplication
import PrestoCVDomain

/// A stored CV as the tests keep it: its title, the language of its PDF, its look, and the rest of it.
private struct Record: Equatable, Sendable {
    var id: UUID, title: String, language: String?, look: DesignChoice? = nil, content: String
}

private struct StoreFailed: Error, Equatable {}

/// The stored CVs, in memory. Another window can change a stored CV meanwhile (`changeElsewhere`).
private actor InMemoryStoredCVs: StoredCVs {
    private(set) var stored: [UUID: Record]
    private(set) var updates: [Record] = []
    var failsLoading = false, failsUpdating = false

    init(_ records: [Record]) { stored = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) }) }

    func load(_ id: UUID) async throws -> Record? {
        if failsLoading { throw StoreFailed() }
        return stored[id]
    }

    func update(_ cv: Record) async throws -> Record {
        if failsUpdating { throw StoreFailed() }
        updates.append(cv); stored[cv.id] = cv
        return cv
    }

    nonisolated func renaming(_ cv: Record, to title: String) -> Record { var cv = cv; cv.title = title; return cv }
    nonisolated func settingDocumentLanguage(of cv: Record, to tag: String?) -> Record { var cv = cv; cv.language = tag; return cv }
    nonisolated func settingLook(of cv: Record, to look: DesignChoice) -> Record { var cv = cv; cv.look = look; return cv }

    func changeElsewhere(_ id: UUID, content: String) { stored[id]?.content = content }
    func failLoading() { failsLoading = true }
    func failUpdating() { failsUpdating = true }
}

private let cvID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
private let original = Record(id: cvID, title: "iOS roles", language: "it", content: "as first saved")
private let modernLook = DesignChoice(design: "modern", palette: "creative", fonts: "serif")!
private let minimalLook = DesignChoice(design: "minimal", palette: "minimal", fonts: "classic")!

@Suite("Changing one field of a stored CV")
struct ChangeStoredCVTests {
    @Test("a rename trims the title, and reads the CV again so that nothing else changes")
    func rename() async throws {
        let store = InMemoryStoredCVs([original])
        await store.changeElsewhere(cvID, content: "saved since in another window")
        let renamed = try await ChangeStoredCV(cvs: store).rename(cvID, to: "  Backend roles \n")
        let expected = Record(id: cvID, title: "Backend roles", language: "it", content: "saved since in another window")
        #expect(renamed == expected)
        #expect(await store.updates == [expected])
    }

    @Test("a blank title changes nothing", arguments: ["", "   ", "\n\t"])
    func blankTitle(title: String) async throws {
        let store = InMemoryStoredCVs([original])
        #expect(try await ChangeStoredCV(cvs: store).rename(cvID, to: title) == nil)
        #expect(await store.updates.isEmpty)
    }

    @Test("the language of the PDF is set on the CV as stored now; nil is automatic", arguments: ["pt-BR", nil] as [String?])
    func documentLanguage(tag: String?) async throws {
        let store = InMemoryStoredCVs([original])
        await store.changeElsewhere(cvID, content: "saved since in another window")
        let changed = try await ChangeStoredCV(cvs: store).setDocumentLanguage(tag, of: cvID)
        let expected = Record(id: cvID, title: "iOS roles", language: tag, content: "saved since in another window")
        #expect(changed == expected)
        #expect(await store.updates == [expected])
    }

    @Test("the look is set on the CV as stored now, and nothing else changes")
    func look() async throws {
        let store = InMemoryStoredCVs([original])
        await store.changeElsewhere(cvID, content: "saved since in another window")
        let changed = try await ChangeStoredCV(cvs: store).setLook(modernLook, of: cvID)
        let expected = Record(id: cvID, title: "iOS roles", language: "it", look: modernLook, content: "saved since in another window")
        #expect(changed == expected)
        #expect(await store.updates == [expected])
    }

    @Test("a look replaces the look the CV had")
    func lookReplacesTheLook() async throws {
        let store = InMemoryStoredCVs([Record(id: cvID, title: "iOS roles", language: "it", look: modernLook, content: "as saved")])
        let changed = try await ChangeStoredCV(cvs: store).setLook(minimalLook, of: cvID)
        #expect(changed.look == minimalLook)
        #expect(await store.updates.map(\.look) == [minimalLook])
    }

    @Test("a language and a look chosen one after the other both stay, whichever is chosen first")
    func languageAndLookKeepEachOther() async throws {
        let languageFirst = InMemoryStoredCVs([original])
        _ = try await ChangeStoredCV(cvs: languageFirst).setDocumentLanguage("de", of: cvID)
        _ = try await ChangeStoredCV(cvs: languageFirst).setLook(modernLook, of: cvID)
        let lookFirst = InMemoryStoredCVs([original])
        _ = try await ChangeStoredCV(cvs: lookFirst).setLook(modernLook, of: cvID)
        _ = try await ChangeStoredCV(cvs: lookFirst).setDocumentLanguage("de", of: cvID)

        let expected = Record(id: cvID, title: "iOS roles", language: "de", look: modernLook, content: "as first saved")
        #expect(await languageFirst.stored[cvID] == expected)
        #expect(await lookFirst.stored[cvID] == expected)
    }

    @Test("a CV that is no longer stored is not found, and nothing is stored")
    func notFound() async {
        let store = InMemoryStoredCVs([])
        await #expect(throws: StoredCVChangeError.notFound) { _ = try await ChangeStoredCV(cvs: store).rename(cvID, to: "New") }
        await #expect(throws: StoredCVChangeError.notFound) { _ = try await ChangeStoredCV(cvs: store).setDocumentLanguage("en", of: cvID) }
        await #expect(throws: StoredCVChangeError.notFound) { _ = try await ChangeStoredCV(cvs: store).setLook(modernLook, of: cvID) }
        #expect(await store.updates.isEmpty)
    }

    @Test("a failure of the store reaches the caller as it is")
    func storeFailure() async {
        let loading = InMemoryStoredCVs([original])
        await loading.failLoading()
        await #expect(throws: StoreFailed()) { _ = try await ChangeStoredCV(cvs: loading).rename(cvID, to: "New") }
        await #expect(throws: StoreFailed()) { _ = try await ChangeStoredCV(cvs: loading).setLook(modernLook, of: cvID) }
        let updating = InMemoryStoredCVs([original])
        await updating.failUpdating()
        await #expect(throws: StoreFailed()) { _ = try await ChangeStoredCV(cvs: updating).setDocumentLanguage("en", of: cvID) }
        await #expect(throws: StoreFailed()) { _ = try await ChangeStoredCV(cvs: updating).setLook(modernLook, of: cvID) }
    }
}
