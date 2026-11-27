#if DEBUG
import Foundation
import PrestoCVApplication
import PrestoCVCoreTestSupport
import PrestoCVDomain
import PrestoCVIntegration
import PrestoCVWorkflowPorts
import Testing
@testable import PrestoCVComposition

/// The store a UI test launches with to see what another window did to the open CV (#402): the first write of a stored CV
/// meets the other window's change, and every other call goes to the store as it is.
@Suite("The store another window changes once")
struct OtherWindowStoreTests {
    /// The store the fixture wraps, with one CV in it, and the editing over the wrapped store.
    private struct World {
        let inner = InMemoryCVRepository()
        let editing: EditCVWorkflow
        let stored: CV

        init(_ change: LaunchFixtures.OtherWindow) async throws {
            stored = try await inner.create(FixtureCV.full())
            editing = EditCVWorkflow(repository: OtherWindowStore(inner: inner, change: change), ids: SequentialIDGenerator())
        }

        /// The stored CV with a new title: a change the editor would write.
        func renamed(_ cv: CV, _ title: String) -> CV {
            var changed = cv
            changed.rename(title)
            return changed
        }
    }

    @Test("Another window's save meets the first write of a stored CV as a conflict, and a write after a reload is stored")
    func conflictOnTheFirstWrite() async throws {
        let world = try await World(.conflict)

        await #expect(throws: EditFailure.conflict(storedRevision: world.stored.revision + 1)) {
            try await world.editing.save(world.renamed(world.stored, "Backend"))
        }

        let reloaded = try await world.editing.load(world.stored.id)
        let saved = try await world.editing.save(world.renamed(reloaded, "Backend"))
        #expect(try await world.inner.load(world.stored.id).title == "Backend")
        _ = try await world.editing.save(world.renamed(saved, "Platform"))
        #expect(try await world.inner.load(world.stored.id).title == "Platform", "the other window changes the CV once")
    }

    @Test("Another window's deletion meets the first write of a stored CV as deleted elsewhere")
    func deletedOnTheFirstWrite() async throws {
        let world = try await World(.deleted)

        await #expect(throws: EditFailure.deletedElsewhere) {
            try await world.editing.save(world.renamed(world.stored, "Backend"))
        }

        await #expect(throws: RepositoryError.notFound(world.stored.id)) { try await world.inner.load(world.stored.id) }
    }

    @Test("A new CV's first write, the reads and a deletion go to the store as they are, before the change and after it")
    func otherCallsPassThrough() async throws {
        let world = try await World(.conflict)
        let fresh = FixtureCV.full(id: CVID(UUID(uuidString: "22222222-2222-2222-2222-222222222222")!))
        let created = try await world.editing.save(world.renamed(fresh, "New"))
        #expect(try await world.inner.load(created.id).title == "New", "a new CV is no other window's: it is stored")
        #expect(try await world.editing.load(world.stored.id) == world.stored)

        await #expect(throws: EditFailure.conflict(storedRevision: created.revision + 1)) {
            try await world.editing.save(world.renamed(created, "Changed"))
        }

        let moved = try await world.editing.load(created.id)
        try await world.editing.delete(moved)
        await #expect(throws: RepositoryError.notFound(created.id)) { try await world.inner.load(created.id) }
        #expect(try await world.inner.load(world.stored.id) == world.stored, "the other window changed only the CV written first")
    }
}
#endif
