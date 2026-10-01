import Testing
import Foundation
import CVDesignCatalog
import CVBundledDesigns
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

/// A store that can be read but not written to.
struct ReadOnlyStore: DesignStore {
    struct Failure: Error {}
    func save(_ design: ValidatedDesign) async throws { throw Failure() }
    func design(id: String) async throws -> ValidatedDesign? { nil }
    func installedDesigns() async throws -> [DesignManifest] { [] }
}

/// A bundled source with a fixed list of packages; `nil` is a source that cannot be read.
struct FixedBundledSource: BundledDesignSource {
    struct Unreachable: Error {}
    let packages: [(name: String, data: Data)]?
    func bundledPackages() async throws -> [(name: String, data: Data)] {
        guard let packages else { throw Unreachable() }
        return packages
    }
}

private func bundled(_ id: String, version: String = "1.0.0", css: String = ".cv-name{color:var(--color-primary)}") throws -> (name: String, data: Data) {
    (id, try DesignStoreContract.package(id: id, version: version, css: css))
}

@Suite("syncing the bundled designs (#125)")
struct SyncBundledDesignsTests {
    @Test("into an empty store every bundled design is installed, in the order of the source")
    func installsAll() async throws {
        let store = InMemoryDesignStore()
        let source = FixedBundledSource(packages: [try bundled("clean"), try bundled("bold")])
        let report = try await SyncBundledDesigns(source: source, store: store)()
        #expect(report.installed == ["clean", "bold"])
        #expect(report.upgraded.isEmpty && report.unchanged.isEmpty && report.rejected.isEmpty)
        #expect(try await store.installedDesigns().map(\.id) == ["bold", "clean"])
    }

    @Test("a bundled design newer than the installed one replaces it", arguments: [("1.0.0", "1.0.1"), ("1.9.9", "2.0.0"), ("1.0.9", "1.0.10")])
    func upgrades(installed: String, bundledVersion: String) async throws {
        let store = InMemoryDesignStore()
        try await store.save(DesignStoreContract.design(id: "clean", version: installed))
        let newer = try bundled("clean", version: bundledVersion, css: ".cv-entry-title{font-weight:600}")
        let report = try await SyncBundledDesigns(source: FixedBundledSource(packages: [newer]), store: store)()
        #expect(report.upgraded == ["clean"])
        #expect(report.installed.isEmpty && report.unchanged.isEmpty && report.rejected.isEmpty)
        let stored = try await GetDesign(store: store)(id: "clean")
        #expect(stored.manifest.version == bundledVersion && stored.stylesheet.css == ".cv-entry-title{font-weight:600}")
    }

    @Test("a bundled design of the same version leaves the installed one alone")
    func equalVersion() async throws {
        let store = InMemoryDesignStore()
        let installed = try DesignStoreContract.design(id: "clean", version: "1.2.3", css: ".cv-name{color:var(--color-primary)}")
        try await store.save(installed)
        let sameVersion = try bundled("clean", version: "1.2.3", css: ".cv-entry-title{font-weight:600}")
        let report = try await SyncBundledDesigns(source: FixedBundledSource(packages: [sameVersion]), store: store)()
        #expect(report.unchanged == ["clean"])
        #expect(report.installed.isEmpty && report.upgraded.isEmpty && report.rejected.isEmpty)
        #expect(try await GetDesign(store: store)(id: "clean") == installed)
    }

    @Test("a bundled design never downgrades a newer one installed by other means", arguments: [("2.0.0", "1.9.9"), ("1.0.10", "1.0.9"), ("1.10.0", "1.9.0")])
    func neverDowngrades(installed: String, bundledVersion: String) async throws {
        let store = InMemoryDesignStore()
        let newer = try DesignStoreContract.design(id: "clean", version: installed)
        try await store.save(newer)
        let older = try bundled("clean", version: bundledVersion, css: ".cv-entry-title{font-weight:600}")
        let report = try await SyncBundledDesigns(source: FixedBundledSource(packages: [older]), store: store)()
        #expect(report.unchanged == ["clean"])
        #expect(report.installed.isEmpty && report.upgraded.isEmpty && report.rejected.isEmpty)
        #expect(try await GetDesign(store: store)(id: "clean") == newer)
    }

    @Test("a mixed source is reported in the order processed")
    func mixed() async throws {
        let store = InMemoryDesignStore()
        for (id, version) in [("b", "1.0.0"), ("c", "1.0.0"), ("d", "2.0.0")] { try await store.save(DesignStoreContract.design(id: id, version: version)) }
        let source = FixedBundledSource(packages: [try bundled("a"), try bundled("b", version: "1.1.0"), try bundled("c"), try bundled("d")])
        let report = try await SyncBundledDesigns(source: source, store: store)()
        #expect(report.installed == ["a"] && report.upgraded == ["b"] && report.unchanged == ["c", "d"] && report.rejected.isEmpty)
        #expect(try await store.installedDesigns().map(\.version) == ["1.0.0", "1.1.0", "1.0.0", "2.0.0"])
    }

    @Test("a rejected package is reported with its name and violations, and the others still sync")
    func rejectedAmongValid() async throws {
        let store = InMemoryDesignStore()
        let broken = (name: "broken-file", data: designData(".cv{}", id: "broken", manifestExtra: ["defaultPalette": "minimal", "version": "1"]))
        let source = FixedBundledSource(packages: [try bundled("clean"), broken, try bundled("bold")])
        let report = try await SyncBundledDesigns(source: source, store: store)()
        #expect(report.installed == ["clean", "bold"])
        #expect(report.rejected.map(\.name) == ["broken-file"])
        #expect(report.rejected.map(\.violations) == [[.invalidVersion("1"), .unknownPalette("minimal")]])
        #expect(try await store.installedDesigns().map(\.id) == ["bold", "clean"])
    }

    @Test("the validator given to the use case is the one that judges the packages")
    func customValidator() async throws {
        let store = InMemoryDesignStore()
        let source = FixedBundledSource(packages: [try bundled("clean")])
        let report = try await SyncBundledDesigns(source: source, validator: DesignPackageValidator(maxBytes: 10), store: store)()
        #expect(report.rejected.map(\.name) == ["clean"])
        #expect(report.rejected.flatMap(\.violations).count == 1)
        #expect(try await store.installedDesigns().isEmpty)
    }

    @Test("a source that cannot be read is reported")
    func sourceUnavailable() async {
        let sync = SyncBundledDesigns(source: FixedBundledSource(packages: nil), store: InMemoryDesignStore())
        await #expect(throws: DesignCatalogError.bundledDesignsUnavailable) { _ = try await sync() }
    }

    @Test("a store that cannot be read or written is reported")
    func storeUnavailable() async throws {
        let source = FixedBundledSource(packages: [try bundled("clean")])
        for store in [UnavailableStore(), ReadOnlyStore()] as [any DesignStore] {
            let sync = SyncBundledDesigns(source: source, store: store)
            await #expect(throws: DesignCatalogError.storeUnavailable) { _ = try await sync() }
        }
    }

    @Test("today's bundled designs are all rejected, and nothing is stored (#3 rewrites them)")
    func realBundleToday() async throws {
        let store = InMemoryDesignStore()
        let report = try await SyncBundledDesigns(source: BundleDesignSource(), store: store)()
        #expect(report.rejected.map(\.name) == ["minimal", "modern", "professional"])
        #expect(report.rejected.allSatisfy { !$0.violations.isEmpty })
        #expect(report.installed.isEmpty && report.upgraded.isEmpty && report.unchanged.isEmpty)
        #expect(try await store.installedDesigns().isEmpty)
    }
}
