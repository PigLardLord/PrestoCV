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

    @Test("a look change that changes nothing, of a CV another window changed, is a conflict and keeps the stored CV")
    func unchangedLookOfStaleCVIsConflict() async throws {
        let repository = InMemoryCVRepository()
        let saved = try await SaveCV(repository: repository)(FixtureCV.full())
        let other = try await RenameCV(repository: repository)(saved, to: "Other window")
        let same = LookChange(shown: saved.design!, parts: [.design, .palette, .fonts])

        await #expect(throws: AuthoringError.conflict(storedRevision: other.revision)) {
            _ = try await ChangeCV(repository: repository).look(of: saved, same)
        }
        #expect(try await repository.load(saved.id) == other)
    }

    @Test("a language change that changes nothing, of a CV another window changed, is a conflict and keeps the stored CV")
    func unchangedLanguageOfStaleCVIsConflict() async throws {
        let repository = InMemoryCVRepository()
        let saved = try await SaveCV(repository: repository)(FixtureCV.full())
        let other = try await RenameCV(repository: repository)(saved, to: "Other window")

        await #expect(throws: AuthoringError.conflict(storedRevision: other.revision)) {
            _ = try await ChangeCV(repository: repository).documentLanguage(of: saved, to: saved.language)
        }
        #expect(try await repository.load(saved.id) == other)
    }

    @Test("a change that changes nothing, of a CV another window deleted, is deleted elsewhere")
    func unchangedChangeOfDeletedCVIsDeletedElsewhere() async throws {
        let repository = InMemoryCVRepository()
        let saved = try await SaveCV(repository: repository)(FixtureCV.full())
        try await DeleteCV(repository: repository)(saved)
        let same = LookChange(shown: saved.design!, parts: [.design, .palette, .fonts])

        await #expect(throws: AuthoringError.deletedElsewhere) {
            _ = try await ChangeCV(repository: repository).look(of: saved, same)
        }
        await #expect(throws: AuthoringError.deletedElsewhere) {
            _ = try await ChangeCV(repository: repository).documentLanguage(of: saved, to: saved.language)
        }
        #expect(try await repository.list().cvs.isEmpty)
    }

    @Test("a change applied without storing leaves the identity, revision and text as they are")
    func applyingWithoutStoring() {
        let draft = FixtureCV.full()

        let looked = ChangeCV.applying(LookChange(shown: minimal, parts: [.design]), to: draft)
        let spoken = ChangeCV.applying(language: DocumentLanguage("de"), to: draft)

        #expect(looked.design == DesignChoice(design: "minimal", palette: "ocean", fonts: "classic"))
        #expect(spoken.language == DocumentLanguage("de"))
        #expect(looked.revision == draft.revision && looked.sections == draft.sections && spoken.title == draft.title)
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

@Suite("A CV holding the text of another")
struct CVContentTests {
    @Test("the text is the other's; the identity, revision, times, design and language are the CV's own")
    func textOfAnother() async throws {
        let repository = InMemoryCVRepository()
        var base = named("Ada", id: id1)
        base.choose(design: modern)
        base.setLanguage(DocumentLanguage("de"))
        let stored = try await SaveCV(repository: repository)(base)
        var edited = FixtureCV.full(id: CVID(UUID(uuidString: "99999999-9999-9999-9999-999999999999")!))
        edited.choose(design: minimal)
        edited.setLanguage(DocumentLanguage("fr"))

        let result = stored.holding(contentOf: edited)

        #expect(result.id == stored.id && result.revision == stored.revision)
        #expect(result.createdAt == stored.createdAt && result.updatedAt == stored.updatedAt)
        #expect(result.design == modern && result.language == DocumentLanguage("de"))
        #expect(result.title == edited.title && result.personal == edited.personal && result.sections == edited.sections)
    }
}
