@testable import CVGeneratorAI
import DiagnosticLogging
import DiagnosticTrace
import Foundation
import PrestoCVImporting
import Synchronization

// The import and the AI draft take the logger they write to and the trace they record into in their initialisers (ADR 0030,
// ADR 0032). The tests that do not look at the log give them one that logs nothing, and a trace that records nothing; the
// tests that do give them a `LogSpy`.

extension ImportCV {
    /// The import of the tests that do not look at its log.
    init(pdfReader: any PDFTextExtracting, limits: ImportLimits) {
        self.init(pdfReader: pdfReader, limits: limits, logger: SilentLogger(), clock: ContinuousClock(), tracer: NoTracer())
    }
}

extension CVGeneratorUseCase {
    /// A use case that logs nothing, for the tests that are not about the log, with every time limit on a test clock (#413).
    convenience init(service: CVGenerationService, claimChecker: ClaimChecking, sanitizer: CVDataSanitizer = CVDataSanitizer()) {
        self.init(
            service: service, claimChecker: claimChecker, logger: SilentLogger(), clock: ContinuousClock(), tracer: NoTracer(),
            validator: DefaultCVValidator(), sanitizer: sanitizer, limits: .onTestClock()
        )
    }
}

/// Keeps the lines written to it, in order, so that a test can read the events that reached the log.
final class LogSpy: DiagnosticLogger {
    private let written = Mutex<[LogEntry]>([])

    func log(_ entry: LogEntry) {
        written.withLock { $0.append(entry) }
    }

    /// Every entry written, in order
    var entries: [LogEntry] {
        written.withLock { $0 }
    }

    /// The events written, in order
    var events: [String] {
        written.withLock { $0.map { $0.event.description } }
    }

    /// Every line written, in order
    var lines: [String] {
        written.withLock { $0.map(\.line) }
    }
}

extension DraftingLimits {
    /// The app's times on a clock that ends them only when a test says so: a draft of a test never runs out of time on a busy
    /// machine (#413). The package's tests have the same in `TestCallClock`; a test target cannot import another's files.
    static func onTestClock() -> DraftingLimits {
        let clock = IdleClock()
        return DraftingLimits(
            extraction: .seconds(90), section: .seconds(30),
            claimCheck: ClaimCheckLimits(batchSize: ClaimCheckLimits.standard.batchSize, time: ClaimCheckLimits.standard.time, on: clock),
            on: clock
        )
    }
}

/// A clock whose sleeps end only when their task is cancelled: a limit on it never runs out, however busy the machine is.
private struct IdleClock: Clock {
    typealias Instant = ContinuousClock.Instant

    var now: Instant { .now }
    var minimumResolution: Duration { .zero }

    func sleep(until deadline: Instant, tolerance: Duration?) async throws {
        try await Task.sleep(for: .seconds(1_000_000_000))
    }
}
