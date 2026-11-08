import Testing
import PrestoCVCoreTestSupport

@Suite("The repository the editing tests use")
struct FakeRepositoryContractTests {
    @Test("the repository with failure injection passes the contract that the file repository passes")
    func spyPassesTheContract() async throws {
        try await CVRepositoryContract.verify(RepositorySpy())
    }
}
