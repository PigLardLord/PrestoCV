import Testing
import Foundation
import CVDesignCatalog
import CVBundledDesigns
import CVRenderingTestSupport

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

private func bundled(_ id: String, version: String = "1.0.0", css: String = ".cv-name{color:var(--color-primary)}") throws -> (name: String, data: Data) {
    (id, try DesignStoreContract.package(id: id, version: version, css: css))
}

private let otherCSS = ".cv-entry-title{font-weight:600}"

/// A design as an earlier sync installed it: the store records it as bundled.
private func installedBySync(_ design: ValidatedDesign, in store: some DesignStore) async throws {
    _ = try await store.saveIfNewer(design)
}

@Suite("syncing the bundled designs (#125)")
struct SyncBundledDesignsTests {
    // MARK: Installing and upgrading

    @Test("into an empty store every bundled design is rendered and installed, in the order of the source")
    func installsAll() async throws {
        let store = InMemoryDesignStore(), gate = FakeRenderingGate()
        let source = FixedBundledSource(packages: [try bundled("clean"), try bundled("bold")])
        let report = try await SyncBundledDesigns(source: source, gate: gate, store: store)()
        #expect(report.installed == ["clean", "bold"])
        #expect(report.upgraded.isEmpty && report.unchanged.isEmpty && report.rejected.isEmpty && report.notRendered.isEmpty && report.failed.isEmpty)
        #expect(try await store.installedDesigns().map(\.id) == ["bold", "clean"])
        #expect(await gate.verified == ["clean", "bold"])
    }

    @Test("a bundled design newer than the installed one is rendered and replaces it", arguments: [("1.0.0", "1.0.1"), ("1.9.9", "2.0.0"), ("1.0.9", "1.0.10")])
    func upgrades(installed: String, bundledVersion: String) async throws {
        let store = InMemoryDesignStore(), gate = FakeRenderingGate()
        try await installedBySync(DesignStoreContract.design(id: "clean", version: installed), in: store)
        let newer = try bundled("clean", version: bundledVersion, css: otherCSS)
        let report = try await SyncBundledDesigns(source: FixedBundledSource(packages: [newer]), gate: gate, store: store)()
        #expect(report.upgraded == ["clean"])
        #expect(report.installed.isEmpty && report.unchanged.isEmpty && report.rejected.isEmpty && report.notRendered.isEmpty && report.failed.isEmpty)
        let stored = try await GetDesign(store: store)(id: "clean")
        #expect(stored.manifest.version.text == bundledVersion && stored.stylesheet.css == otherCSS)
        #expect(await gate.verified == ["clean"])
    }

    @Test("a bundled design of the same version leaves the installed one alone, and is not rendered")
    func equalVersion() async throws {
        let store = InMemoryDesignStore(), gate = FakeRenderingGate()
        let installed = try DesignStoreContract.design(id: "clean", version: "1.2.3")
        try await installedBySync(installed, in: store)
        let sameVersion = try bundled("clean", version: "1.2.3", css: otherCSS)
        let report = try await SyncBundledDesigns(source: FixedBundledSource(packages: [sameVersion]), gate: gate, store: store)()
        #expect(report.unchanged == ["clean"])
        #expect(report.installed.isEmpty && report.upgraded.isEmpty && report.rejected.isEmpty && report.notRendered.isEmpty && report.failed.isEmpty)
        #expect(try await GetDesign(store: store)(id: "clean") == installed)
        #expect(await gate.verified.isEmpty)
    }

