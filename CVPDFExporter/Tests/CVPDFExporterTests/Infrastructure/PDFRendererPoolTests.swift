import Testing
import Foundation
@testable import CVPDFExporter

// MARK: - PDF Renderer Pool Tests

@Suite("PDF Renderer Pool")
struct PDFRendererPoolTests {

    private struct BlockFailure: Error {}

    @Test("withRenderer gives the renderer back to the pool once its block has ended")
    func rendererIsBackInThePoolAfterTheBlock() async {
        let pool = PDFRendererPool(maxPoolSize: 1, configuration: .test)

        let wasAvailable = await pool.withRenderer { renderer in renderer.isAvailable }

        #expect(wasAvailable)
        let statistics = await pool.getStatistics()
        #expect(statistics.available == 1)
        #expect(statistics.active == 0)
    }

    @Test("withRenderer gives the renderer back also when its block throws")
    func rendererIsBackInThePoolWhenTheBlockThrows() async {
        let pool = PDFRendererPool(maxPoolSize: 1, configuration: .test)

        await #expect(throws: BlockFailure.self) {
            try await pool.withRenderer { _ in throw BlockFailure() }
        }

        let statistics = await pool.getStatistics()
        #expect(statistics.available == 1)
        #expect(statistics.active == 0)
    }

    @Test("a renderer that was given back is the one handed out next, not a new one")
    func givenBackRendererIsReused() async {
        let pool = PDFRendererPool(maxPoolSize: 1, configuration: .test)

        await pool.withRenderer { _ in }
        await pool.withRenderer { _ in }

        let statistics = await pool.getStatistics()
        #expect(statistics.totalCreated == 1)
        #expect(statistics.reusedCount == 1)
    }
}
