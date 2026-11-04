#if canImport(PDFKit)
import DiagnosticLogging
import DiagnosticTrace
import PrestoCVImporting
import PrestoCVImportingPDFKit

extension PDFKitTextExtractor {
    /// The reader of the tests that do not look at its log.
    init() {
        self.init(logger: SilentLogger())
    }
}

extension ImportCV {
    /// The import of the tests that do not look at its log or its trace.
    init(pdfReader: any PDFTextExtracting, limits: ImportLimits) {
        self.init(pdfReader: pdfReader, limits: limits, logger: SilentLogger(), clock: ContinuousClock(), tracer: NoTracer())
    }
}
#endif
