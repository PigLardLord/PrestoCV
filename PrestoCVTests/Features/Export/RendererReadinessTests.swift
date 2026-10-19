import Testing
import Foundation
import PDFKit
@testable import CVPDFExporter

extension RealRendererSuites {
    /// What the iOS renderer does with a page that never says it is ready: the app's renderer draws it all the same,
    /// the tests' renderer fails.
    @MainActor
    @Suite("The iOS renderer and a page that is never ready", .timeLimit(.minutes(2)))
    struct RendererReadinessTests {

        /// A page whose readiness never comes: it sets the readiness hooks before the renderer's own script can.
        private static let neverReady = """
            <!DOCTYPE html>
            <html lang="en">
            <head><script>window.__cvPreview = { awaitReady: () => new Promise(() => {}), awaitContent: () => new Promise(() => {}) };</script></head>
            <body><p>Never ready</p></body>
            </html>
            """

        private static let options = ExportOptions(pageSize: .a4, margins: .uniform(43), maxPages: 10)

        @Test("past the readiness timeout, the app's renderer draws the page all the same")
        func theAppsRendererDrawsAnyway() async throws {
            let renderer = EnhancedWKWebViewPDFRenderer(pageLoadTimeout: patience, readinessTimeout: .milliseconds(200))

            let data = try await renderer.renderToPDF(html: Self.neverReady, options: Self.options)

            #expect(PDFDocument(data: data)?.string?.contains("Never ready") == true)
        }

        @Test("past the readiness timeout, the tests' renderer fails instead of drawing the page")
        func theTestsRendererFails() async throws {
            let renderer = EnhancedWKWebViewPDFRenderer(
                pageLoadTimeout: patience,
                readinessTimeout: .milliseconds(200),
                onReadinessTimeout: .fail
            )

            await #expect(throws: PDFExportError.self) {
                _ = try await renderer.renderToPDF(html: Self.neverReady, options: Self.options)
            }
        }
    }
}
