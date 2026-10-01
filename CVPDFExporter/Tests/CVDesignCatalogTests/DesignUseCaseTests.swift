import Testing
import Foundation
import CVDesignCatalog
import CVRenderingTestSupport

/// A store that cannot be reached: every operation fails, so the tests can see how the use cases report it (R7).
struct UnavailableStore: DesignStore {
    struct Failure: Error {}
    func save(_ design: ValidatedDesign) async throws { throw Failure() }
    func design(id: String) async throws -> ValidatedDesign? { throw Failure() }
    func installedDesigns() async throws -> [DesignManifest] { throw Failure() }
}

@Suite("listing and getting designs (#125)")
struct ListAndGetDesignTests {
    @Test("an empty store lists no designs")
    func emptyList() async throws {
        #expect(try await ListDesigns(store: InMemoryDesignStore())() == [])
    }

    @Test("the installed designs are listed in the store's order, by identifier")
    func list() async throws {
        let store = InMemoryDesignStore()
        let clean = try DesignStoreContract.design(id: "clean"), bold = try DesignStoreContract.design(id: "bold")
        try await store.save(clean)
        try await store.save(bold)
        #expect(try await ListDesigns(store: store)() == [bold.manifest, clean.manifest])
    }

    @Test("a store that cannot be reached is reported, not listed as empty")
    func listUnavailable() async {
        await #expect(throws: DesignCatalogError.storeUnavailable) { _ = try await ListDesigns(store: UnavailableStore())() }
    }

    @Test("an installed design is returned as it was stored, preview included")
    func get() async throws {
        let store = InMemoryDesignStore()
        let clean = try DesignStoreContract.design(id: "clean", preview: true)
        try await store.save(clean)
        try await store.save(DesignStoreContract.design(id: "bold"))
        #expect(try await GetDesign(store: store)(id: "clean") == clean)
    }

    @Test("an identifier with no design is unknown, whatever it looks like", arguments: ["bold", "", "../clean", "Clean", "clean\n"])
    func getUnknown(id: String) async throws {
        let store = InMemoryDesignStore()
        try await store.save(DesignStoreContract.design(id: "clean"))
        await #expect(throws: DesignCatalogError.unknownDesign(id)) { _ = try await GetDesign(store: store)(id: id) }
    }

    @Test("a store that cannot be reached is reported, not an unknown design")
    func getUnavailable() async {
        await #expect(throws: DesignCatalogError.storeUnavailable) { _ = try await GetDesign(store: UnavailableStore())(id: "clean") }
    }
}
