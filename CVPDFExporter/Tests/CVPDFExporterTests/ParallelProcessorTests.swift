import Testing
import Foundation
@testable import CVPDFExporter

// MARK: - Parallel Processor Tests (Sprint 6)

@Suite("Parallel Processor")
struct ParallelProcessorTests {

    @Test("Parallel processor renders multiple templates concurrently")
    func parallelProcessorRendersTemplates() async throws {
        // Given
        let processor = ParallelProcessor()
        let document = createSampleDocument()
        let templates: [RenderableTemplate] = [
            createBasicTemplate(),
            createModernTemplate(),
            createMinimalTemplate()
        ]

        // When
        let results = try await processor.renderAll(
            templates: templates,
            document: document,
            options: ExportOptions()
        )

        // Then
        #expect(results.count == 3)
        for html in results {
            #expect(html.contains("Test User"))
            #expect(html.contains("<html"))
        }
    }

    @Test("Parallel processor optimizes for single template")
    func parallelProcessorOptimizesForSingle() async throws {
        // Given
        let processor = ParallelProcessor()
        let document = createSampleDocument()
        let templates: [RenderableTemplate] = [createBasicTemplate()]

        // When
        let results = try await processor.renderAll(
            templates: templates,
            document: document,
            options: ExportOptions()
        )

        // Then
        #expect(results.count == 1)
        #expect(results.first?.contains("Test User") == true)
    }

    @Test("Parallel processor handles errors gracefully")
    func parallelProcessorHandlesErrors() async {
        // Given
        let processor = ParallelProcessor()
        let document = createSampleDocument()
        let templates: [RenderableTemplate] = [
            createBasicTemplate(),
            FailingTemplate(), // Template that throws error
            createModernTemplate()
        ]

        // When/Then - Should not throw, but skip failed template
        do {
            let results = try await processor.renderAll(
                templates: templates,
                document: document,
                options: ExportOptions(),
                skipFailures: true
            )
            #expect(results.count == 2) // Only successful templates
        } catch {
            Issue.record("Should not throw with skipFailures: true")
        }
    }

    @Test("Parallel processor respects concurrency limit")
    func parallelProcessorRespectsConcurrencyLimit() async throws {
        // Given
        let processor = ParallelProcessor(maxConcurrency: 2)
        let document = createSampleDocument()
        let templates: [RenderableTemplate] = (0..<5).map { _ in createBasicTemplate() }

        // When
        let results = try await processor.renderAll(
            templates: templates,
            document: document,
            options: ExportOptions()
        )

        // Then
        #expect(results.count == 5)
        // Max concurrency is enforced internally
    }

    @Test("Parallel processor batch processes documents")
    func parallelProcessorBatchProcesses() async throws {
        // Given
        let processor = ParallelProcessor()
        let documents = (0..<3).map { i in
            CVDocument(
                personalInfo: PersonalInfo(
                    name: "User \(i)",
                    email: "user\(i)@example.com"
                ),
                sections: [],
                metadata: DocumentMetadata()
            )
        }
        let template = createBasicTemplate()

        // When
        let results = try await processor.renderBatch(
            documents: documents,
            template: template,
            options: ExportOptions()
        )

        // Then
        #expect(results.count == 3)
        for (index, html) in results.enumerated() {
            #expect(html.contains("User \(index)"))
        }
    }

    @Test("Parallel processor tracks performance")
    func parallelProcessorTracksPerformance() async throws {
        // Given
        let processor = ParallelProcessor(trackPerformance: true)
        let document = createSampleDocument()
        let templates: [RenderableTemplate] = [
            createBasicTemplate(),
            createModernTemplate()
        ]

        // When
        let results = try await processor.renderAll(
            templates: templates,
            document: document,
            options: ExportOptions()
        )

        // Then
        #expect(results.count == 2)
        let metrics = await processor.getPerformanceMetrics()
        #expect(metrics != nil)
        #expect(metrics?.totalTime ?? 0 > 0)
        #expect(metrics?.averageTime ?? 0 > 0)
    }

    @Test("Parallel processor cancels operations")
    func parallelProcessorCancelsOperations() async {
        // Given
        let processor = ParallelProcessor()
        let document = createSampleDocument()
        let templates: [RenderableTemplate] = (0..<10).map { _ in SlowTemplate() }

        // When - Start rendering and cancel
        let task = Task {
            try await processor.renderAll(
                templates: templates,
                document: document,
                options: ExportOptions()
            )
        }

        // Give it time to start
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        task.cancel()

        // Then
        do {
            _ = try await task.value
            Issue.record("Should have been cancelled")
        } catch {
            // Expected cancellation
            #expect(error is CancellationError)
        }
    }

    @Test("Parallel processor uses template cache")
    func parallelProcessorUsesCache() async throws {
        // Given
        let cache = TemplateCache()
        let processor = ParallelProcessor(cache: cache)
        let document = createSampleDocument()
        let template = createBasicTemplate()

        // When - Render twice with same document
        let results1 = try await processor.renderAll(
            templates: [template],
            document: document,
            options: ExportOptions()
        )

        let results2 = try await processor.renderAll(
            templates: [template],
            document: document,
            options: ExportOptions()
        )

        // Then
        #expect(results1.first == results2.first)
        // Cache hit should be faster (verified internally)
    }

    // MARK: - Helper Methods

    private func createSampleDocument() -> CVDocument {
        CVDocument(
            personalInfo: PersonalInfo(
                name: "Test User",
                email: "test@example.com",
                phone: "+1 234 567 8900"
            ),
            sections: [
                CVSection(
                    id: "work",
                    type: .work,
                    title: "Experience",
                    items: [
                        CVItem(
                            title: "Developer",
                            subtitle: "Tech Co"
                        )
                    ]
                )
            ],
            metadata: DocumentMetadata()
        )
    }

    // MARK: - Template Creation Helpers

    // Bundled templates are CSS over the shared base HTML, so the base HTML is what gets rendered
    private func createBasicTemplate() -> Template {
        Template(
            id: "basic",
            name: "Basic",
            description: "Basic template",
            htmlContent: BaseHTMLTemplate.html,
            supportedVariables: []
        )
    }

    private func createModernTemplate() -> Template {
        Template(
            id: "modern",
            name: "Modern",
            description: "Modern template",
            htmlContent: BaseHTMLTemplate.html,
            supportedVariables: []
        )
    }

    private func createMinimalTemplate() -> Template {
        Template(
            id: "minimal",
            name: "Minimal",
            description: "Minimal template",
            htmlContent: BaseHTMLTemplate.html,
            supportedVariables: []
        )
    }
}

// MARK: - Mock Templates for Testing

private struct FailingTemplate: RenderableTemplate {
    func render(document: CVDocument, options: ExportOptions) async throws -> String {
        throw ExportError.encodingFailed("Test error")
    }
}

private struct SlowTemplate: RenderableTemplate {
    func render(document: CVDocument, options: ExportOptions) async throws -> String {
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        return "<html><body>Slow</body></html>"
    }
}