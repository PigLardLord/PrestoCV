import Testing
import DiagnosticLogging
import Foundation
@testable import PrestoCV
@testable import PrestoCVCore
@testable import CVPDFExporter

// MARK: - Test Doubles

/// Holds the choice of an earlier version in memory, so view model tests never touch the real file in Application Support.
struct InMemoryExportPreferencesStore: ExportPreferencesStore {
    var stored = ExportPreferences()

    func load() -> ExportPreferences {
        stored
    }
}

// MARK: - FileExportPreferencesStore Tests

/// The file that earlier versions wrote the one choice of the whole app in: it is only read now, for a CV that has no
/// look of its own.
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

    private func write(_ json: String, to fileURL: URL) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(json.utf8).write(to: fileURL)
    }

    @Test("load returns an empty choice when nothing is stored")
    func loadReturnsEmptyChoiceWithoutFile() {
        let fileURL = makeTemporaryFileURL()

        #expect(FileExportPreferencesStore(fileURL: fileURL).load() == ExportPreferences())
    }

    @Test("load returns the choice that an earlier version wrote")
    func loadReturnsTheChoiceOfAnEarlierVersion() throws {
        let fileURL = makeTemporaryFileURL()
        defer { removeDirectory(of: fileURL) }
        try write(#"{"templateId":"minimal","colorPalette":"creative","fontScheme":"serif"}"#, to: fileURL)

        #expect(FileExportPreferencesStore(fileURL: fileURL).load()
                == ExportPreferences(templateId: "minimal", colorPalette: .creative, fontScheme: .serif))
    }

    @Test("load returns the parts of an earlier choice that were made")
    func loadReturnsAPartialChoice() throws {
        let fileURL = makeTemporaryFileURL()
        defer { removeDirectory(of: fileURL) }
        try write(#"{"colorPalette":"minimal"}"#, to: fileURL)

        #expect(FileExportPreferencesStore(fileURL: fileURL).load()
                == ExportPreferences(templateId: nil, colorPalette: .minimal, fontScheme: nil))
    }

    @Test("load returns an empty choice when the file is damaged")
    func loadReturnsEmptyChoiceForDamagedFile() throws {
        let fileURL = makeTemporaryFileURL()
        defer { removeDirectory(of: fileURL) }
        try write("not json", to: fileURL)

        #expect(FileExportPreferencesStore(fileURL: fileURL).load() == ExportPreferences())
    }

    @Test("reading the file leaves it as it is")
    func loadDoesNotChangeTheFile() throws {
        let fileURL = makeTemporaryFileURL()
        defer { removeDirectory(of: fileURL) }
        let json = #"{"templateId":"modern","colorPalette":"modern","fontScheme":"modern"}"#
        try write(json, to: fileURL)

        _ = FileExportPreferencesStore(fileURL: fileURL).load()

        #expect(try Data(contentsOf: fileURL) == Data(json.utf8))
    }

    @Test("the default file lives in Application Support, outside UserDefaults")
    func defaultFileIsInApplicationSupport() {
        let path = AppEnvironment.device(diagnostics: SilentLogger()).exportPreferencesFile.path

        #expect(path.contains("Application Support"))
        #expect(path.hasSuffix("export-preferences.json"))
    }
}
