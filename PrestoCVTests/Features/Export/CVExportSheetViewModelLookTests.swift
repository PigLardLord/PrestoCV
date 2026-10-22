import Testing
import Foundation
@testable import PrestoCV
@testable import PrestoCVCore
@testable import CVPDFExporter
import struct PrestoCVApplication.LookChange
import struct PrestoCVDomain.DesignChoice

/// The sheet keeps the design, palette and font with its CV: it starts from the look the CV keeps, hands each change
/// to the CV at once, as the parts the person chose, and leaves the choice of earlier versions, one for the whole app,
/// alone.
@MainActor
@Suite("CVExportSheetViewModel Tests - the look of the CV")
struct CVExportSheetViewModelLookTests {

    private let service = MockCVExportService()
    private let sentLooks = SentLooks()
    private let sentLanguages = SentLanguages()

    /// What the sheet handed over, in order
    @MainActor
    final class SentLooks {
        var all: [LookChange] = []
    }

    @MainActor
    final class SentLanguages {
        var all: [DocumentLanguage?] = []
    }

    private static func template(_ id: String) -> Template {
        Template(id: id, name: id.capitalized, htmlContent: "<html></html>")
    }

    private static let designs = ["professional", "modern", "minimal"].map(template)
    private static let modern = CVLook(design: "modern", palette: "creative", fonts: "serif")
    private static let minimal = CVLook(design: "minimal", palette: "minimal", fonts: "modern")

    private func makeViewModel(
        look: CVLook?,
        legacy: ExportPreferences = ExportPreferences(),
        preferencesStore: (any ExportPreferencesStore)? = nil
    ) async -> CVExportSheetViewModel {
        await service.setAvailableTemplatesResult(.success(Self.designs))
        var cv = CVModel.exportable
        cv.look = look
        let sentLooks = self.sentLooks, sentLanguages = self.sentLanguages
        return CVExportSheetViewModel(
            cv: cv,
            exportService: service,
            preferencesStore: preferencesStore ?? InMemoryExportPreferencesStore(stored: legacy),
            documentLanguageSink: { sentLanguages.all.append($0) },
            lookSink: { sentLooks.all.append($0) },
            exportPolicy: .standard,
            documentLanguageDetector: englishDocumentLanguageDetector,
            appLocale: Locale(identifier: "en"),
            previewDebounce: .zero
        )
    }

    private func shown(by viewModel: CVExportSheetViewModel) -> ExportLook {
        ExportLook(
            templateId: viewModel.selectedTemplateId,
            colorPalette: viewModel.selectedColorPalette,
            fontScheme: viewModel.selectedFontScheme
        )
    }

    /// The change a choice makes: the parts chosen, and the look the sheet shows after it
    private func change(_ parts: Set<LookChange.Part>, shown design: String, _ palette: ColorPalette, _ font: FontScheme) -> LookChange {
        LookChange(shown: DesignChoice(design: design, palette: palette.rawValue, fonts: font.rawValue)!, parts: parts)
    }

    // MARK: - Where the sheet starts

    @Test("The sheet starts from the look of its own CV, not from the choice of the old global file")
    func startsFromTheLookOfTheCV() async {
        let legacy = ExportPreferences(templateId: "minimal", colorPalette: .minimal, fontScheme: .classic)
        let viewModel = await makeViewModel(look: Self.modern, legacy: legacy)

        await viewModel.loadTemplates()

        #expect(shown(by: viewModel) == ExportLook(templateId: "modern", colorPalette: .creative, fontScheme: .serif))
    }

    @Test("A CV without a look starts from the design an earlier version chose last")
    func withoutALookStartsFromTheOldChoice() async {
        let legacy = ExportPreferences(templateId: "minimal", colorPalette: .creative, fontScheme: .serif)
        let viewModel = await makeViewModel(look: nil, legacy: legacy)

        await viewModel.loadTemplates()

        #expect(shown(by: viewModel) == ExportLook(templateId: "minimal", colorPalette: .creative, fontScheme: .serif))
    }

    @Test("A CV without a look, and no old choice, starts with the defaults")
    func withoutALookAndAnOldChoiceStartsWithTheDefaults() async {
        let viewModel = await makeViewModel(look: nil)

        await viewModel.loadTemplates()

        #expect(shown(by: viewModel) == ExportLook(templateId: "professional", colorPalette: .professional, fontScheme: .classic))
    }

    @Test("A CV that has a look never reads the old global file")
    func aLookIsNotMixedWithTheOldFile() async {
        let spy = CountingPreferencesStore(stored: ExportPreferences(templateId: "minimal", colorPalette: .minimal, fontScheme: .modern))
        let viewModel = await makeViewModel(look: CVLook(design: "modern"), preferencesStore: spy)

        await viewModel.loadTemplates()

        #expect(shown(by: viewModel) == ExportLook(templateId: "modern", colorPalette: .professional, fontScheme: .classic))
        #expect(spy.loads == 0)
    }

