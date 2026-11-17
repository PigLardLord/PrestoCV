import Testing

/// Runs a test that prints PDFs for real while no other such test prints.
///
/// The macOS renderer refuses a third print running in the process (`MacPDFRenderer.Failure.tooManyPrints`, abandoned
/// prints included), and the package's tests run in one process, in parallel: a launch prints the gate's fixture under
/// every bundled design, and an export prints the CV. Three such tests at once made an export fail at random. Every
/// test that prints for real (a `Composition.launch`, an export not cancelled in its pause) takes this trait; a test
/// that only needs a ready composition uses the fake gate instead (`CompositionTests.inputs`).
struct PrintsForReal: TestTrait, TestScoping {
    func provideScope(
        for test: Test, testCase: Test.Case?, performing function: @Sendable () async throws -> Void
    ) async throws {
        try await PrintTurn.shared.taking { try await function() }
    }
}

extension Trait where Self == PrintsForReal {
    /// The test prints PDFs for real: it waits for its turn among the tests that do.
    static var printsForReal: Self { PrintsForReal() }
}

/// One turn at a time, in the order asked.
private actor PrintTurn {
    static let shared = PrintTurn()
    private var taken = false
    private var waiting: [CheckedContinuation<Void, Never>] = []

    func taking(_ work: @Sendable () async throws -> Void) async throws {
        if taken {
            await withCheckedContinuation { waiting.append($0) }
        } else {
            taken = true
        }
        defer {
            if waiting.isEmpty { taken = false } else { waiting.removeFirst().resume() }
        }
        try await work()
    }
}
