import Testing
import PrestoCVDomain
@testable import PrestoCVPresentation

/// The document language and the look of the open CV: changed by the writer of the open CV, which keeps them; the editor
/// shows, exports and copies what it gives back, and the person's edits stay.
@MainActor
@Suite("Editor language and look")
struct EditorLanguageAndLookTests {

    let classicOcean = EditorLook(design: "classic", palette: "ocean", fonts: nil)

    @Test("a language change goes through the writer, the editor shows what it stored, and the edits stay")
    func languageChangeUsesThePortAndKeepsEdits() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let editor = await world.editor(on: cv)
        editor.type(\.fullName, "Mara Ellison-Renn")

        await editor.setDocumentLanguage("de")

        #expect(world.editing.languages.withLock { $0.map { $0?.tag } } == ["de"])
        #expect(editor.documentLanguage == "de")
        #expect(editor.content.fullName == "Mara Ellison-Renn")
        #expect(try await world.editing.inStore(cv.id).language?.tag == "de")

        await editor.saveNow()
        let stored = try await world.editing.inStore(cv.id)
        #expect(stored.language?.tag == "de")
        #expect(stored.personal.fullName == "Mara Ellison-Renn")
        #expect(editor.saveStatus == .saved)

        await editor.setDocumentLanguage(nil)
        #expect(editor.documentLanguage == nil)
        #expect(try await world.editing.inStore(cv.id).language == nil)

        await editor.setDocumentLanguage("not a tag!")
        #expect(world.editing.languages.withLock { $0.count } == 2)
        #expect(editor.documentLanguage == nil)
    }

    @Test("a look change goes through the writer with the parts chosen, the editor shows what it stored, and the edits stay")
    func lookChangeUsesThePortAndKeepsEdits() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let editor = await world.editor(on: cv)
        #expect(editor.look == nil)
        editor.type(\.fullName, "Mara Ellison-Renn")

        await editor.changeLook(to: classicOcean, parts: [.design, .palette])

        #expect(world.editing.looks.withLock { $0.map(\.parts) } == [[.design, .palette]])
        #expect(editor.look == classicOcean)
        #expect(editor.content.fullName == "Mara Ellison-Renn")
        #expect(try await world.editing.inStore(cv.id).design?.design == "classic")

        await editor.saveNow()
        let stored = try await world.editing.inStore(cv.id)
        #expect(stored.design?.palette == "ocean")
        #expect(stored.personal.fullName == "Mara Ellison-Renn")
        #expect(editor.saveStatus == .saved)

        await editor.changeLook(to: EditorLook(design: "Not An Id", palette: nil, fonts: nil), parts: [.design])
        #expect(world.editing.looks.withLock { $0.count } == 1)
        #expect(editor.look == classicOcean)
    }

    @Test("a look and a language chosen before the first write are shown at once and stored by that write")
    func changesBeforeTheFirstWriteAreStoredByIt() async throws {
        let world = Editing()
        let editor = world.editor(.blank)
        await editor.load()

        await editor.setDocumentLanguage("fr")
        await editor.changeLook(to: classicOcean, parts: [.design, .palette])

        #expect(world.editing.writeCount == 0)
        #expect(editor.documentLanguage == "fr")
        #expect(editor.look == classicOcean)
        #expect(editor.saveStatus == .notEnoughContent)

        editor.type(\.fullName, "Tobias Renn")
        await world.passThePause(thenWrites: 1)
        await editor.saveNow()

        let stored = try await world.editing.store.list().cvs
        #expect(stored.map(\.personal.fullName) == ["Tobias Renn"])
        #expect(stored.map { $0.language?.tag } == ["fr"])
        #expect(stored.map { $0.design?.design } == ["classic"])
        #expect(editor.saveStatus == .saved)
        #expect(editor.look == classicOcean)
    }

    @Test("an export snapshot and a copy take the look and the language chosen last")
    func exportAndCopyTakeTheChosenLookAndLanguage() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let editor = await world.editor(on: cv)
        await editor.setDocumentLanguage("de")
        await editor.changeLook(to: classicOcean, parts: [.design, .palette])

        let snapshot = editor.exportSnapshot()
        await editor.saveAsCopy()

        #expect(snapshot?.cv.language?.tag == "de")
        #expect(snapshot?.cv.design?.design == "classic")
        let copies = world.editing.copies.withLock { $0 }
        #expect(copies.map { $0.language?.tag } == ["de"])
        #expect(copies.map { $0.design?.design } == ["classic"])
        #expect(editor.documentLanguage == "de")
        #expect(editor.look == classicOcean)
    }

    @Test("a change the store refuses shows its status, and the look and the text stay as they were")
    func refusedChangeShowsItsStatus() async throws {
        let world = Editing()
        let cv = try await world.storedCV()
        let editor = await world.editor(on: cv)
        try await world.editing.otherWindowSaves(cv, fullName: "Tobias Renn")
        editor.type(\.fullName, "Mara Ellison-Renn")

        await editor.changeLook(to: classicOcean, parts: [.design])

        #expect(editor.saveStatus == .conflict)
        #expect(editor.look == nil)
        #expect(editor.content.fullName == "Mara Ellison-Renn")
        #expect(try await world.editing.inStore(cv.id).design == nil)
    }
}
