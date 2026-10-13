import Testing
import Foundation
@testable import PrestoCV
@testable import PrestoCVCore
@testable import CVPDFExporter

// MARK: - Test Doubles

/// Keeps the choice in memory, so view model tests never touch the real file in Application Support.
final class InMemoryExportPreferencesStore: ExportPreferencesStore {
    var stored: ExportPreferences
    var saveError: Error?
    private(set) var saveCount = 0

    init(stored: ExportPreferences = ExportPreferences()) {
        self.stored = stored
    }

    func load() -> ExportPreferences {
        stored
    }

    func save(_ preferences: ExportPreferences) throws {
        saveCount += 1
        if let saveError {
            throw saveError
        }
        stored = preferences
    }
}

// MARK: - FileExportPreferencesStore Tests

@Suite("FileExportPreferencesStore Tests")
struct FileExportPreferencesStoreTests {

    private func makeTemporaryFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("export-preferences.json")
    }

    private func removeDirectory(of fileURL: URL) {
        try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
    }

    @Test("load returns an empty choice when nothing is stored")
    func loadReturnsEmptyChoiceWithoutFile() {
        let fileURL = makeTemporaryFileURL()
        let store = FileExportPreferencesStore(fileURL: fileURL)

        #expect(store.load() == ExportPreferences())
    }

    @Test("save then load returns the same choice and creates the folder")
    func saveThenLoadRoundTrip() throws {
        let fileURL = makeTemporaryFileURL()
        defer { removeDirectory(of: fileURL) }
        let store = FileExportPreferencesStore(fileURL: fileURL)
        let choice = ExportPreferences(templateId: "minimal", colorPalette: .creative, fontScheme: .serif)

        try store.save(choice)

        #expect(FileManager.default.fileExists(atPath: fileURL.path))
        #expect(FileExportPreferencesStore(fileURL: fileURL).load() == choice)
    }

    @Test("a second save replaces the first choice")
    func saveReplacesPreviousChoice() throws {
        let fileURL = makeTemporaryFileURL()
        defer { removeDirectory(of: fileURL) }
        let store = FileExportPreferencesStore(fileURL: fileURL)

        try store.save(ExportPreferences(templateId: "modern", colorPalette: .modern, fontScheme: .modern))
        try store.save(ExportPreferences(templateId: "minimal", colorPalette: .minimal, fontScheme: .classic))

        #expect(store.load() == ExportPreferences(templateId: "minimal", colorPalette: .minimal, fontScheme: .classic))
    }

    @Test("load returns an empty choice when the file is damaged")
    func loadReturnsEmptyChoiceForDamagedFile() throws {
        let fileURL = makeTemporaryFileURL()
        defer { removeDirectory(of: fileURL) }
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("not json".utf8).write(to: fileURL)

        #expect(FileExportPreferencesStore(fileURL: fileURL).load() == ExportPreferences())
    }

    @Test("the default file lives in Application Support, outside UserDefaults")
    func defaultFileIsInApplicationSupport() {
        let path = FileExportPreferencesStore.defaultFileURL.path

        #expect(path.contains("Application Support"))
        #expect(path.hasSuffix("export-preferences.json"))
    }
}

// MARK: - CVExportSheetViewModel remembers the last choice

@MainActor
@Suite("CVExportSheetViewModel Preferences Tests")
struct CVExportSheetViewModelPreferencesTests {

    private static func template(_ id: String) -> Template {
        Template(id: id, name: id.capitalized, htmlContent: "<html></html>")
    }

    private func makeViewModel(
        templates: [Template],
        stored: ExportPreferences = ExportPreferences()
    ) async -> (CVExportSheetViewModel, InMemoryExportPreferencesStore, MockCVExportService) {
        let service = MockCVExportService()
        await service.setAvailableTemplatesResult(.success(templates))
        let store = InMemoryExportPreferencesStore(stored: stored)
        return (CVExportSheetViewModel(exportService: service, preferencesStore: store), store, service)
    }