    @Test("a bundled design never downgrades a newer one that is installed as bundled", arguments: [("2.0.0", "1.9.9"), ("1.0.10", "1.0.9"), ("1.10.0", "1.9.0")])
    func neverDowngrades(installed: String, bundledVersion: String) async throws {
        let store = InMemoryDesignStore(), gate = FakeRenderingGate()
        let newer = try DesignStoreContract.design(id: "clean", version: installed)
        try await installedBySync(newer, in: store)
        let older = try bundled("clean", version: bundledVersion, css: otherCSS)
        let report = try await SyncBundledDesigns(source: FixedBundledSource(packages: [older]), gate: gate, store: store)()
        #expect(report.unchanged == ["clean"])
        #expect(report.installed.isEmpty && report.upgraded.isEmpty && report.rejected.isEmpty && report.notRendered.isEmpty && report.failed.isEmpty)
        #expect(try await GetDesign(store: store)(id: "clean") == newer)
        #expect(await gate.verified.isEmpty)
    }

    @Test("a mixed source is reported in the order processed")
    func mixed() async throws {
        let store = InMemoryDesignStore(), gate = FakeRenderingGate()
        for (id, version) in [("b", "1.0.0"), ("c", "1.0.0"), ("d", "2.0.0")] { try await installedBySync(DesignStoreContract.design(id: id, version: version), in: store) }
        let source = FixedBundledSource(packages: [try bundled("a"), try bundled("b", version: "1.1.0"), try bundled("c"), try bundled("d")])
        let report = try await SyncBundledDesigns(source: source, gate: gate, store: store)()
        #expect(report.installed == ["a"] && report.upgraded == ["b"] && report.unchanged == ["c", "d"] && report.rejected.isEmpty)
        #expect(try await store.installedDesigns().map(\.version.text) == ["1.0.0", "1.1.0", "1.0.0", "2.0.0"])
        #expect(await gate.verified == ["a", "b"])
    }

    @Test("the same design twice, the newer second: installed, then upgraded, and the store holds the newer")
    func newerSecond() async throws {
        let store = InMemoryDesignStore(), gate = FakeRenderingGate()
        let source = FixedBundledSource(packages: [try bundled("clean"), try bundled("clean", version: "1.1.0", css: otherCSS)])
        let report = try await SyncBundledDesigns(source: source, gate: gate, store: store)()
        #expect(report.installed == ["clean"] && report.upgraded == ["clean"] && report.unchanged.isEmpty)
        let stored = try await GetDesign(store: store)(id: "clean")
        #expect(stored.manifest.version.text == "1.1.0" && stored.stylesheet.css == otherCSS)
    }

    @Test("the same design twice, the older second: installed, then unchanged, and the store holds the first")
    func olderSecond() async throws {
        let store = InMemoryDesignStore(), gate = FakeRenderingGate()
        let source = FixedBundledSource(packages: [try bundled("clean", version: "1.1.0", css: otherCSS), try bundled("clean")])
        let report = try await SyncBundledDesigns(source: source, gate: gate, store: store)()
        #expect(report.installed == ["clean"] && report.unchanged == ["clean"] && report.upgraded.isEmpty)
        let stored = try await GetDesign(store: store)(id: "clean")
        #expect(stored.manifest.version.text == "1.1.0" && stored.stylesheet.css == otherCSS)
        #expect(await gate.verified == ["clean"])
    }

    @Test("a second sync finds every design unchanged, and saves nothing")
    func steadyState() async throws {
        let store = SpyDesignStore(), gate = FakeRenderingGate()
        let sync = SyncBundledDesigns(source: FixedBundledSource(packages: [try bundled("clean"), try bundled("bold")]), gate: gate, store: store)
        let first = try await sync()
        #expect(first.installed == ["clean", "bold"])
        #expect(await store.savedIDs == ["clean", "bold"])
        #expect(await gate.verified == ["clean", "bold"])
        let second = try await sync()
        #expect(second.unchanged == ["clean", "bold"])
        #expect(second.installed.isEmpty && second.upgraded.isEmpty && second.rejected.isEmpty && second.notRendered.isEmpty && second.failed.isEmpty)
        #expect(await store.savedIDs == ["clean", "bold"])
        #expect(await gate.verified == ["clean", "bold"])
    }

