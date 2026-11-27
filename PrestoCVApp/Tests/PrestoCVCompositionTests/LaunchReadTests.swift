import CVRendering
import Foundation
import Synchronization
import Testing
@testable import PrestoCVComposition

/// A heading source that holds no table, and records for each read whether it ran on the main actor.
private final class ThreadRecordingHeadings: HeadingTableSource {
    struct NoTable: Error {}
    private let threads = Mutex<[Bool]>([])

    /// For each read, whether it ran on the main actor.
    var readOnTheMainActor: [Bool] { threads.withLock { $0 } }

    func index() throws -> Data {
        record()
        throw NoTable()
    }

    func table(_ tag: String) throws -> Data? {
        record()
        throw NoTable()
    }

    private func record() {
        let onMainActor = MainActorProbe.isOnTheMainActor
        threads.withLock { $0.append(onMainActor) }
    }
}

@Suite("The launch's reads")
struct LaunchReadTests {
    @MainActor
    @Test("the heading tables are read off the main actor, while the app shows that it is loading (R19)")
    func headingsAreReadOffTheMainActor() async {
        let source = ThreadRecordingHeadings()

        await #expect(throws: CompositionFailure.self) {
            _ = try await Composition.read(HeadingsCatalog(source: source), gate: "en")
        }

        #expect(source.readOnTheMainActor == [false])
    }
}
