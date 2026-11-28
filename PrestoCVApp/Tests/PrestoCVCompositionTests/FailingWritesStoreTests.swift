#if DEBUG
import Foundation
import PrestoCVApplication
import PrestoCVCoreTestSupport
import PrestoCVDomain
import Testing
@testable import PrestoCVComposition

/// The store a UI test launches with to see a save fail (#408): the first writes fail with a failed write and store
/// nothing, the writes after them and every read go to the store as it is.
@Suite("The store whose first writes fail")
struct FailingWritesStoreTests {
    private let inner = InMemoryCVRepository()

    private func store(failing count: Int) -> FailingWritesStore {
        FailingWritesStore(inner: inner, count: count)
    }

    private func isWriteFailure(_ error: RepositoryError) -> Bool {
        if case .writeFailed(_, let cause) = error { return cause == FailureCause(domain: .posix, code: 5) }
        return false
    }

    @Test("The first writes fail with a failed write and store nothing, and the next one is stored")
    func firstWritesFailThenSucceed() async throws {
        let store = store(failing: 2)
        let cv = FixtureCV.full()

        for _ in 0..<2 {
            do {
                _ = try await store.create(cv)
                Issue.record("A write that should fail was stored")
            } catch {
                #expect(isWriteFailure(error), "The failure keeps its cause: \(error)")
            }
        }
        await #expect(throws: RepositoryError.notFound(cv.id)) { try await inner.load(cv.id) }

        let created = try await store.create(cv)
        #expect(try await inner.load(cv.id) == created, "The third write is stored")
    }

    @Test("A replacement and a deletion count as writes, and fail while the count lasts")
    func replacementsAndDeletionsFail() async throws {
        let stored = try await inner.create(FixtureCV.full())
        let store = store(failing: 2)

        do { _ = try await store.update(stored); Issue.record("The replacement was stored") } catch {
            #expect(isWriteFailure(error))
        }
        do { try await store.delete(stored.id, revision: stored.revision); Issue.record("The deletion was done") } catch {
            #expect(isWriteFailure(error))
        }
        #expect(try await inner.load(stored.id) == stored, "Nothing changed while the writes failed")

        _ = try await store.update(stored)
        #expect(try await inner.load(stored.id).revision == stored.revision + 1, "The write after the count is stored")
    }

    @Test("A count that never runs out never succeeds")
    func aCountThatNeverRunsOut() async throws {
        let store = store(failing: .max)
        for _ in 0..<5 {
            await #expect(throws: RepositoryError.self) { try await store.create(FixtureCV.full()) }
        }
        #expect(try await inner.list().cvs.isEmpty, "Nothing was stored")
    }

    @Test("A count of none fails nothing, and reads go to the store while writes fail")
    func readsAndAnEmptyCount() async throws {
        let stored = try await inner.create(FixtureCV.full())
        let failing = store(failing: 1)
        #expect(try await failing.load(stored.id) == stored)
        #expect(try await failing.list().cvs.count == 1)
        let none = store(failing: 0)
        _ = try await none.update(stored)
        #expect(try await inner.load(stored.id).revision == stored.revision + 1)
    }
}
#endif
