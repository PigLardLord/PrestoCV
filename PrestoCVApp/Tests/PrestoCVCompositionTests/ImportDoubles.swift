import Foundation
import PrestoCVDomain
import PrestoCVImporting
import PrestoCVIntegration
import PrestoCVWorkflowPorts

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

/// An exporter for the tests that never export.
struct NoExporter: CVExporting {
    func export(_ snapshot: CV, language: DocumentLanguage) async throws -> ExportOutcome { throw ExportFailure.renderingFailed }
}

/// Look options for the tests that never show a look picker: no design to choose, and the default design's id.
struct FixedLookOptions: LookOptionsProviding {
    func options() -> LookOptions {
        LookOptions(designs: [], palettes: [], fontSchemes: [], defaultDesign: "professional", defaultPalette: nil, defaultFonts: nil)
    }
}