    @Test("a newer design saved while the sync renders is not overwritten by the older bundled design", .timeLimit(.minutes(1)))
    func savedWhileRendering() async throws {
        let store = InMemoryDesignStore(), gate = SuspendingRenderingGate(holding: "clean")
        try await installedBySync(DesignStoreContract.design(id: "clean", version: "1.0.0"), in: store)
        let sync = SyncBundledDesigns(source: FixedBundledSource(packages: [try bundled("clean", version: "2.0.0", css: otherCSS)]), gate: gate, store: store)
        let running = Task { try await sync() }
        guard await gate.waitUntilEntered() else {
            Issue.record("the sync did not reach the rendering gate in time")
            running.cancel()
            return
        }
        let newest = try DesignStoreContract.design(id: "clean", version: "3.0.0", css: ".cv-skill{font-weight:700}")
        try await installedBySync(newest, in: store)
        await gate.release()
        let report = try await running.value
        #expect(report.unchanged == ["clean"])
        #expect(report.upgraded.isEmpty && report.installed.isEmpty && report.failed.isEmpty && report.notRendered.isEmpty)
        #expect(try await GetDesign(store: store)(id: "clean") == newest)
    }

    @Test("an imported design saved while the sync renders is not replaced by the bundled design, and is reported as a conflict", .timeLimit(.minutes(1)))
    func importedWhileRendering() async throws {
        let store = InMemoryDesignStore(), gate = SuspendingRenderingGate(holding: "clean")
        let sync = SyncBundledDesigns(source: FixedBundledSource(packages: [try bundled("clean", version: "2.0.0", css: otherCSS)]), gate: gate, store: store)
        let running = Task { try await sync() }
        guard await gate.waitUntilEntered() else {
            Issue.record("the sync did not reach the rendering gate in time")
            running.cancel()
            return
        }
        let mine = try DesignStoreContract.design(id: "clean", version: "1.0.0")
        try await store.save(mine)
        await gate.release()
        let report = try await running.value
        #expect(report.conflicts == ["clean"])
        #expect(report.installed.isEmpty && report.upgraded.isEmpty && report.unchanged.isEmpty && report.failed.isEmpty && report.notRendered.isEmpty)
        #expect(try await GetDesign(store: store)(id: "clean") == mine)
        #expect(try await store.installedOrigins() == ["clean": .imported])
    }

    @Test("an installed design is listed, never read: one that cannot be read does not stop the sync")
    func unreadableInstalledDesign() async throws {
        let store = SpyDesignStore(installed: [try DesignStoreContract.design(id: "clean")], unreadable: ["clean"])
        let source = FixedBundledSource(packages: [try bundled("clean"), try bundled("bold")])
        let report = try await SyncBundledDesigns(source: source, gate: FakeRenderingGate(), store: store)()
        #expect(report.unchanged == ["clean"] && report.installed == ["bold"])
    }

    // MARK: Designs the sync did not install