    @Test("A design that is no longer installed gives the first design, and the other parts stay")
    func missingDesignGivesTheFirst() async {
        let viewModel = await makeViewModel(look: CVLook(design: "retired-design", palette: "creative", fonts: "serif"))

        await viewModel.loadTemplates()

        #expect(shown(by: viewModel) == ExportLook(templateId: "professional", colorPalette: .creative, fontScheme: .serif))
    }

    @Test("The look of the CV makes one preview when the sheet shows, not one for each of its parts")
    func startingMakesOnePreview() async {
        await service.enqueueExport(.success(URL(fileURLWithPath: "/tmp/first.pdf")), held: true)
        let viewModel = await makeViewModel(look: Self.modern)

        await viewModel.start()
        await service.waitUntilHeld(.export)

        #expect(await service.generatePreviewHTMLCallCount == 1)
        #expect(await service.lastExportTemplateId == "modern")
        #expect(await service.lastExportOptions?.customization == CustomizationOptions(colorPalette: .creative, fontScheme: .serif))
        await viewModel.stop().value
        await service.releaseHeld(.export)
    }

    // MARK: - Opening the sheet changes nothing

    @Test("Opening the sheet hands nothing to the CV, whatever the look it starts from",
          arguments: [
              "a look", "no look", "an old choice", "ids the app does not know", "a design that is gone",
          ])
    func startingIsNotAChoice(starting: String) async {
        let viewModel: CVExportSheetViewModel
        switch starting {
        case "a look": viewModel = await makeViewModel(look: Self.modern)
        case "no look": viewModel = await makeViewModel(look: nil)
        case "an old choice":
            viewModel = await makeViewModel(look: nil, legacy: ExportPreferences(templateId: "minimal", colorPalette: .creative, fontScheme: .serif))
        case "ids the app does not know": viewModel = await makeViewModel(look: CVLook(design: "x", palette: "y", fonts: "z"))
        default: viewModel = await makeViewModel(look: CVLook(design: "retired-design", palette: "creative", fonts: "serif"))
        }

        await viewModel.start()
        await viewModel.stop().value

        #expect(sentLooks.all.isEmpty, "The CV keeps what it has until the person chooses")
        #expect(sentLanguages.all.isEmpty)
    }

    // MARK: - Choosing

