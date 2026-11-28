// This file imports nothing of the domain, the application layer or the ports, and not `@testable`: what it uses is what a
// view sees.
import Foundation
import Testing
import PrestoCVPresentation

/// Every public member of the export sheet and of the values it shows, each with its type spelled out. It compiles only
/// while each type is the presentation's own: a domain type in the public surface breaks it.
@MainActor
func useEveryPublicMember(of sheet: ExportSheetViewModel, sharing share: PDFShare) {
    let _: ExportLanguage? = sheet.selectedLanguage
    let _: ExportLanguage? = sheet.automaticLanguage
    let _: ExportLanguage? = sheet.effectiveLanguage
    let offered: [ExportLanguage] = sheet.offeredLanguages
    let _: [String] = offered.map(\.tag)
    let _: ExportLanguage = ExportLanguage.preferred(["de"])
    let _: ExportStatus = sheet.status
    let _: ExportedDocument? = sheet.document
    let _: ExportID? = sheet.documentID
    let _: String? = sheet.suggestedFileName
    let missing: ExportMissing = sheet.missing
    let _: [ExportMissing.Field] = missing.blockers + missing.warnings
    let _: ShareOutcome? = sheet.shareOutcome
    let _: ExportSnapshot.Type = ExportSnapshot.self
    sheet.showFullPDF()
    let full: FullPDF? = sheet.fullPDF
    let _: ExportID? = full?.id
    let _: ExportedDocument? = full?.document
    let _: String? = full?.fileName
    sheet.closeFullPDF()
    sheet.start()
    sheet.select(language: ExportLanguage.preferred(["de"]))
    let announced: LanguageChoice? = sheet.languageToAnnounce
    let _: ExportLanguage? = announced?.language
    let choices: LookChoices = sheet.lookChoices
    let _: [LookChoice] = choices.designs + choices.palettes + choices.fontSchemes
    let shown: EditorLook = sheet.shownLook
    let _: String = shown.design
    let _: String? = shown.palette
    let _: String? = shown.fonts
    sheet.choose(design: "classic")
    sheet.choose(palette: nil)
    sheet.choose(fonts: nil)
    sheet.share()
    let _: PDFShare? = sheet.openShare
    let _: URL = share.url
    let _: String = share.fileName
    let _: ObjectIdentifier = share.id
    let _: ShareOutcome? = sheet.shareOutcome
    let _: ShareFailure? = sheet.shareFailure
    let remade: RemadePDF? = sheet.remadeToAnnounce
    let _: Int? = remade?.pages
    let _: DesignWait? = sheet.waitToAnnounce
    let _: DesignsAnnouncement.Kind? = sheet.designsToAnnounce?.kind
    let _: Bool = sheet.status.offersRetry
    let _: [Bool] = sheet.lookPicker.groups.map(\.checksMore)
    let _: () async -> Void = sheet.watchDesigns
    sheet.retryDesigns()
    let result = ShareResult(activity: nil, completed: false, failed: false)
    share.end(result)
    sheet.refresh()
    sheet.stop()
}

@MainActor
@Suite("Export sheet public surface")
struct ExportSheetSurfaceTests {

    @Test("The export API holds no domain type: this file uses all of it importing only the presentation")
    func noDomainTypeInTheExportAPI() async throws {
        let world = SheetWorld()
        let sheet = world.sheet()
        sheet.start()
        await world.passThePause(thenExports: 1)
        await waitUntil("the PDF") { sheet.documentID != nil }
        sheet.share()
        await waitUntil("the share") { sheet.openShare != nil }
        let share = try #require(sheet.openShare)

        useEveryPublicMember(of: sheet, sharing: share)

        #expect(sheet.status == .idle)
        #expect(sheet.selectedLanguage == ExportLanguage("de"), "a choice stays: the sheet has no way back to automatic")
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
