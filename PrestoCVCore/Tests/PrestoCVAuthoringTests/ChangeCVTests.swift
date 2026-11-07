import Testing
import Foundation
import PrestoCVDomain
import PrestoCVApplication
import PrestoCVCoreTestSupport

private let modern = DesignChoice(design: "modern", palette: "creative", fonts: "serif")!
private let minimal = DesignChoice(design: "minimal", palette: "minimal", fonts: "classic")!

@Suite("Changing the look and the language of a CV")
struct ChangeCVTests {
    @Test("a change sets only the parts chosen and keeps the others of the look the CV holds")
    func onlyChosenPartsChange() {
        let change = LookChange(shown: minimal, parts: [.palette])

        #expect(change.applying(to: modern) == DesignChoice(design: "modern", palette: "minimal", fonts: "serif"))
    }

    @Test("a part the app does not know stays as the CV holds it when another part is chosen")
    func unknownIdsStay() {
        let held = DesignChoice(design: "from-a-newer-app", palette: "newer-palette", fonts: "newer-fonts")!
        let change = LookChange(shown: modern, parts: [.fonts])

        #expect(change.applying(to: held) == DesignChoice(design: "from-a-newer-app", palette: "newer-palette", fonts: "serif"))
    }

    @Test("a CV with no look takes all of the look shown")
    func noLookTakesAllShown() {
        #expect(LookChange(shown: modern, parts: [.palette]).applying(to: nil) == modern)
    }

    @Test("a part chosen without a value clears it")
    func aChosenPartWithoutValueClears() {
        let bare = DesignChoice(design: "minimal")!

        #expect(LookChange(shown: bare, parts: [.palette]).applying(to: modern) == DesignChoice(design: "modern", palette: nil, fonts: "serif"))
    }

    @Test("the use case stores the changed look at the next revision")
    func storesTheChangedLook() async throws {
        let repository = InMemoryCVRepository()
        let saved = try await SaveCV(repository: repository)(FixtureCV.full())

        let changed = try await ChangeCV(repository: repository).look(of: saved, LookChange(shown: minimal, parts: [.design]))

        #expect(changed.design == DesignChoice(design: "minimal", palette: "ocean", fonts: "classic"))
        #expect(changed.revision == saved.revision + 1)
        #expect(try await repository.load(saved.id) == changed)
    }

    @Test("a change that changes nothing writes nothing")
    func unchangedWritesNothing() async throws {
        let repository = InMemoryCVRepository()
        let saved = try await SaveCV(repository: repository)(FixtureCV.full())
        let same = LookChange(shown: saved.design!, parts: [.design, .palette, .fonts])

        let result = try await ChangeCV(repository: repository).look(of: saved, same)

        #expect(result == saved)
        #expect(try await repository.load(saved.id).revision == saved.revision)
    }

    @Test("a look change of a stale CV is a conflict and keeps the stored CV")
    func staleLookIsConflict() async throws {
        let repository = InMemoryCVRepository()
        let saved = try await SaveCV(repository: repository)(FixtureCV.full())
        let other = try await RenameCV(repository: repository)(saved, to: "Other window")

        await #expect(throws: AuthoringError.conflict(storedRevision: other.revision)) {
            _ = try await ChangeCV(repository: repository).look(of: saved, LookChange(shown: minimal, parts: [.design]))
        }
        #expect(try await repository.load(saved.id) == other)
    }

    @Test("the document language is stored, and cleared for automatic")
    func languageTagIsStoredAndCleared() async throws {
        let repository = InMemoryCVRepository()
        let saved = try await SaveCV(repository: repository)(FixtureCV.full())
        let german = DocumentLanguage("de")

        let set = try await ChangeCV(repository: repository).documentLanguage(of: saved, to: german)
        #expect(set.language == german && set.revision == saved.revision + 1)

        let cleared = try await ChangeCV(repository: repository).documentLanguage(of: set, to: nil)
        #expect(cleared.language == nil)
        #expect(try await repository.load(saved.id) == cleared)
    }

    @Test("a rename trims the title to one line")
    func renameTrims() async throws {
        let repository = InMemoryCVRepository()
        let saved = try await SaveCV(repository: repository)(named("Ada"))

        let renamed = try await RenameCV(repository: repository)(saved, to: "  Backend\nroles \n")

        #expect(renamed.title == "Backend roles")
    }
}

@Suite("A CV holding the content of another")
struct CVContentTests {
    @Test("the content is the other's, the identity, revision and times are the CV's own")
    func contentOfAnother() async throws {
        let repository = InMemoryCVRepository()
        let stored = try await SaveCV(repository: repository)(named("Ada", id: id1))
        let edited = FixtureCV.full(id: CVID(UUID(uuidString: "99999999-9999-9999-9999-999999999999")!))

        let result = stored.holding(contentOf: edited)

        #expect(result.id == stored.id && result.revision == stored.revision)
        #expect(result.createdAt == stored.createdAt && result.updatedAt == stored.updatedAt)
        let probe = CVID(UUID(uuidString: "88888888-8888-8888-8888-888888888888")!)
        #expect(result.duplicated(as: probe, title: result.title) == edited.duplicated(as: probe, title: edited.title))
        #expect(result.title == edited.title)
    }
}
