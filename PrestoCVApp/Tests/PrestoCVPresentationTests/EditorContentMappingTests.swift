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

    /// A CV with every field the form shows populated, each with a value of its own.
    func fullCV() throws -> CV {
        let sections = CVSections(
            experiences: [Experience(role: "Designer", company: "Acme", location: "Pisa",
                                     period: try Period.reading(start: "2019-02", end: "2020", current: false),
                                     description: "Led the forms.")],
            education: [Education(degree: "Design", school: "Politecnico", period: try Period.reading(start: "2014", end: "", current: true),
                                  description: "Thesis on forms.")],
            skills: [Skill(name: "Prototyping", level: SkillLevel(4))],
            languages: [LanguageSkill(language: "French", proficiency: .b2)],
            certifications: [Certification(name: "Usability", issuer: "Institute", issued: PartialDate(year: 2021, month: 6),
                                           link: WebLink("https://example.org/cert"), description: "Passed.")],
            profiles: [ProfileLink(platform: "Portfolio", link: WebLink("https://example.org/me")!)],
            interests: ["Cycling"]
        )
        return CV(id: SequentialIDGenerator().next(), title: "Design roles", personal: person(), sections: sections)
    }

    /// Every leaf of `value`, as text: a string, a number, a flag, or the name of a case.
    func leaves(_ value: Any) -> [String] {
        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .optional { return mirror.children.flatMap { leaves($0.value) } }
        if mirror.children.isEmpty { return ["\(value)"] }
        return mirror.children.flatMap { leaves($0.value) }
    }

    @Test("every populated field of the CV appears in the form, and every field of the form comes from the CV")
    func mirrorCompletenessOfEditorContent() throws {
        let cv = try fullCV()
        let content = EditorContent(cv)

        let shown = leaves(content)
        let held = leaves(cv.title) + leaves(cv.personal) + leaves(cv.sections)
        // Each value of the CV is somewhere in the form: a date is its text, a level or a proficiency its code
        // (`current` is the flag of a period that goes on: the form's flag, which the round trip below pins)
        for leaf in held where !["current", "unknown"].contains(leaf) {
            #expect(shown.contains { $0.contains(leaf) }, "\(leaf) is not in the form")
        }
        // Every field of the form is populated, but the end of the period that goes on: none is without a field to fill it
        #expect(shown.filter(\.isEmpty).count == 1, "a field of the form is blank for a CV that holds every field")
        // And what the form holds lands in the CV, and in nothing else
        let blank = CV(id: cv.id)
        #expect(content.applied(to: blank) == cv)
    }

    @Test("a CV with sections goes to the form and back unchanged")
    func sectionsRoundTrip() throws {
        let cv = try fullCV()

        #expect(EditorContent(cv).applied(to: cv) == cv)
        #expect(EditorContent(EditorContent(cv).applied(to: cv)) == EditorContent(cv))
    }

    @Test("a row without what its entry needs is left out of the CV and named, a blank one without a word")
    func incompleteRows() {
        var ids = RowIDs()
        var content = EditorContent.empty
        content.languages = [LanguageRow(id: ids.make(), language: "French", proficiency: ""),
                             LanguageRow(id: ids.make(), language: "", proficiency: "")]
        content.profiles = [ProfileRow(id: ids.make(), platform: "Portfolio", link: "not a link"),
                            ProfileRow(id: ids.make(), platform: "", link: "")]

        let cv = content.applied(to: CV(id: SequentialIDGenerator().next()))

        #expect(cv.sections.languages.isEmpty)
        #expect(cv.sections.profiles.isEmpty)
        #expect(content.unreadableFields == [.languageProficiency, .profileLink])
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
