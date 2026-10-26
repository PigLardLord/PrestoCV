import Testing

/// The suites that print PDFs with the real iOS renderer, one at a time. WebKit loads and prints on the main thread of
/// the one test host: run side by side, renders would wait on each other, and how long each takes would depend on how
/// many ran at once.
@Suite("PDFs from the real renderer", .serialized)
enum RealRendererSuites {}
