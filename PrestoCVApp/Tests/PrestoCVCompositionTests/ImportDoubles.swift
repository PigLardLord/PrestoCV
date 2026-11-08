import Foundation
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
