import Foundation
import PrestoCVDomain
import PrestoCVImporting
import PrestoCVIntegration
import PrestoCVPresentation
import PrestoCVWorkflowPorts

/// A reader of a CV's language that never finds one, for the tests that never export.
struct NoDetectedLanguage: CVLanguageDetecting {
    func language(of cv: CV, among languages: [DocumentLanguage]) -> DocumentLanguage? { nil }
}

/// An importer for the tests that never import.
struct NoImporter: CVTextImporting {
    func importText(_ text: String) throws -> ImportResult { throw ImportError.unreadable }
    func importPDF(_ data: Data) async throws -> ImportResult { throw ImportError.unreadable }
}

/// A file port for the tests that never import a file.
struct NoImportFiles: ImportFileReading {
    func receive(_ url: URL) -> ReceivedFile { ReceivedFile(id: 0, url: url) }
    func readPDF(of file: ReceivedFile) async throws -> Data { throw ImportFailure.fileNotRead }
    func release(_ file: ReceivedFile) {}
}

/// A share file port for the tests that never share: a write fails, and a remove has nothing to remove.
struct NoExportFiles: ExportFileSharing {
    struct NotWritten: Error {}

    func write(_ pdf: Data, named fileName: String) async throws -> SharedFile { throw NotWritten() }
    func remove(_ file: SharedFile) {}
}

/// An exporter for the tests that never export.
struct NoExporter: CVExporting {
    func export(_ snapshot: CV, language: DocumentLanguage) async throws -> ExportOutcome { throw ExportFailure.renderingFailed }
}

/// Background time for the tests that never leave the foreground: its hold asks the system for nothing.
struct NoBackgroundTime: BackgroundTime {
    @MainActor func hold() -> BackgroundHold { BackgroundHold(end: {}) }
}

/// Look options for the tests that never show a look picker: no design to choose, and the default design's id.
struct FixedLookOptions: LookOptionsProviding {
    func options() -> LookOptions {
        LookOptions(designs: [], palettes: [], fontSchemes: [], defaultDesign: "professional", ownLooks: [:])
    }
}
