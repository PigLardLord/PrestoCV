import Foundation

// MARK: - Performance Measurement

/// A measurement result from performance monitoring
public struct PerformanceMeasurement: Sendable {
    public let label: String
    public let duration: TimeInterval
    public let memoryBefore: Int?
    public let memoryAfter: Int?
    public let timestamp: Date

    public init(
        label: String,
        duration: TimeInterval,
        memoryBefore: Int? = nil,
        memoryAfter: Int? = nil,
        timestamp: Date = Date()
    ) {
        self.label = label
        self.duration = duration
        self.memoryBefore = memoryBefore
        self.memoryAfter = memoryAfter
        self.timestamp = timestamp
    }
}

/// Statistics for a set of measurements
public struct PerformanceStatistics: Sendable {
    public let count: Int
    public let average: TimeInterval
    public let min: TimeInterval
    public let max: TimeInterval
    public let total: TimeInterval

    public init(measurements: [PerformanceMeasurement]) {
        self.count = measurements.count
        let durations = measurements.map { $0.duration }
        self.total = durations.reduce(0, +)
        self.average = count > 0 ? total / Double(count) : 0
        self.min = durations.min() ?? 0
        self.max = durations.max() ?? 0
    }
}

/// Alert result for threshold monitoring
public struct ThresholdAlert: Sendable {
    public let exceeded: Bool
    public let duration: TimeInterval
    public let threshold: TimeInterval

    public init(exceeded: Bool, duration: TimeInterval, threshold: TimeInterval) {
        self.exceeded = exceeded
        self.duration = duration
        self.threshold = threshold
    }
}

/// Performance metrics for export
public struct PerformanceMetrics: Codable, Sendable {
    public let measurements: [ExportableMeasurement]
    public let statistics: [String: StatisticsSummary]

    public var averageTime: TimeInterval {
        guard !measurements.isEmpty else { return 0 }
        let total = measurements.reduce(0) { $0 + $1.duration }
        return total / Double(measurements.count)
    }

    public struct ExportableMeasurement: Codable, Sendable {
        public let label: String
        public let duration: TimeInterval
        public let timestamp: Date
        public let memoryBefore: Int?
        public let memoryAfter: Int?
    }

    public struct StatisticsSummary: Codable, Sendable {
        public let count: Int
        public let average: TimeInterval
        public let min: TimeInterval
        public let max: TimeInterval
    }
}

// MARK: - Performance Monitor

