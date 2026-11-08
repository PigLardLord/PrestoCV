import Testing
import PrestoCVCoreTestSupport
import PrestoCVDomain
@testable import PrestoCVPresentation

/// Adding and removing the rows of the form's sections.
@MainActor
@Suite("Editor rows")
struct EditorRowTests {

    @Test("a row with nothing in it goes at once, and nothing waits")
    func emptyRowGoesAtOnce() async throws {
        let world = Editing()
        let editor = await world.editor(on: try await world.storedCV())
        editor.addRow(to: .experiences)
        #expect(editor.content.experiences.count == 1)

        editor.removeRow(in: .experiences, id: editor.content.experiences[0].id)

        #expect(editor.content.experiences.isEmpty)
        #expect(editor.pendingRemoval == nil)
    }

    @Test("a row with something in it waits for the confirmation, and goes with it")
    func rowWithContentWaitsForConfirmation() async throws {
        let world = Editing()
        let editor = await world.editor(on: try await world.storedCV())
        editor.addRow(to: .skills)
        editor.content.skills[0].name = "Prototyping"
        let id = editor.content.skills[0].id

        editor.removeRow(in: .skills, id: id)

        #expect(editor.content.skills.map(\.name) == ["Prototyping"])
        #expect(editor.pendingRemoval == RowRemoval(section: .skills, row: id))

        editor.confirmRemoval()

        #expect(editor.content.skills.isEmpty)
        #expect(editor.pendingRemoval == nil)
    }

    @Test("cancelling the request keeps the row, and confirming then removes nothing")
    func cancelKeepsTheRow() async throws {
        let world = Editing()
        let editor = await world.editor(on: try await world.storedCV())
        editor.addRow(to: .interests)
        editor.content.interests[0].text = "Cycling"
        editor.removeRow(in: .interests, id: editor.content.interests[0].id)

        editor.cancelRemoval()
        editor.confirmRemoval()

        #expect(editor.content.interests.map(\.text) == ["Cycling"])
        #expect(editor.pendingRemoval == nil)
    }

    @Test("a request for a row that is not there asks for nothing")
    func removingARowThatIsNotThere() async throws {
        let world = Editing()
        let editor = await world.editor(on: try await world.storedCV())
        editor.addRow(to: .education)
        let gone = editor.content.education[0].id
        editor.removeRow(in: .education, id: gone)
        #expect(editor.content.education.isEmpty)

        editor.removeRow(in: .education, id: gone)
        editor.confirmRemoval()

        #expect(editor.pendingRemoval == nil)
        #expect(editor.content.education.isEmpty)
    }

    @Test("adding a row is an edit: the autosave stores the CV with the entry, and the status says it waits")
    func addRowIsAnEdit() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let editor = await world.editor(on: cv)
        #expect(editor.saveStatus == .saved)

        editor.addRow(to: .experiences)

