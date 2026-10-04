import Testing
import PrestoCVCoreTestSupport

@Suite("R10 · application repository contract")
struct ApplicationContractTests {
    @Test("in-memory adapter passes")
    func inMemory() async throws { try await ApplicationRepositoryContract.verify(InMemoryApplicationRepository()) }
}
