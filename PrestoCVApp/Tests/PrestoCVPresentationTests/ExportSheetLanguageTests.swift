import Foundation
import Testing
import PrestoCVDomain
@testable import PrestoCVPresentation
import PrestoCVWorkflowPorts

/// The language of the PDF, the choice that goes to the CV, and the name of the file.
@MainActor
@Suite("Export sheet language")
struct ExportSheetLanguageTests {

    // MARK: - A CV that keeps no language (#407)

    @Test("A CV that keeps no language is exported in the language of its words, which goes to the CV once")
    func wordsTellTheLanguage() async {
        let world = SheetWorld()
        world.cv = SheetWorld.cv(language: nil)
        world.detector.answers(DocumentLanguage("de"))
        let sheet = world.sheet()

        sheet.start()
        await world.passThePause(thenExports: 1)
        await settle()

        #expect(world.exporter.languages.map(\.tag) == ["de"])
        #expect(sheet.automaticLanguage == SheetWorld.language("de"))
        #expect(sheet.selectedLanguage == nil)
        #expect(world.kept == [SheetWorld.language("de")])
        #expect(world.chosen.isEmpty, "the language found is no choice of the person's")
        #expect(world.detector.asked == [SheetWorld.offered.map(\.language)], "read once, among the languages offered")
    }

    @Test("A CV whose words tell no language is exported in the app's, and nothing goes to the CV")
    func wordsTellNoLanguage() async {
        let world = SheetWorld()
        world.cv = SheetWorld.cv(language: nil)
        let sheet = world.sheet()

        sheet.start()
        await world.passThePause(thenExports: 1)
        await settle()

        #expect(world.exporter.languages.map(\.tag) == ["fr"], "the app is in French")
        #expect(sheet.automaticLanguage == SheetWorld.appLanguage)
        #expect(world.kept.isEmpty, "the app's language is not the CV's: a later export reads the words again")
        #expect(world.chosen.isEmpty)
    }

    @Test("A CV that keeps a language is exported in it, and its words are not read")
    func theCVsLanguageIsNotRead() async {
        let world = SheetWorld()
        world.detector.answers(DocumentLanguage("de"))
        let sheet = world.sheet()

        sheet.start()
        await world.passThePause(thenExports: 1)
        await settle()

        #expect(world.exporter.languages.map(\.tag) == ["it"], "the CV is in Italian")
        #expect(world.detector.asked.isEmpty)
        #expect(world.kept.isEmpty)
    }

    @Test("A language chosen in the sheet goes to the CV, and the one found in the words does not")
    func aChoiceIsNotOverwritten() async {
        let world = SheetWorld()
        world.cv = SheetWorld.cv(language: nil)
        world.detector.answers(DocumentLanguage("de"))
        let sheet = world.sheet()

        sheet.select(language: SheetWorld.language("en"))
        await world.passThePause(thenExports: 1)
        await settle()

        #expect(world.exporter.languages.map(\.tag) == ["en"])
        #expect(world.chosen == [SheetWorld.language("en")])
        #expect(world.kept.isEmpty, "the CV keeps the person's choice, which reaches it later than this snapshot")
        #expect(sheet.automaticLanguage == SheetWorld.language("de"), "automatic still names what it stands for")
    }

    @Test("Choosing automatic again reads the words again, and their language goes to the CV")
    func automaticReadsTheWordsAgain() async {
        let world = SheetWorld()
        world.cv = SheetWorld.cv(language: nil)
        world.detector.answers(DocumentLanguage("de"))
        let sheet = world.sheet()

        sheet.select(language: SheetWorld.language("en"))
        await world.passThePause(thenExports: 1)
        sheet.select(language: nil)
        await world.passThePause(thenExports: 2)
        await settle()

        #expect(world.exporter.languages.map(\.tag) == ["en", "de"])
        #expect(world.chosen == [SheetWorld.language("en"), nil])
        #expect(world.kept == [SheetWorld.language("de")])
        #expect(world.detector.asked.count == 2)
    }

    @Test("Once the words told a language, a new export neither reads them again nor keeps it twice")
    func theWordsAreReadOnce() async {
        let world = SheetWorld()
        world.cv = SheetWorld.cv(language: nil)
        world.detector.answers(DocumentLanguage("de"))
        let sheet = world.sheet()

        sheet.start()
        await world.passThePause(thenExports: 1)
        await settle()
        world.detector.answers(DocumentLanguage("it"))
        sheet.refresh()
        await world.passThePause(thenExports: 2)
        await settle()

        #expect(world.exporter.languages.map(\.tag) == ["de", "de"], "the snapshot lags the language kept")
        #expect(world.detector.asked.count == 1)
        #expect(world.kept == [SheetWorld.language("de")])
    }

    // MARK: - A language chosen


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
