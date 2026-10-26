import CVGeneratorAI
import DiagnosticLogging
import Foundation
import PrestoCVImporting
import Synchronization

// The import and the AI draft take the logger they write to in their initialisers (ADR 0030). The tests that do not
// look at the log give them one that logs nothing; the tests that do give them a `LogSpy`.

extension ImportCV {
    /// The import of the tests that do not look at its log.
    init(pdfReader: any PDFTextExtracting, limits: ImportLimits) {
        self.init(pdfReader: pdfReader, limits: limits, logger: SilentLogger(), clock: ContinuousClock())
    }
}

extension CVGeneratorUseCase {
    /// A use case that logs nothing, for the tests that are not about the log.
    convenience init(service: CVGenerationService, claimChecker: ClaimChecking, sanitizer: CVDataSanitizer = CVDataSanitizer()) {
        self.init(service: service, claimChecker: claimChecker, logger: SilentLogger(), clock: ContinuousClock(), sanitizer: sanitizer)
    }
}

/// Keeps the lines written to it, in order, so that a test can read the events that reached the log.
final class LogSpy: DiagnosticLogger {
    private let written = Mutex<[LogEntry]>([])

    func log(_ entry: LogEntry) {
        written.withLock { $0.append(entry) }
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