        #expect(editor.saveStatus == .pending)
        await world.passThePause(thenWrites: 1)
        await editor.saveNow()
        #expect(editor.saveStatus == .saved)
        #expect(try await world.editing.inStore(cv.id).sections.experiences.count == 1)
    }

    @Test("removing a row is an edit too, as soon as the row goes")
    func removeRowIsAnEdit() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let editor = await world.editor(on: cv)
        editor.addRow(to: .experiences)
        await editor.saveNow()
        #expect(try await world.editing.inStore(cv.id).sections.experiences.count == 1)

        editor.removeRow(in: .experiences, id: editor.content.experiences[0].id)
        #expect(editor.saveStatus == .pending)
        await editor.saveNow()

        #expect(try await world.editing.inStore(cv.id).sections.experiences.isEmpty)
        #expect(editor.saveStatus == .saved)
    }

    @Test("a text too long in a row names its field, in whichever section")
    func textTooLongInARowNamesItsField() async throws {
        let world = Editing()
        let editor = await world.editor(on: try await world.storedCV())
        editor.addRow(to: .certifications)

        editor.content.certifications[0].issuer = String(repeating: "x", count: 10_001)

        #expect(editor.saveStatus == .textTooLong(.certificationIssuer))
    }

    @Test("a section above its limit names the section")
    func tooManyRowsNamesTheSection() async throws {
        let world = Editing()
        let editor = await world.editor(on: try await world.storedCV())

        for _ in 0...200 { editor.addRow(to: .skills) }

        #expect(editor.saveStatus == .tooManyEntries(.skills))
    }

    @Test("a period the domain cannot read is a field code, and the rest of the entry is stored")
    func unreadablePeriodInARow() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let editor = await world.editor(on: cv)
        editor.addRow(to: .experiences)
        editor.content.experiences[0].role = "Designer"
        editor.content.experiences[0].periodStart = "last spring"

        await editor.saveNow()

        #expect(editor.saveStatus == .unreadable(.experiencePeriod))
        #expect(editor.content.experiences[0].periodStart == "last spring")
        let stored = try await world.editing.inStore(cv.id).sections.experiences
        #expect(stored.map(\.role) == ["Designer"])
        #expect(stored.map(\.period) == [nil])
    }

    // MARK: - Every section

    /// The ids of the rows of a section, in order.
    func ids(_ content: EditorContent, _ section: EditorSection) -> [RowID] {
        switch section {
        case .experiences: content.experiences.map(\.id)
        case .education: content.education.map(\.id)
        case .skills: content.skills.map(\.id)
        case .languages: content.languages.map(\.id)
        case .certifications: content.certifications.map(\.id)
        case .profiles: content.profiles.map(\.id)
        case .interests: content.interests.map(\.id)
        }
    }

    /// Puts text in the row at `index` of a section.
    func fill(_ editor: EditorViewModel, _ section: EditorSection, at index: Int) {
        switch section {
        case .experiences: editor.content.experiences[index].role = "Designer"
        case .education: editor.content.education[index].degree = "Design"
        case .skills: editor.content.skills[index].name = "Prototyping"
        case .languages: editor.content.languages[index].language = "Italian"
        case .certifications: editor.content.certifications[index].name = "Certified"
        case .profiles: editor.content.profiles[index].platform = "Portfolio"
        case .interests: editor.content.interests[index].text = "Cycling"
        }
    }

    /// An editor whose every section has three rows, those of `filled` with text in them.
    func editorWithRows(filled: Set<Int>, in world: Editing) async throws -> EditorViewModel {
        let editor = await world.editor(on: try await world.storedCV())
        for section in EditorSection.allCases {
            for index in 0..<3 {
                editor.addRow(to: section)
                #expect(ids(editor.content, section).count == index + 1)
                guard ids(editor.content, section).count == index + 1 else { continue }
                if filled.contains(index) { fill(editor, section, at: index) }
            }
        }
        return editor
    }

    /// The ids of every section but `section`.
    func idsOutside(_ section: EditorSection, _ content: EditorContent) -> [EditorSection: [RowID]] {
        Dictionary(uniqueKeysWithValues: EditorSection.allCases.filter { $0 != section }.map { ($0, ids(content, $0)) })
    }

    @Test("adding a row changes only the section asked for", arguments: EditorSection.allCases)
    func addRowChangesOnlyItsSection(section: EditorSection) async throws {
        let editor = try await editorWithRows(filled: [0, 1, 2], in: Editing())
        let before = editor.content

        editor.addRow(to: section)

        let after = ids(editor.content, section)
        #expect(after.count == 4)
        guard after.count == 4 else { return }
        #expect(Array(after.prefix(3)) == ids(before, section))
        #expect(!ids(before, section).contains(after[3]))
        #expect(idsOutside(section, editor.content) == idsOutside(section, before))
    }

    @Test("a row with nothing in it goes at once, and its neighbours stay", arguments: EditorSection.allCases)
    func blankRemovalTakesOnlyTheBlankRow(section: EditorSection) async throws {
        let editor = try await editorWithRows(filled: [0, 2], in: Editing())
        let before = editor.content

        editor.removeRow(in: section, id: ids(before, section)[1])

        #expect(ids(editor.content, section) == [ids(before, section)[0], ids(before, section)[2]])
        #expect(idsOutside(section, editor.content) == idsOutside(section, before))
        #expect(editor.pendingRemoval == nil)
    }

    @Test("a confirmed removal takes the one row, and its neighbours stay", arguments: EditorSection.allCases)
    func confirmedRemovalTakesOnlyTheChosenRow(section: EditorSection) async throws {
        let editor = try await editorWithRows(filled: [0, 1, 2], in: Editing())
        let before = editor.content
        let chosen = ids(before, section)[1]

        editor.removeRow(in: section, id: chosen)
        #expect(ids(editor.content, section) == ids(before, section))
        #expect(editor.pendingRemoval == RowRemoval(section: section, row: chosen))
        editor.confirmRemoval()

        #expect(ids(editor.content, section) == [ids(before, section)[0], ids(before, section)[2]])
        #expect(idsOutside(section, editor.content) == idsOutside(section, before))
        #expect(editor.pendingRemoval == nil)
    }

    // MARK: - Identity

    /// The skills the editor shows, by name, with the id of each.
    func addSkills(_ names: [String], to editor: EditorViewModel) -> [RowID] {
        names.map { name in
            editor.addRow(to: .skills)
            let id = editor.content.skills[editor.content.skills.count - 1].id
            editor.content.skills[editor.content.skills.count - 1].name = name
            return id
        }
    }

    @Test("a row keeps its id while it is typed in and while the rows around it come and go")
    func rowsKeepTheirIdentity() async throws {
        let world = Editing()
        let editor = await world.editor(on: try await world.storedCV())
        let ids = addSkills(["A", "B", "C"], to: editor)
        #expect(Set(ids).count == 3)

        editor.content.skills[1].name = "B typed in"
        editor.removeRow(in: .skills, id: ids[0])
        editor.confirmRemoval()

        #expect(editor.content.skills.map(\.id) == [ids[1], ids[2]])
        #expect(editor.content.skills.map(\.name) == ["B typed in", "C"])
    }

    @Test("the ids stay in the form: two forms of one CV differ in them, and the CV built from either is the same")
    func idsNeverReachTheCV() throws {
        let cv = CV(id: SequentialIDGenerator().next(), title: "Design roles", personal: PersonalDetails(fullName: "Mara Ellison"),
                    sections: CVSections(skills: [Skill(name: "Prototyping")], interests: ["Cycling"]))
        var ids = RowIDs()

        let first = EditorContent(cv, ids: &ids)
        let second = EditorContent(cv, ids: &ids)

        #expect(first != second)
        #expect(first.skills[0].id != second.skills[0].id)
        #expect(first.applied(to: cv) == second.applied(to: cv))
        #expect(first.applied(to: cv) == cv)
    }

    @Test("a removal asked for before a reload does not wait for the reloaded form: it is gone, and removes no other row")
    func pendingRemovalDoesNotSurviveAReload() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let editor = await world.editor(on: cv)
        let ids = addSkills(["Prototyping"], to: editor)
        editor.removeRow(in: .skills, id: ids[0])
        #expect(editor.pendingRemoval != nil)
        try await world.editing.otherWindowSaves(cv, fullName: "Tobias Renn")
        await editor.saveNow()
        #expect(editor.saveStatus == .conflict)

        await editor.reload()
        #expect(editor.pendingRemoval == nil)
        let other = addSkills(["Research"], to: editor)
        editor.confirmRemoval()

        #expect(editor.content.skills.map(\.id) == other)
        #expect(editor.content.skills.map(\.name) == ["Research"])
    }

    @Test("a removal asked for stays on its row when the view replaces the rows above it")
    func pendingRemovalFollowsItsRow() async throws {
        let world = Editing()
        let editor = await world.editor(on: try await world.storedCV())
        let ids = addSkills(["A", "B", "C"], to: editor)
        editor.removeRow(in: .skills, id: ids[1])

        editor.content.skills.remove(at: 0)
        #expect(editor.pendingRemoval == RowRemoval(section: .skills, row: ids[1]))
        editor.confirmRemoval()

        #expect(editor.content.skills.map(\.name) == ["C"])
    }

    @Test("a removal asked for whose row the view replaced away removes nothing")
    func pendingRemovalOfAReplacedRow() async throws {
        let world = Editing()
        let editor = await world.editor(on: try await world.storedCV())
        let ids = addSkills(["A", "B"], to: editor)
        editor.removeRow(in: .skills, id: ids[0])

        editor.content.skills.remove(at: 0)
        editor.confirmRemoval()

        #expect(editor.content.skills.map(\.name) == ["B"])
        #expect(editor.pendingRemoval == nil)
    }

    @Test("opening a CV asks for no removal, and a form unchanged by a reload stays unchanged: nothing is written")
    func unchangedFormAfterAReload() async throws {
        let world = Editing()
        let stored = CV(id: world.editing.ids.next(), title: "Design roles", personal: PersonalDetails(fullName: "Mara Ellison"),
                        sections: CVSections(skills: [Skill(name: "Prototyping")]), language: DocumentLanguage("it"))
        let cv = try await world.editing.store.create(stored)
        let editor = await world.editor(on: cv)
        try await world.editing.otherWindowSaves(cv, fullName: "Tobias Renn")
        editor.type(\.fullName, "Mara Ellison-Renn")
        await editor.saveNow()
        #expect(editor.saveStatus == .conflict)

        await editor.reload()
        let writes = world.editing.writeCount
        world.clock.advance(by: .seconds(5))
        await settle()

        #expect(editor.saveStatus == .saved)
        #expect(editor.content.skills.map(\.name) == ["Prototyping"])
        #expect(world.editing.writeCount == writes)
    }

    // MARK: - Unique ids

    @Test("a row the view copied gets an id of its own, and removing the original leaves the copy")
    func copiedRowDoesNotShareItsId() async throws {
        let world = Editing()
        let editor = await world.editor(on: try await world.storedCV())
        let ids = addSkills(["A", "B"], to: editor)

        editor.content.skills.append(editor.content.skills[0])

        #expect(editor.content.skills.map(\.name) == ["A", "B", "A"])
        #expect(editor.content.skills[0].id == ids[0])
        #expect(Set(editor.content.skills.map(\.id)).count == 3)
        editor.removeRow(in: .skills, id: ids[0])
        editor.confirmRemoval()
        #expect(editor.content.skills.map(\.name) == ["B", "A"])
    }

    @Test("a row whose id the editor never issued gets one, and an id taken in another section is not shared")
    func foreignAndCrossSectionIdsAreReplaced() async throws {
        let world = Editing()
        let editor = await world.editor(on: try await world.storedCV())
        let ids = addSkills(["A"], to: editor)
        var content = editor.content
        content.interests = [InterestRow(id: ids[0], text: "Cycling"), InterestRow(id: RowID(value: 9_999), text: "Chess")]

        editor.content = content

        let all = editor.content.skills.map(\.id) + editor.content.interests.map(\.id)
        #expect(Set(all).count == 3)
        #expect(editor.content.skills[0].id == ids[0])
        #expect(editor.content.interests.map(\.text) == ["Cycling", "Chess"])
        #expect(!all.contains(RowID(value: 9_999)))
    }

    /// The text `fill` puts in the rows of a section, in order.
    func filledText(_ content: EditorContent, _ section: EditorSection) -> [String] {
        switch section {
        case .experiences: content.experiences.map(\.role)
        case .education: content.education.map(\.degree)
        case .skills: content.skills.map(\.name)
        case .languages: content.languages.map(\.language)
        case .certifications: content.certifications.map(\.name)
        case .profiles: content.profiles.map(\.platform)
        case .interests: content.interests.map(\.text)
        }
    }

    /// Gives `destination` the rows of one section of `source`, through the form's public setter.
    func takeRows(of section: EditorSection, from source: EditorContent, into destination: EditorViewModel) {
        switch section {
        case .experiences: destination.content.experiences = source.experiences
        case .education: destination.content.education = source.education
        case .skills: destination.content.skills = source.skills
        case .languages: destination.content.languages = source.languages
        case .certifications: destination.content.certifications = source.certifications
        case .profiles: destination.content.profiles = source.profiles
        case .interests: destination.content.interests = source.interests
        }
    }

    @Test("an editor that has made no id yet takes another editor's rows: they keep their text and get ids of its own",
          arguments: EditorSection.allCases)
    func rowsFromAnotherEditorBeforeAnyIdIsMade(section: EditorSection) async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let source = await world.editor(on: cv)
        source.addRow(to: section)
        fill(source, section, at: 0)
        let destination = await world.editor(on: cv)
        #expect(EditorSection.allCases.allSatisfy { ids(destination.content, $0).isEmpty })

        takeRows(of: section, from: source.content, into: destination)
        destination.addRow(to: section)

        #expect(filledText(destination.content, section).first == filledText(source.content, section).first)
        #expect(ids(destination.content, section).count == 2)
        #expect(Set(ids(destination.content, section)).count == 2)
    }

    @Test("the content removes only the first row with an id, if two slipped through")
    func contentRemovesOnlyTheFirstRowWithTheId() {
        let same = RowID(value: 1)
        var content = EditorContent.empty
        content.skills = [SkillRow(id: same, name: "A", level: nil), SkillRow(id: same, name: "B", level: nil)]

        content.removeRow(in: .skills, id: same)

        #expect(content.skills.map(\.name) == ["B"])
    }

    @Test("ids are made unique in every section, and the first row with an id keeps it")
    func uniqueIDsKeepTheFirst() {
        var issued = RowIDs()
        let first = issued.make()
        var content = EditorContent.empty
        content.experiences = [ExperienceRow.blank(id: first), ExperienceRow.blank(id: first)]
        content.education = [EducationRow.blank(id: first)]
        content.languages = [LanguageRow.blank(id: first)]
        content.profiles = [ProfileRow.blank(id: first), ProfileRow.blank(id: RowID(value: 0))]

        let unique = issued.unique(content)

        let all = [unique.experiences.map(\.id), unique.education.map(\.id), unique.languages.map(\.id), unique.profiles.map(\.id)]
            .flatMap { $0 }
        #expect(Set(all).count == 6)
        #expect(unique.experiences[0].id == first)
    }

    // MARK: - A pending removal whose row can no longer be told apart

    /// Where the view puts a copy of the row waiting for its removal.
    enum CopyPlace: CaseIterable, Sendable {
        case before
        case after
        case anotherSection
    }

    @Test("a copy of the row waiting for removal withdraws the request, and both rows stay", arguments: CopyPlace.allCases)
    func copyOfThePendingRowWithdrawsTheRequest(place: CopyPlace) async throws {
        let world = Editing()
        let editor = await world.editor(on: try await world.storedCV())
        let ids = addSkills(["A"], to: editor)
        editor.removeRow(in: .skills, id: ids[0])
        #expect(editor.pendingRemoval == RowRemoval(section: .skills, row: ids[0]))
        var content = editor.content
        let copy = content.skills[0]
        switch place {
        case .before: content.skills.insert(copy, at: 0)
        case .after: content.skills.append(copy)
        case .anotherSection: content.interests = [InterestRow(id: ids[0], text: "Cycling")]
        }

        editor.content = content

        #expect(editor.pendingRemoval == nil)
        editor.confirmRemoval()
        let expectedSkills = place == .anotherSection ? 1 : 2
        #expect(editor.content.skills.map(\.name) == Array(repeating: "A", count: expectedSkills))
        #expect(editor.content.interests.count == (place == .anotherSection ? 1 : 0))
        #expect(editor.pendingRemoval == nil)
    }

    @Test("the row waiting for removal taken out by the view: confirming removes nothing else")
    func pendingRowRemovedByTheViewRemovesNothingElse() async throws {
        let world = Editing()
        let editor = await world.editor(on: try await world.storedCV())
        let ids = addSkills(["A", "B"], to: editor)
        editor.removeRow(in: .skills, id: ids[0])
        var content = editor.content
        content.skills.removeAll { $0.id == ids[0] }

        editor.content = content

        #expect(editor.pendingRemoval == nil)
        editor.confirmRemoval()
        #expect(editor.content.skills.map(\.name) == ["B"])
        #expect(editor.pendingRemoval == nil)
    }
}
