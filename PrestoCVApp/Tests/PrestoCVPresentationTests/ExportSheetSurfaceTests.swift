// This file imports nothing of the domain, the application layer or the ports, and not `@testable`: what it uses is what a
// view sees.
import Testing
import PrestoCVPresentation

/// Every public member of the export sheet and of the values it shows, each with its type spelled out. It compiles only
/// while each type is the presentation's own: a domain type in the public surface breaks it.
@MainActor
func useEveryPublicMember(of sheet: ExportSheetViewModel, sharing shared: ExportedDocument) {
    let _: ExportLanguage? = sheet.selectedLanguage
    let _: ExportLanguage? = sheet.automaticLanguage
    let _: ExportLanguage? = sheet.effectiveLanguage
    let offered: [ExportLanguage] = sheet.offeredLanguages
    let _: [String] = offered.map(\.tag)
    let _: ExportStatus = sheet.status
    let _: ExportedDocument? = sheet.document
    let _: String? = sheet.suggestedFileName
    let missing: ExportMissing = sheet.missing
    let _: [ExportMissing.Field] = missing.blockers + missing.warnings
    let _: ShareOutcome? = sheet.shareOutcome
    let _: ExportSnapshot.Type = ExportSnapshot.self
    sheet.start()
    sheet.select(language: ExportLanguage("de"))
    sheet.select(language: nil)
    sheet.refresh()
    let result: ShareResult = .saved
    sheet.shareEnded(result, of: shared)
    sheet.stop()
}

@MainActor
@Suite("Export sheet public surface")
struct ExportSheetSurfaceTests {

    @Test("The export API holds no domain type: this file uses all of it importing only the presentation")
    func noDomainTypeInTheExportAPI() {
        let world = SheetWorld()
        let sheet = world.sheet()

        useEveryPublicMember(of: sheet, sharing: ExportingFake.onePageDocument)

        #expect(sheet.status == .idle)
        #expect(sheet.selectedLanguage == nil)
    }

    @Test("What the sheet shows of an export, of the CV and of a share are codes: none carries a text")
    func exportStatusesCarryNoText() {
        let sheet = SheetWorld().sheet()
        let fields: [ExportMissing.Field] = [.name, .email, .phone]
        let outcomes: [ShareOutcome] = [.saved, .sent]
        let results: [ShareResult] = [.saved, .sent, .cancelled]
        let values: [Any] = everyExportStatus() + [sheet.missing] + fields + outcomes + results

        #expect(values.flatMap { strings(in: $0) }.isEmpty)
    }
}
