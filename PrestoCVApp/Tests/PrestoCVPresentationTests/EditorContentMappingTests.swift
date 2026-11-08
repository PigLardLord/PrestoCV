import Testing
import PrestoCVCoreTestSupport
import PrestoCVDomain
@testable import PrestoCVPresentation

/// The form's text read into a CV and back, and what the editor opens.
@MainActor
@Suite("Editor content")
struct EditorContentMappingTests {

    func person() -> PersonalDetails {
        PersonalDetails(
            fullName: "Mara Ellison", professionalTitle: "Product designer", email: EmailAddress("mara@example.org"),
            phone: PhoneNumber("+39 055 0100"), location: "Florence", website: WebLink("https://example.org/mara"),
            summary: "Designs forms people finish."
        )
    }

    @Test("the title and the personal details go from the CV to the form and back unchanged")
    func contentRoundTripsThroughTheCV() throws {
        let cv = CV(id: SequentialIDGenerator().next(), title: "Design roles", personal: person(),
                    sections: CVSections(skills: [Skill(name: "Prototyping")]), language: DocumentLanguage("it"))

        let content = EditorContent(cv)

        #expect(content.applied(to: cv) == cv)
        #expect(content.email == "mara@example.org")
        #expect(content.website == "https://example.org/mara")
        #expect(EditorContent(content.applied(to: cv)) == content)
    }

    @Test("every personal detail of the CV has its field in the form, and every field of the form is the CV's")
    func mirrorCompletenessOfThePersonalDetails() {
        func labels(_ value: Any) -> Set<String> { Set(Mirror(reflecting: value).children.compactMap(\.label)) }

        #expect(labels(EditorContent.empty) == labels(person()).union(["title"]))
    }

    @Test("text that cannot be read as an address is a field code; the rest is stored and the text stays in the form")
    func unreadableAddressIsAFieldCode() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let editor = await world.editor(on: cv)

        editor.type(\.email, "mara at example")
        editor.type(\.professionalTitle, "Product designer")
        #expect(editor.saveStatus == .unreadable(.email))
        await editor.saveNow()

        #expect(editor.saveStatus == .unreadable(.email))
        #expect(editor.content.email == "mara at example")
        let stored = try await world.editing.inStore(cv.id)
        #expect(stored.personal.email == nil)
        #expect(stored.personal.professionalTitle == "Product designer")

        editor.type(\.email, "mara@example.org")
        await editor.saveNow()
        #expect(editor.saveStatus == .saved)
    }

    @Test("a draft keeps its identity for the first write, which creates it")
    func draftKeepsItsIdentity() async throws {
        let world = Editing()
        let draft = CV(id: world.editing.ids.next(), title: "Imported", personal: person())
        let editor = world.editor(.draft(CVDraft(cv: draft)))
        await editor.load()

        await editor.saveNow()

        let writes = world.editing.writes.withLock { $0 }
        #expect(writes.map(\.id) == [draft.id])
        #expect(writes.map(\.revision) == [0])
        #expect(try await world.editing.inStore(draft.id).personal == draft.personal)
        #expect(editor.saveStatus == .saved)
    }

    @Test("a draft opens with its content and stores nothing until it is changed or left")
    func draftOpensWithoutAWrite() async throws {
        let world = Editing()
        let draft = CV(id: world.editing.ids.next(), title: "Imported", personal: person())
        let editor = world.editor(.draft(CVDraft(cv: draft)))
        #expect(editor.opening == .opening)

        await editor.load()
        world.clock.advance(by: .seconds(5))
        await settle()

        #expect(editor.opening == .open)
        #expect(editor.content == EditorContent(draft))
        #expect(world.editing.writeCount == 0)
        #expect(editor.saveStatus == .pending)
        #expect(!editor.isSavedOnThisDevice)
    }

    @Test("a stored CV that is gone opens as missing")
    func openingAStoredCVThatIsNotThere() async throws {
        let world = Editing()
        let missing = world.editor(.stored(CVReference(id: world.editing.ids.next())))

        await missing.load()

        #expect(missing.opening == .missing)
    }
}