    @Test("Each design, palette and font chosen is handed to the CV once, as the part chosen and the look the sheet shows")
    func eachChoiceIsHandedOver() async {
        let viewModel = await makeViewModel(look: Self.modern)
        await viewModel.loadTemplates()

        viewModel.selectedTemplateId = "minimal"
        viewModel.selectedColorPalette = .minimal
        viewModel.selectedFontScheme = .classic

        #expect(sentLooks.all == [
            change([.design], shown: "minimal", .creative, .serif),
            change([.palette], shown: "minimal", .minimal, .serif),
            change([.fonts], shown: "minimal", .minimal, .classic),
        ])
    }

    @Test("The same choice again is not handed over twice")
    func sameChoiceIsHandedOverOnce() async {
        let viewModel = await makeViewModel(look: Self.modern)
        await viewModel.loadTemplates()

        viewModel.selectedColorPalette = .creative
        viewModel.selectedTemplateId = "modern"
        viewModel.selectedFontScheme = .serif
        #expect(sentLooks.all.isEmpty, "Choosing what is already chosen changes nothing")

        viewModel.selectedColorPalette = .minimal
        viewModel.selectedColorPalette = .minimal

        #expect(sentLooks.all == [change([.palette], shown: "modern", .minimal, .serif)])
    }

    @Test("A language chosen alone does not hand a look over, and a look chosen alone does not hand a language")
    func languageAndLookAreSeparate() async {
        let viewModel = await makeViewModel(look: Self.modern)
        await viewModel.loadTemplates()

        viewModel.documentLanguageChoice = .french
        #expect(sentLooks.all.isEmpty)
        #expect(sentLanguages.all == [.french])

        viewModel.selectedFontScheme = .classic
        #expect(sentLooks.all == [change([.fonts], shown: "modern", .creative, .classic)])
        #expect(sentLanguages.all == [.french])
    }

    @Test("A choice is handed over at once, while the first PDF is still being made")
    func choiceDoesNotWaitForThePDF() async {
        await service.enqueueExport(.success(URL(fileURLWithPath: "/tmp/first.pdf")), held: true)
        let viewModel = await makeViewModel(look: Self.modern)
        await viewModel.start()
        await service.waitUntilHeld(.export)

        viewModel.selectedColorPalette = .minimal

        #expect(sentLooks.all == [change([.palette], shown: "modern", .minimal, .serif)])
        #expect(viewModel.sharePDF == nil, "No PDF has been made yet")
        await viewModel.stop().value
        await service.releaseHeld(.export)
    }

    @Test("A choice made on a CV whose look the app cannot read hands over the part chosen and no other",
          arguments: [LookChange.Part.design, .palette, .fonts])
    func choiceHandsOverOnlyThePartChosen(part: LookChange.Part) async {
        let viewModel = await makeViewModel(look: CVLook(design: "future-design", palette: "neon", fonts: "handwritten"))
        await viewModel.loadTemplates()
        #expect(shown(by: viewModel) == ExportLook(templateId: "professional", colorPalette: .professional, fontScheme: .classic),
                "The sheet shows a default for every id it does not know")

        switch part {
        case .design: viewModel.selectedTemplateId = "modern"
        case .palette: viewModel.selectedColorPalette = .creative
        case .fonts: viewModel.selectedFontScheme = .serif
        }

        let expectedShown = ExportLook(
            templateId: part == .design ? "modern" : "professional",
            colorPalette: part == .palette ? .creative : .professional,
            fontScheme: part == .fonts ? .serif : .classic
        )
        #expect(sentLooks.all == [LookChange(shown: expectedShown.designChoice!, parts: [part])],
                "The ids of the parts the person did not touch are not theirs to replace")
    }

    @Test("Without a design there is no look to hand over")
    func noDesignNoLook() async {
        await service.setAvailableTemplatesResult(.success([]))
        let sentLooks = self.sentLooks
        let viewModel = CVExportSheetViewModel(
            cv: .exportable, exportService: service, preferencesStore: InMemoryExportPreferencesStore(),
            documentLanguageSink: { _ in }, lookSink: { sentLooks.all.append($0) }, exportPolicy: .standard,
            documentLanguageDetector: englishDocumentLanguageDetector, appLocale: Locale(identifier: "en"), previewDebounce: .zero
        )
        await viewModel.loadTemplates()

        viewModel.selectedColorPalette = .creative

        #expect(sentLooks.all.isEmpty)
    }

    // MARK: - Each CV has its own

    @Test("Two CVs keep different looks: each sheet starts from its own and a choice in one does not reach the other")
    func twoCVsAreIndependent() async {
        let first = await makeViewModel(look: Self.modern)
        let second = await makeViewModel(look: Self.minimal)
        await first.loadTemplates()
        await second.loadTemplates()
        #expect(shown(by: first) == ExportLook(templateId: "modern", colorPalette: .creative, fontScheme: .serif))
        #expect(shown(by: second) == ExportLook(templateId: "minimal", colorPalette: .minimal, fontScheme: .modern))

        second.selectedFontScheme = .serif
        first.selectedColorPalette = .minimal

        #expect(shown(by: first) == ExportLook(templateId: "modern", colorPalette: .minimal, fontScheme: .serif))
        #expect(shown(by: second) == ExportLook(templateId: "minimal", colorPalette: .minimal, fontScheme: .serif))
        #expect(sentLooks.all == [
            change([.fonts], shown: "minimal", .minimal, .serif),
            change([.palette], shown: "modern", .minimal, .serif),
        ])
    }

    // MARK: - The old global file

    @Test("A PDF made does not write the old global file: it is not created, and one that exists is left as it is")
    func exportWritesNoPreferences() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("look-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let absent = directory.appendingPathComponent("absent.json")
        let present = directory.appendingPathComponent("present.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let json = Data(#"{"templateId":"minimal","colorPalette":"creative","fontScheme":"serif"}"#.utf8)
        try json.write(to: present)

        for file in [absent, present] {
            let viewModel = await makeViewModel(look: nil, preferencesStore: FileExportPreferencesStore(fileURL: file))
            await viewModel.loadTemplates()
            viewModel.selectedTemplateId = "modern"
            viewModel.selectedColorPalette = .minimal

            await viewModel.requestPreview().value

            #expect(viewModel.sharePDF != nil, "The PDF is made")
            await viewModel.stop().value
        }

        #expect(!FileManager.default.fileExists(atPath: absent.path))
        #expect(try Data(contentsOf: present) == json)
    }

    /// The old choice, with the number of times it was read
    private final class CountingPreferencesStore: ExportPreferencesStore {
        let stored: ExportPreferences
        private(set) var loads = 0

        init(stored: ExportPreferences) {
            self.stored = stored
        }

        func load() -> ExportPreferences {
            loads += 1
            return stored
        }
    }
}
