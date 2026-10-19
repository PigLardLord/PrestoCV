import Testing
import Foundation
@testable import CVPDFExporter

// MARK: - Performance Monitor Tests (Sprint 6)

@Suite("Performance Monitor")
struct PerformanceMonitorTests {

    @Test("Performance monitor tracks execution time")
    func performanceMonitorTracksTime() async {
        // Given
        let clock = ManualClock()
        let monitor = PerformanceMonitor(now: clock.now)

        // When
        let result = await monitor.measure(label: "test") {
            // Work that takes a quarter of a second
            clock.advance(by: 0.25)
            return "completed"
        }

        // Then
        #expect(result == "completed")
        #expect(await monitor.lastMeasurement?.label == "test")
        #expect(await monitor.lastMeasurement?.duration == 0.25)
    }

    @Test("Performance monitor calculates statistics")
    func performanceMonitorCalculatesStats() async {
        // Given
        let clock = ManualClock()
        let monitor = PerformanceMonitor(now: clock.now)

        // When - perform multiple measurements, the i-th taking i eighths of a second
        for i in 1...5 {
            _ = await monitor.measure(label: "operation") {
                clock.advance(by: Double(i) / 8)
                return i
            }
        }

        // Then
        let stats = await monitor.getStatistics(for: "operation")
        #expect(stats != nil)
        #expect(stats?.count == 5)
        #expect(stats?.average == 0.375)
        #expect(stats?.min == 0.125)
        #expect(stats?.max == 0.625)
    }

    @Test("Performance monitor tracks memory usage")
    func performanceMonitorTracksMemory() async {
        // Given
        let monitor = PerformanceMonitor()

        // When
        _ = await monitor.measureWithMemory(label: "memory-test") {
            // Allocate some memory
            var array: [Int] = []
            for i in 0..<10000 {
                array.append(i)
            }
            return array.count
        }

        // Then
        #expect(await monitor.lastMeasurement?.label == "memory-test")
        #expect(await monitor.lastMeasurement?.memoryBefore != nil)
        #expect(await monitor.lastMeasurement?.memoryAfter != nil)
    }

    @Test("Performance monitor generates report")
    func performanceMonitorGeneratesReport() async {
        // Given
        let monitor = PerformanceMonitor()

        // When
        _ = await monitor.measure(label: "task1") { "result1" }
        _ = await monitor.measure(label: "task2") { "result2" }
        _ = await monitor.measure(label: "task1") { "result1-2" }

        let report = await monitor.generateReport()

        // Then
        #expect(report.contains("Performance Report"))
        #expect(report.contains("task1"))
        #expect(report.contains("task2"))
        #expect(report.contains("Average"))
    }

    @Test("Performance monitor clears measurements")
    func performanceMonitorClearsMeasurements() async {
        // Given
        let monitor = PerformanceMonitor()

        // When
        _ = await monitor.measure(label: "test") { "result" }
        #expect(await monitor.lastMeasurement != nil)

        await monitor.clear()

        // Then
        #expect(await monitor.lastMeasurement == nil)
        #expect(await monitor.getStatistics(for: "test") == nil)
    }

    @Test("Performance monitor threshold alerts")
    func performanceMonitorThresholdAlerts() async {
        // Given
        let clock = ManualClock()
        let monitor = PerformanceMonitor(now: clock.now)
        await monitor.setThreshold(for: "slow-task", threshold: 0.125)

        // When - perform an operation that takes longer than the threshold
        let (_, alert) = await monitor.measureWithAlert(label: "slow-task") {
            clock.advance(by: 0.25)
            return "slow"
        }

        // Then
        #expect(alert.exceeded == true)
        #expect(alert.duration == 0.25)
    }

    @Test("Performance monitor exports metrics")
    func performanceMonitorExportsMetrics() async throws {
        // Given
        let monitor = PerformanceMonitor()

        // When
        _ = await monitor.measure(label: "export-test") { "data" }
        let metrics = try await monitor.exportMetrics()

        // Then
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(
            PerformanceMetrics.self,
            from: metrics
        )
        #expect(decoded.measurements.count > 0)
    }

    @Test("Performance monitor is thread safe")
    func performanceMonitorIsThreadSafe() async {
        // Given
        let monitor = PerformanceMonitor()

        // When - concurrent measurements
        await withTaskGroup(of: String.self) { group in
            for i in 0..<10 {
                group.addTask {
                    await monitor.measure(label: "concurrent-\(i)") {
                        "result-\(i)"
                    }
                }
            }
        }

        // Then
        let report = await monitor.generateReport()
        #expect(report.contains("concurrent"))
    }
}