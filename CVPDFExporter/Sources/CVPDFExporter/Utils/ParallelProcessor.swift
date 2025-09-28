import Foundation

// MARK: - Template Protocol

/// Protocol for renderable templates
public protocol RenderableTemplate: Sendable {
    func render(document: CVDocument, options: ExportOptions) async throws -> String
}

// Make Template conform to RenderableTemplate
extension Template: RenderableTemplate {
    public func render(document: CVDocument, options: ExportOptions) async throws -> String {
        let engine = MustacheTemplateEngine()
        return try await engine.render(template: self, data: document, customization: options.customization)
    }
}

// MARK: - Performance Metrics

/// Metrics for parallel processing performance
public struct ProcessingMetrics: Sendable {
    public let totalTime: TimeInterval
    public let averageTime: TimeInterval
    public let taskCount: Int
    public let successCount: Int
    public let failureCount: Int

    public init(
        totalTime: TimeInterval,
        averageTime: TimeInterval,
        taskCount: Int,
        successCount: Int,
        failureCount: Int
    ) {
        self.totalTime = totalTime
        self.averageTime = averageTime
        self.taskCount = taskCount
        self.successCount = successCount
        self.failureCount = failureCount
    }
}

// MARK: - Parallel Processor

/// Processor for parallel template rendering
/// Sprint 6: Performance optimization
public actor ParallelProcessor {

    private let maxConcurrency: Int
    private let trackPerformance: Bool
    private let cache: TemplateCache?
    private var metrics: ProcessingMetrics?

    public init(
        maxConcurrency: Int = ProcessInfo.processInfo.processorCount,
        trackPerformance: Bool = false,
        cache: TemplateCache? = nil
    ) {
        self.maxConcurrency = max(1, maxConcurrency)
        self.trackPerformance = trackPerformance
        self.cache = cache
    }

    // MARK: - Render All Templates

    /// Render multiple templates concurrently
    public func renderAll(
        templates: [RenderableTemplate],
        document: CVDocument,
        options: ExportOptions,
        skipFailures: Bool = false
    ) async throws -> [String] {
        guard !templates.isEmpty else { return [] }

        // Optimize for single template
        if templates.count == 1 {
            let html = try await templates[0].render(
                document: document,
                options: options
            )
            return [html]
        }

        let startTime = CFAbsoluteTimeGetCurrent()
        var results: [String] = []
        var successCount = 0
        var failureCount = 0

        // Use TaskGroup for concurrent rendering
        try await withThrowingTaskGroup(of: String?.self) { group in
            // Add all tasks
            for template in templates {
                group.addTask {
                    do {
                        return try await template.render(
                            document: document,
                            options: options
                        )
                    } catch {
                        if skipFailures {
                            return nil
                        } else {
                            throw error
                        }
                    }
                }
            }

            // Collect results
            for try await html in group {
                if let html = html {
                    results.append(html)
                    successCount += 1
                } else if skipFailures {
                    failureCount += 1
                }
            }
        }

        // Track metrics if enabled
        if trackPerformance {
            let totalTime = CFAbsoluteTimeGetCurrent() - startTime
            metrics = ProcessingMetrics(
                totalTime: totalTime,
                averageTime: totalTime / Double(templates.count),
                taskCount: templates.count,
                successCount: successCount,
                failureCount: failureCount
            )
        }

        return results
    }

    // MARK: - Batch Processing

    /// Render multiple documents with the same template
    public func renderBatch(
        documents: [CVDocument],
        template: RenderableTemplate,
        options: ExportOptions
    ) async throws -> [String] {
        guard !documents.isEmpty else { return [] }

        let startTime = CFAbsoluteTimeGetCurrent()
        var results: [String] = []

        // Process documents concurrently
        try await withThrowingTaskGroup(of: (Int, String).self) { group in
            // Add all tasks
            for (index, document) in documents.enumerated() {
                group.addTask {
                    let html = try await template.render(
                        document: document,
                        options: options
                    )
                    return (index, html)
                }
            }

            // Collect results in order
            var indexedResults: [(Int, String)] = []
            for try await result in group {
                indexedResults.append(result)
            }

            // Sort by index to maintain order
            indexedResults.sort { $0.0 < $1.0 }
            results = indexedResults.map { $0.1 }
        }

        // Track metrics if enabled
        if trackPerformance {
            let totalTime = CFAbsoluteTimeGetCurrent() - startTime
            metrics = ProcessingMetrics(
                totalTime: totalTime,
                averageTime: totalTime / Double(documents.count),
                taskCount: documents.count,
                successCount: documents.count,
                failureCount: 0
            )
        }

        return results
    }

    // MARK: - Performance Metrics

    /// Get performance metrics from last operation
    public func getPerformanceMetrics() -> ProcessingMetrics? {
        metrics
    }

    /// Clear performance metrics
    public func clearMetrics() async {
        metrics = nil
    }
}