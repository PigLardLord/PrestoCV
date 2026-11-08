/// The writes one autosave runs through its writer: the editor waits for the one that runs before it reads the store
/// again, and an autosave it replaced can start none.
@MainActor
final class WritesInFlight {

    /// Thrown to the autosave that was replaced. It is no cancellation, which the autosave would retry after a pause, and
    /// the editor ignores the failure of an autosave it replaced.
    struct Replaced: Error {}

    private var running = 0
    private var isReplaced = false
    private var waiting: [CheckedContinuation<Void, Never>] = []

    /// Runs `write`, unless the autosave was replaced.
    func run(_ write: () async throws -> Void) async throws {
        guard !isReplaced else { throw Replaced() }
        running += 1
        defer {
            running -= 1
            if running == 0 {
                let released = waiting
                waiting = []
                released.forEach { $0.resume() }
            }
        }
        try await write()
    }

    /// Returns once no write runs.
    func untilIdle() async {
        guard running > 0 else { return }
        await withCheckedContinuation { waiting.append($0) }
    }

    /// From now on no write starts. The one that runs ends on its own.
    func replace() { isReplaced = true }
}