/// Monitor for tracking performance metrics
/// Sprint 6: Performance optimization
public actor PerformanceMonitor {

    private var measurements: [PerformanceMeasurement] = []
    private var thresholds: [String: TimeInterval] = [:]
    private var activeMeasurements: [UUID: (label: String, start: TimeInterval, memoryBefore: Int?)] = [:]
    private let now: @Sendable () -> TimeInterval

    /// - Parameter now: The clock durations are measured on, in seconds.
    public init(now: @escaping @Sendable () -> TimeInterval = { CFAbsoluteTimeGetCurrent() }) {
        self.now = now
    }

    // MARK: - Public Properties

    /// Get the last measurement
    public var lastMeasurement: PerformanceMeasurement? {
        measurements.last
    }

    // MARK: - Measurement Methods

    /// Measure the execution time of a closure
    public func measure<T>(
        label: String,
        operation: () async throws -> T
    ) async rethrows -> T {
        let start = now()
        let result = try await operation()
        let duration = now() - start

        let measurement = PerformanceMeasurement(
            label: label,
            duration: duration
        )
        measurements.append(measurement)

        return result
    }

    /// Measure execution time with memory tracking
    public func measureWithMemory<T>(
        label: String,
        operation: () async throws -> T
    ) async rethrows -> T {
        let memoryBefore = getCurrentMemoryUsage()
        let start = now()
        let result = try await operation()
        let duration = now() - start
        let memoryAfter = getCurrentMemoryUsage()

        let measurement = PerformanceMeasurement(
            label: label,
            duration: duration,
            memoryBefore: memoryBefore,
            memoryAfter: memoryAfter
        )
        measurements.append(measurement)

        return result
    }

    /// Measure with threshold alert
    public func measureWithAlert<T>(
        label: String,
        operation: () async throws -> T
    ) async rethrows -> (result: T, alert: ThresholdAlert) {
        let start = now()
        let result = try await operation()
        let duration = now() - start

        let measurement = PerformanceMeasurement(
            label: label,
            duration: duration
        )
        measurements.append(measurement)

        let threshold = thresholds[label] ?? Double.infinity
        let alert = ThresholdAlert(
            exceeded: duration > threshold,
            duration: duration,
            threshold: threshold
        )

        return (result, alert)
    }

    /// Begin a measurement for manual lifecycle control.
    public func startMeasurement(operation: String, trackMemory: Bool = false) -> UUID {
        let id = UUID()
        let memory = trackMemory ? getCurrentMemoryUsage() : nil
        activeMeasurements[id] = (label: operation, start: now(), memoryBefore: memory)
        return id
    }

    /// Complete a previously started measurement and record it.
    public func endMeasurement(id: UUID) {
        guard let active = activeMeasurements.removeValue(forKey: id) else { return }

        let duration = now() - active.start
        let measurement = PerformanceMeasurement(
            label: active.label,
            duration: duration,
            memoryBefore: active.memoryBefore,
            memoryAfter: active.memoryBefore == nil ? nil : getCurrentMemoryUsage()
        )
        measurements.append(measurement)
    }

    /// Aggregate metrics for all recorded measurements.
    public func getMetrics() -> PerformanceMetrics {
        let exportableMeasurements = measurements.map { measurement in
            PerformanceMetrics.ExportableMeasurement(
                label: measurement.label,
                duration: measurement.duration,
                timestamp: measurement.timestamp,
                memoryBefore: measurement.memoryBefore,
                memoryAfter: measurement.memoryAfter
            )
        }

        let grouped = Dictionary(grouping: measurements) { $0.label }
        let statistics = grouped.mapValues { measurements -> PerformanceMetrics.StatisticsSummary in
            let stats = PerformanceStatistics(measurements: measurements)
            return PerformanceMetrics.StatisticsSummary(
                count: stats.count,
                average: stats.average,
                min: stats.min,
                max: stats.max
            )
        }

        return PerformanceMetrics(
            measurements: exportableMeasurements,
            statistics: statistics
        )
    }

    // MARK: - Statistics

    /// Get statistics for a specific label
    public func getStatistics(for label: String) -> PerformanceStatistics? {
        let filtered = measurements.filter { $0.label == label }
        guard !filtered.isEmpty else { return nil }
        return PerformanceStatistics(measurements: filtered)
    }

    /// Generate a performance report
    public func generateReport() -> String {
        var report = "Performance Report\n"
        report += "==================\n\n"

        // Group measurements by label
        let grouped = Dictionary(grouping: measurements) { $0.label }

        for (label, measurements) in grouped.sorted(by: { $0.key < $1.key }) {
            let stats = PerformanceStatistics(measurements: measurements)
            report += "Task: \(label)\n"
            report += "  Count: \(stats.count)\n"
            report += "  Average: \(String(format: "%.4f", stats.average))s\n"
            report += "  Min: \(String(format: "%.4f", stats.min))s\n"
            report += "  Max: \(String(format: "%.4f", stats.max))s\n"
            report += "  Total: \(String(format: "%.4f", stats.total))s\n\n"
        }

        return report
    }

    // MARK: - Threshold Management

    /// Set a performance threshold for a label
    public func setThreshold(for label: String, threshold: TimeInterval) {
        thresholds[label] = threshold
    }

    /// Get the threshold for a label
    public func getThreshold(for label: String) -> TimeInterval? {
        thresholds[label]
    }

    // MARK: - Export

    /// Export metrics as JSON data
    public func exportMetrics() throws -> Data {
        let exportableMeasurements = measurements.map { measurement in
            PerformanceMetrics.ExportableMeasurement(
                label: measurement.label,
                duration: measurement.duration,
                timestamp: measurement.timestamp,
                memoryBefore: measurement.memoryBefore,
                memoryAfter: measurement.memoryAfter
            )
        }

        let grouped = Dictionary(grouping: measurements) { $0.label }
        let statistics = grouped.mapValues { measurements in
            let stats = PerformanceStatistics(measurements: measurements)
            return PerformanceMetrics.StatisticsSummary(
                count: stats.count,
                average: stats.average,
                min: stats.min,
                max: stats.max
            )
        }

        let metrics = PerformanceMetrics(
            measurements: exportableMeasurements,
            statistics: statistics
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(metrics)
    }

    // MARK: - Clear

    /// Clear all measurements and thresholds
    public func clear() {
        measurements.removeAll()
        thresholds.removeAll()
    }

    // MARK: - Private Helpers

    private func getCurrentMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }

        return result == KERN_SUCCESS ? Int(info.resident_size) : 0
    }
}
