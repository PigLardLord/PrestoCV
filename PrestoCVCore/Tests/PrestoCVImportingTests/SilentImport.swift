import DiagnosticLogging
import DiagnosticTrace
import PrestoCVImporting

extension ImportCV {
    /// The import of the tests that do not look at its log or its trace.
    init(pdfReader: any PDFTextExtracting, limits: ImportLimits) {
        self.init(pdfReader: pdfReader, limits: limits, logger: SilentLogger(), clock: ContinuousClock(), tracer: NoTracer())
    }
}