    @Test("an imported design that holds a bundled identifier is left alone, not rendered, and reported as a conflict, whatever the versions",
          arguments: ["0.0.1", "1.0.0", "999999999.0.0"])
    func importedIsAConflict(importedVersion: String) async throws {
        let store = InMemoryDesignStore(), gate = FakeRenderingGate()
        let mine = try DesignStoreContract.design(id: "clean", version: importedVersion, css: otherCSS)
        try await store.save(mine)
        let report = try await SyncBundledDesigns(source: FixedBundledSource(packages: [try bundled("clean")]), gate: gate, store: store)()
        #expect(report.conflicts == ["clean"])
        #expect(report.installed.isEmpty && report.upgraded.isEmpty && report.unchanged.isEmpty && report.rejected.isEmpty
                && report.notRendered.isEmpty && report.failed.isEmpty)
        #expect(try await GetDesign(store: store)(id: "clean") == mine)
        #expect(try await store.installedOrigins() == ["clean": .imported])
        #expect(await gate.verified.isEmpty)
    }

    @Test("a design with no recorded origin is the bundled one if its identifier and version match, and an import otherwise",
          arguments: [("1.0.0", false), ("0.9.0", true), ("1.0.1", true), ("2.0.0", true)])
    func unrecordedOrigin(installedVersion: String, isConflict: Bool) async throws {
        let installed = try DesignStoreContract.design(id: "clean", version: installedVersion, css: otherCSS)
        let store = SpyDesignStore(installed: [installed]), gate = FakeRenderingGate()
        let report = try await SyncBundledDesigns(source: FixedBundledSource(packages: [try bundled("clean")]), gate: gate, store: store)()
        #expect(report.conflicts == (isConflict ? ["clean"] : []))
        #expect(report.unchanged == (isConflict ? [] : ["clean"]))
        #expect(report.installed.isEmpty && report.upgraded.isEmpty && report.rejected.isEmpty && report.notRendered.isEmpty && report.failed.isEmpty)
        #expect(try await GetDesign(store: store)(id: "clean") == installed)
        #expect(await store.savedIDs.isEmpty)
        #expect(await gate.verified.isEmpty)
    }

    @Test("a bundled design never replaces an imported one: conflicts are reported in the order processed, the others still sync")
    func importedAmongBundled() async throws {
        let store = InMemoryDesignStore(), gate = FakeRenderingGate()
        try await store.save(DesignStoreContract.design(id: "b", version: "0.0.1"))
        try await installedBySync(DesignStoreContract.design(id: "c", version: "1.0.0"), in: store)
        let source = FixedBundledSource(packages: [try bundled("a"), try bundled("b", version: "2.0.0"), try bundled("c", version: "1.1.0"), try bundled("b")])
        let report = try await SyncBundledDesigns(source: source, gate: gate, store: store)()
        #expect(report.installed == ["a"] && report.upgraded == ["c"] && report.conflicts == ["b", "b"])
        #expect(report.unchanged.isEmpty && report.rejected.isEmpty && report.notRendered.isEmpty && report.failed.isEmpty)
        #expect(try await store.installedDesigns().map(\.version.text) == ["1.0.0", "0.0.1", "1.1.0"])
        #expect(try await store.installedOrigins() == ["a": .bundled, "b": .imported, "c": .bundled])
        #expect(await gate.verified == ["a", "c"])
    }

    // MARK: A package that does not make it

    @Test("a rejected package is reported with its name and violations, and the others still sync")
    func rejectedAmongValid() async throws {
        let store = InMemoryDesignStore(), gate = FakeRenderingGate()
        let broken = (name: "broken-file", data: designData(".cv{}", id: "broken", manifestExtra: ["defaultPalette": "minimal", "version": "1"]))
        let source = FixedBundledSource(packages: [try bundled("clean"), broken, try bundled("bold")])
        let report = try await SyncBundledDesigns(source: source, gate: gate, store: store)()
        #expect(report.installed == ["clean", "bold"])
        #expect(report.rejected.map(\.name) == ["broken-file"])
        #expect(report.rejected.map(\.violations) == [[.invalidVersion("1"), .unknownPalette("minimal")]])
        #expect(try await store.installedDesigns().map(\.id) == ["bold", "clean"])
        #expect(await gate.verified == ["clean", "bold"])
    }

    @Test("the validator given to the use case is the one that judges the packages")
    func customValidator() async throws {
        let store = InMemoryDesignStore(), package = try bundled("clean")
        let report = try await SyncBundledDesigns(source: FixedBundledSource(packages: [package]), validator: DesignPackageValidator(maxBytes: 10),
                                                  gate: FakeRenderingGate(), store: store)()
        #expect(report.rejected.map(\.name) == ["clean"])
        #expect(report.rejected.map(\.violations) == [[.tooLarge(package.data.count)]])
        #expect(try await store.installedDesigns().isEmpty)
    }

    @Test("a design that does not render is reported, not stored, and the others still sync")
    func notRendered() async throws {
        let store = InMemoryDesignStore(), gate = FakeRenderingGate(refusing: ["bold"])
        let source = FixedBundledSource(packages: [try bundled("clean"), try bundled("bold"), try bundled("plain")])
        let report = try await SyncBundledDesigns(source: source, gate: gate, store: store)()
        #expect(report.notRendered == ["bold"] && report.installed == ["clean", "plain"])
        #expect(report.rejected.isEmpty && report.failed.isEmpty && report.upgraded.isEmpty && report.unchanged.isEmpty)
        #expect(try await store.installedDesigns().map(\.id) == ["clean", "plain"])
    }

    @Test("an upgrade that does not render leaves the installed design in place")
    func upgradeNotRendered() async throws {
        let store = InMemoryDesignStore()
        let installed = try DesignStoreContract.design(id: "clean")
        try await installedBySync(installed, in: store)
        let source = FixedBundledSource(packages: [try bundled("clean", version: "1.1.0", css: otherCSS)])
        let report = try await SyncBundledDesigns(source: source, gate: FakeRenderingGate(refusing: ["clean"]), store: store)()
        #expect(report.notRendered == ["clean"] && report.upgraded.isEmpty)
        #expect(try await GetDesign(store: store)(id: "clean") == installed)
    }

    @Test("a cancelled render ends the sync in a cancellation, and what came before stays saved")
    func cancelled() async throws {
        let store = InMemoryDesignStore(), gate = FakeRenderingGate(cancellingOn: ["bold"])
        let source = FixedBundledSource(packages: [try bundled("clean"), try bundled("bold"), try bundled("plain")])
        let sync = SyncBundledDesigns(source: source, gate: gate, store: store)
        await #expect(throws: CancellationError.self) { _ = try await sync() }
        #expect(try await store.installedDesigns().map(\.id) == ["clean"])
        #expect(await gate.verified == ["clean", "bold"])
    }

    @Test("a design the store fails to save is reported, and the others still sync")
    func saveFails() async throws {
        let store = SpyDesignStore(savesFailFor: ["bold"])
        let source = FixedBundledSource(packages: [try bundled("clean"), try bundled("bold"), try bundled("plain")])
        let report = try await SyncBundledDesigns(source: source, gate: FakeRenderingGate(), store: store)()
        #expect(report.failed == ["bold"] && report.installed == ["clean", "plain"])
        #expect(report.rejected.isEmpty && report.notRendered.isEmpty && report.upgraded.isEmpty && report.unchanged.isEmpty)
        #expect(await store.savedIDs == ["clean", "plain"])
    }

    // MARK: What stops the sync

    @Test("a source that cannot be read is reported")
    func sourceUnavailable() async {
        let sync = SyncBundledDesigns(source: FixedBundledSource(packages: nil), gate: FakeRenderingGate(), store: InMemoryDesignStore())
        await #expect(throws: DesignCatalogError.bundledDesignsUnavailable) { _ = try await sync() }
    }

    @Test("a store whose installed designs cannot be listed is unavailable, and nothing is rendered or saved")
    func storeUnavailable() async throws {
        let source = FixedBundledSource(packages: [try bundled("clean")])
        for store in [UnavailableStore(), SpyDesignStore(listingFails: true)] as [any DesignStore] {
            let gate = FakeRenderingGate()
            let sync = SyncBundledDesigns(source: source, gate: gate, store: store)
            await #expect(throws: DesignCatalogError.storeUnavailable) { _ = try await sync() }
            #expect(await gate.verified.isEmpty)
        }
    }

    @Test("today's bundled designs are all rejected, and nothing is rendered or stored (#3 rewrites them)")
    func realBundleToday() async throws {
        let store = InMemoryDesignStore(), gate = FakeRenderingGate()
        let report = try await SyncBundledDesigns(source: BundleDesignSource(), gate: gate, store: store)()
        #expect(report.rejected.map(\.name) == ["minimal", "modern", "professional"])
        #expect(report.rejected.allSatisfy { !$0.violations.isEmpty })
        #expect(report.installed.isEmpty && report.upgraded.isEmpty && report.unchanged.isEmpty && report.notRendered.isEmpty && report.failed.isEmpty)
        #expect(try await store.installedDesigns().isEmpty)
        #expect(await gate.verified.isEmpty)
    }
}

