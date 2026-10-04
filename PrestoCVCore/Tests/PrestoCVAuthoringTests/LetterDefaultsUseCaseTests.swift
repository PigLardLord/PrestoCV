import Testing
import Foundation
import PrestoCVDomain
import PrestoCVApplication
import PrestoCVCoreTestSupport

private func defaults(salary: String = "", note: String = "") throws -> LetterDefaults { try LetterDefaults(salaryExpectation: salary, note: note) }

@Suite("R10 · letter defaults store contract")
struct LetterDefaultsContractTests {
    @Test("in-memory adapter passes") func inMemory() async throws { try await LetterDefaultsStoreContract.verify(InMemoryLetterDefaultsStore()) }
}

@Suite("ADR 0019 · letter defaults use cases")
struct LetterDefaultsUseCaseTests {
    @Test("the defaults are none until saved, then what was saved, and a save is over the revision that was loaded")
    func loadAndSave() async throws {
        let store = InMemoryLetterDefaultsStore()
        let loaded = try await LoadLetterDefaults(store: store)()
        #expect(loaded == .unsaved)
        let saved = try await SaveLetterDefaults(store: store)(try defaults(salary: "55k"), over: loaded)
        #expect(saved.revision == 1 && saved.defaults.salaryExpectation == "55k")
        #expect(try await LoadLetterDefaults(store: store)() == saved)
        await #expect(throws: AuthoringError.conflict(storedRevision: 1)) { _ = try await SaveLetterDefaults(store: store)(try defaults(note: "stale"), over: loaded) }
    }

    @Test("clearing a default is a save like another")
    func clearing() async throws {
        let store = InMemoryLetterDefaultsStore()
        let first = try await SaveLetterDefaults(store: store)(try defaults(salary: "55k", note: "Remote"), over: .unsaved)
        let cleared = try await SaveLetterDefaults(store: store)(try defaults(note: "Remote"), over: first)
        #expect(cleared.defaults.salaryExpectation.isEmpty && cleared.defaults.note == "Remote" && cleared.revision == 2)
    }

    @Test("a store's failures are translated once: a corrupt file and a newer one are told apart, and none reads as empty")
    func translation() async throws {
        let cases: [(LetterDefaultsError, AuthoringError)] = [
            (.conflict(storedRevision: 4), .conflict(storedRevision: 4)), (.corrupt(file: "f", reason: "r"), .corrupt),
            (.upgradeRequired(file: "f", version: 2), .upgradeRequired(version: 2)), (.wouldNotReadBack(file: "f"), .tooLarge),
            (.unreadable(file: "f"), .unavailable), (.tooLarge(file: "f"), .unavailable), (.storeUnavailable(.cannotList), .unavailable),
            (.writeFailed(file: "f"), .unavailable), (.quarantineFailed(file: "f"), .unavailable), (.alreadyExists, .unavailable),
        ]
        for (failure, expected) in cases {
            let store = FailingLetterDefaultsStore(failure)
            await #expect(throws: expected) { _ = try await LoadLetterDefaults(store: store)() }
            await #expect(throws: expected) { _ = try await SaveLetterDefaults(store: store)(.empty, over: .unsaved) }
        }
    }
}
