import Testing
import Foundation
@testable import CVPDFExporter

// MARK: - PDF Renderer Factory Tests

@Suite("PDF Renderer Factory")
struct PDFRendererFactoryTests {

    @Test("creates a renderer from a task that is not on the main actor")
    func createsRendererOffTheMainActor() async {
        // When: the factory hops to the main actor itself, instead of trapping when it is not there
        let renderer = await Task.detached {
            await PDFRendererFactory.createRenderer()
        }.value

        // Then
        #expect(renderer.isAvailable)
    }

    @Test("creates a configured renderer from a task that is not on the main actor")
    func createsConfiguredRendererOffTheMainActor() async {
        let renderer = await Task.detached {
            await PDFRendererFactory.createRenderer(configuration: .test)
        }.value

        #expect(renderer.isAvailable)
    }
}