@Suite("importing a design (#127)")
struct InstallDesignTests {
    @Test("an import that takes the identifier of a bundled design is refused, whatever its version: the bundled design stays",
          arguments: ["0.0.1", "1.0.0", "999999999.0.0"])
    func refusedOverBundled(version: String) async throws {
        let store = InMemoryDesignStore(), gate = FakeRenderingGate()
        let source = FixedBundledSource(packages: [try bundled("modern")])
        _ = try await SyncBundledDesigns(source: source, gate: gate, store: store)()
        let bundledModern = try await GetDesign(store: store)(id: "modern")
        let importGate = FakeRenderingGate()
        let install = InstallDesign(source: source, gate: importGate, store: store)
        await #expect(throws: DesignCatalogError.bundledIdentifier("modern")) { _ = try await install(DesignStoreContract.package(id: "modern", version: version, css: otherCSS)) }
        #expect(try await GetDesign(store: store)(id: "modern") == bundledModern)
        #expect(try await store.installedOrigins() == ["modern": .bundled])
        #expect(await importGate.verified.isEmpty)
    }

    @Test("a bundled identifier is refused before the sync has installed the design, and nothing is stored")
    func refusedBeforeTheSync() async throws {
        let store = InMemoryDesignStore(), gate = FakeRenderingGate()
        let install = InstallDesign(source: FixedBundledSource(packages: [try bundled("modern"), try bundled("clean")]), gate: gate, store: store)
        await #expect(throws: DesignCatalogError.bundledIdentifier("clean")) { _ = try await install(DesignStoreContract.package(id: "clean", version: "999999999.0.0")) }
        #expect(try await store.installedDesigns().isEmpty)
        #expect(await gate.verified.isEmpty)
    }

