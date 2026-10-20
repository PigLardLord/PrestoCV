import Testing
import Foundation
import UIKit
@testable import PrestoCV
@testable import PrestoCVCore
@testable import CVPDFExporter

/// An export whose task is cancelled while it renders ends in the cancellation, and leaves nothing on disk, even when
/// the renderer hands back a PDF after the cancellation.
@Suite("CVExportService Tests - a cancelled export", .timeLimit(.minutes(1)))
struct CVExportServiceCancellationTests {

    @Test("an export cancelled while it renders throws the cancellation and writes no file")
    func aCancelledExportWritesNoFile() async throws {
        let environment = try await ExportTestEnvironment.make()
        defer { environment.cleanUp() }
        let renderer = RendersThroughACancellation()
        let service = CVExportService(
            container: PDFExportDependencyContainer(templateRepository: environment.repository, makeRenderer: { renderer }),
            fileNames: ExportFileName(titlePattern: { _ in "%@ – CV" }),
            temporaryDirectory: environment.exportsDirectory
        )
        let cv = CVModel(personalInfo: PersonalInfo(name: "Ada Lovelace", email: "ada@example.com"))

        let export = Task { try await service.export(cv: cv, templateId: "professional", options: ExportOptions(templateId: "professional")) }
        await renderer.waitUntilStarted()
        export.cancel()

        await #expect(throws: CancellationError.self) { _ = try await export.value }
        #expect(try FileManager.default.contentsOfDirectory(atPath: environment.exportsDirectory.path).isEmpty)
    }
}

/// A renderer that says it started, waits until its task is cancelled, and then hands back a PDF all the same, as a
/// renderer that misses the cancellation would.
private final class RendersThroughACancellation: PDFRendererProtocol, Sendable {
    private let starts = AsyncStream<Void>.makeStream()
    /// Nothing is ever sent on it, and its continuation keeps it open: iterating it ends only with a cancellation.
    private let never = AsyncStream<Void>.makeStream()

    var isAvailable: Bool { true }
    var maxPages: Int { 100 }

    func waitUntilStarted() async {
        var iterator = starts.stream.makeAsyncIterator()
        _ = await iterator.next()
    }

    func renderToPDF(html: String, options: ExportOptions) async throws -> Data {
        starts.continuation.yield()
        for await _ in never.stream {}
        return UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842)).pdfData { $0.beginPage() }
    }
}
