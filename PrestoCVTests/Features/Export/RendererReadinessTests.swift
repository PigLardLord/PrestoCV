import Testing
import Foundation
import PDFKit
@testable import CVPDFExporter

extension RealRendererSuites {
    /// What the iOS renderer does with a page that never says it is ready: the app's renderer draws it all the same,
    /// the tests' renderer fails, and a render cancelled while it waits ends at once.
    @MainActor
    @Suite("The iOS renderer and a page that is never ready", .timeLimit(.minutes(2)))
    struct RendererReadinessTests {

        /// A page whose readiness never comes: it sets the readiness hooks before the renderer's own script can. It keeps
        /// what would resolve them, so that WebKit does not drop the pending promise and end the call on its own.
        private static let neverReady = """
            <!DOCTYPE html>
            <html lang="en">
            <head><script>window.__cvPreview = {
                awaitReady: () => new Promise(resolve => { window.__keptReady = resolve; }),
                awaitContent: () => new Promise(resolve => { window.__keptContent = resolve; })
            };</script></head>
            <body><p>Never ready</p></body>
            </html>
            """

        /// The title a page takes when the renderer starts waiting for it to be ready.
        private static let waitedOn = "Waited on"

        /// The page of `neverReady`, which also says through its title when the renderer starts waiting for it.
        private static let neverReadyAndSaysSo = """
            <!DOCTYPE html>
            <html lang="en">
            <head><script>window.__cvPreview = {
                awaitReady: () => new Promise(resolve => { window.__keptReady = resolve; }),
                awaitContent: () => {
                    document.title = "\(waitedOn)";
                    return new Promise(resolve => { window.__keptContent = resolve; });
                }
            };</script></head>
            <body><p>Never ready</p></body>
            </html>
            """

        private static let options = ExportOptions(pageSize: .a4, margins: .uniform(43), maxPages: 10)

        /// Whether the page of `renderer`'s render says, within `patience`, that the renderer waits for it to be ready.
        private static func waitsForThePage(_ renderer: EnhancedWKWebViewPDFRenderer) async -> Bool {
            let deadline = ContinuousClock.now + patience
            while ContinuousClock.now < deadline {
                if renderer.webView?.title == waitedOn { return true }
                do { try await Task.sleep(for: .milliseconds(10)) } catch { return false }
            }
            return false
        }

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

        @Test("a render cancelled while it waits for the page ends at once in a cancellation, and draws nothing")
        func aRenderCancelledWhileWaitingEndsAtOnce() async throws {
            // A readiness bound longer than the test waits: ending before it means ending with the cancellation
            let renderer = EnhancedWKWebViewPDFRenderer(pageLoadTimeout: patience, readinessTimeout: .seconds(90))
            let render = Task { try await renderer.renderToPDF(html: Self.neverReadyAndSaysSo, options: Self.options) }

            #expect(await Self.waitsForThePage(renderer), "the render did not reach the wait for the page")
            let cancelled = ContinuousClock.now
            render.cancel()
            let result = await render.result

            #expect(throws: CancellationError.self) { _ = try result.get() }
            #expect(ContinuousClock.now - cancelled < patience, "the render should end with the cancellation, not at the readiness bound")
        }
    }
}
