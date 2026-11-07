import Foundation
import Testing
import PrestoCVDomain
@testable import PrestoCVPresentation
import PrestoCVWorkflowPorts

/// The language of the PDF, the choice that goes to the CV, and the name of the file.
@MainActor
@Suite("Export sheet language")
struct ExportSheetLanguageTests {

    @Test("With no language chosen and none in the CV nothing is exported, the status asks for one, the app's is offered first")
    func noLanguageIsLanguageNeededAndStartsNothing() async {
        let world = SheetWorld()
        world.cv = SheetWorld.cv(language: nil)
        let sheet = world.sheet()

        sheet.start()
        world.passThePause()
        await waitUntil("the sheet to read the CV") { sheet.status != .exporting }
        await settle()

        #expect(sheet.status == .languageNeeded)
        #expect(world.exporter.calls == 0, "no PDF in a language nobody chose")
        #expect(sheet.effectiveLanguage == nil)
        #expect(sheet.offeredLanguages.map(\.tag) == ["fr", "en", "de", "it"])
    }

    @Test("A language chosen in the sheet beats the CV's own")
    func choiceBeatsTheCVsLanguage() async {
        let world = SheetWorld()
        let sheet = world.sheet()

        sheet.select(language: SheetWorld.language("de"))
        await world.passThePause(thenExports: 1)

        #expect(world.exporter.languages.map(\.tag) == ["de"], "the CV is in Italian, the choice German")
        #expect(sheet.effectiveLanguage == SheetWorld.language("de"))
    }

    @Test("Choosing a language takes it to the CV once; starting and exporting take nothing")
    func choosingCallsTheCallbackOnce() async {
        let world = SheetWorld()
        let sheet = world.sheet()

        sheet.start()
        sheet.select(language: SheetWorld.language("de"))
        await world.passThePause(thenExports: 1)
        await settle()

        #expect(world.chosen == [SheetWorld.language("de")])
    }

    @Test("Choosing automatic takes nil to the CV")
    func choosingAutomaticCallsItWithNil() async {
        let world = SheetWorld()
        let sheet = world.sheet()

        sheet.select(language: nil)

        #expect(world.chosen == [nil])
    }

    @Test("Automatic is nil, and names the language it stands for: the CV's")
    func automaticIsNilAndNamesTheLanguageItStandsFor() async {
        let world = SheetWorld()
        let sheet = world.sheet()

        sheet.select(language: SheetWorld.language("de"))
        sheet.select(language: nil)
        await world.passThePause(thenExports: 1)

        #expect(sheet.selectedLanguage == nil)
        #expect(sheet.automaticLanguage == SheetWorld.language("it"), "the CV is in Italian")
        #expect(sheet.effectiveLanguage == SheetWorld.language("it"))
        #expect(world.exporter.languages.map(\.tag) == ["it"])
    }

    @Test("The file is named in the language of the PDF, not the app's, and only once the PDF's language is known")
    func fileNameUsesTheLanguageOfThePDF() async {
        let world = SheetWorld()
        let sheet = world.sheet()

        sheet.start()
        await world.passThePause(thenExports: 1)
        #expect(sheet.suggestedFileName == "Mara Ellison – Curriculum.pdf", "the CV is in Italian, the app in French")

        sheet.select(language: SheetWorld.language("de"))
        #expect(sheet.suggestedFileName == nil, "no name of the old PDF while the new one is made")
        await world.passThePause(thenExports: 2)
        #expect(sheet.suggestedFileName == "Mara Ellison – Lebenslauf.pdf")

        sheet.stop()
        #expect(sheet.suggestedFileName == nil, "no name once the PDF is dropped")
    }

    @Test("The file takes the person's name as written, not the CV's own name")
    func fileNameKeepsThePersonsName() async {
        let world = SheetWorld()
        world.cv = SheetWorld.cv(fullName: "Zoë Ångström")
        let sheet = world.sheet()

        sheet.start()
        await world.passThePause(thenExports: 1)

        #expect(sheet.suggestedFileName == "Zoë Ångström – Curriculum.pdf", "the CV's own name is \"Design roles\"")
    }
}