    @Test("an import with an identifier of its own is rendered, stored and recorded as imported")
    func installsImport() async throws {
        let store = InMemoryDesignStore(), gate = FakeRenderingGate()
        let install = InstallDesign(source: FixedBundledSource(packages: [try bundled("modern")]), gate: gate, store: store)
        let design = try await install(DesignStoreContract.package(id: "mine", css: otherCSS))
        #expect(try await GetDesign(store: store)(id: "mine") == design)
        #expect(try await store.installedOrigins() == ["mine": .imported])
        #expect(await gate.verified == ["mine"])
    }

    @Test("a bundled package the validator refuses names no identifier, so an import may take it")
    func refusedBundledPackageReservesNothing() async throws {
        let store = InMemoryDesignStore()
        let broken = (name: "modern", data: designData(".cv{}", id: "modern", manifestExtra: ["version": "1"]))
        let install = InstallDesign(source: FixedBundledSource(packages: [broken]), gate: FakeRenderingGate(), store: store)
        _ = try await install(DesignStoreContract.package(id: "modern"))
        #expect(try await store.installedOrigins() == ["modern": .imported])
    }

    @Test("a bundled source that cannot be read stops the import: nothing is rendered or stored")
    func sourceUnavailable() async throws {
        let store = InMemoryDesignStore(), gate = FakeRenderingGate()
        let install = InstallDesign(source: FixedBundledSource(packages: nil), gate: gate, store: store)
        await #expect(throws: DesignCatalogError.bundledDesignsUnavailable) { _ = try await install(DesignStoreContract.package(id: "mine")) }
        #expect(try await store.installedDesigns().isEmpty)
        #expect(await gate.verified.isEmpty)
    }

    @Test("an invalid package is refused as invalid, before the bundled designs are read")
    func invalidPackage() async throws {
        let install = InstallDesign(source: FixedBundledSource(packages: nil), gate: FakeRenderingGate(), store: InMemoryDesignStore())
        await #expect(throws: DesignPackageRejected.self) { _ = try await install(designData(".cv{display:none}", id: "bad")) }
    }
}