    @Test("loadTemplates preselects the template chosen last time")
    func loadTemplatesPreselectsStoredTemplate() async {
        let (viewModel, _, _) = await makeViewModel(
            templates: [Self.template("professional"), Self.template("modern"), Self.template("minimal")],
            stored: ExportPreferences(templateId: "minimal", colorPalette: .creative, fontScheme: .serif)
        )

        await viewModel.loadTemplates()

        #expect(viewModel.selectedTemplateId == "minimal")
        #expect(viewModel.selectedColorPalette == .creative)
        #expect(viewModel.selectedFontScheme == .serif)
    }

    @Test("loadTemplates falls back to the first template when the stored one is gone")
    func loadTemplatesFallsBackToFirstTemplate() async {
        let (viewModel, _, _) = await makeViewModel(
            templates: [Self.template("professional"), Self.template("modern")],
            stored: ExportPreferences(templateId: "retired", colorPalette: .minimal, fontScheme: nil)
        )

        await viewModel.loadTemplates()

        #expect(viewModel.selectedTemplateId == "professional")
        #expect(viewModel.selectedColorPalette == .minimal)
        #expect(viewModel.selectedFontScheme == .classic)
    }

    @Test("loadTemplates keeps the defaults when nothing was chosen before")
    func loadTemplatesKeepsDefaultsWithoutStoredChoice() async {
        let (viewModel, _, _) = await makeViewModel(
            templates: [Self.template("professional"), Self.template("modern")]
        )

        await viewModel.loadTemplates()

        #expect(viewModel.selectedTemplateId == "professional")
        #expect(viewModel.selectedColorPalette == .professional)
        #expect(viewModel.selectedFontScheme == .classic)
    }

    @Test("loadTemplates does not overwrite a template picked in this session")
    func loadTemplatesKeepsCurrentSelection() async {
        let (viewModel, _, _) = await makeViewModel(
            templates: [Self.template("professional"), Self.template("modern")],
            stored: ExportPreferences(templateId: "professional", colorPalette: nil, fontScheme: nil)
        )
        viewModel.selectedTemplateId = "modern"

        await viewModel.loadTemplates()

        #expect(viewModel.selectedTemplateId == "modern")
    }

    @Test("a successful export stores the template, palette and font")
    func exportStoresTheChoice() async {
        let (viewModel, store, _) = await makeViewModel(templates: [Self.template("modern")])
        viewModel.selectedTemplateId = "modern"
        viewModel.selectedColorPalette = .creative
        viewModel.selectedFontScheme = .serif

        await viewModel.export(cv: CVModel(name: "Test CV"))

        #expect(store.stored == ExportPreferences(templateId: "modern", colorPalette: .creative, fontScheme: .serif))
    }

    @Test("a failed export does not store the choice")
    func failedExportStoresNothing() async {
        let (viewModel, store, service) = await makeViewModel(templates: [Self.template("modern")])
        await service.setExportResult(.failure(AppError.unknown("Export error")))
        viewModel.selectedTemplateId = "modern"

        await viewModel.export(cv: CVModel(name: "Test CV"))

        #expect(store.saveCount == 0)
    }

    @Test("an export without a template stores nothing")
    func exportWithoutTemplateStoresNothing() async {
        let (viewModel, store, _) = await makeViewModel(templates: [])

        await viewModel.export(cv: CVModel(name: "Test CV"))

        #expect(store.saveCount == 0)
    }

    @Test("an export still succeeds when the choice cannot be stored")
    func exportSucceedsWhenStoringFails() async {
        let (viewModel, store, _) = await makeViewModel(templates: [Self.template("modern")])
        store.saveError = CocoaError(.fileWriteOutOfSpace)
        viewModel.selectedTemplateId = "modern"

        await viewModel.export(cv: CVModel(name: "Test CV"))

        #expect(viewModel.previewItem != nil)
        #expect(viewModel.errorMessage == nil)
    }
}
