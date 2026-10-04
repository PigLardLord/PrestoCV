import Foundation

/// Why `ListDesigns`, `GetDesign`, `SyncBundledDesigns`, `ResolveDesign` and `InstallDesign` fail (R7): a failure of the
/// store or of the bundled source is reported as such, never passed through raw.
public enum DesignCatalogError: Error, Equatable, Sendable {
    /// No installed design has this identifier.
    case unknownDesign(String)
    /// The design store cannot be read or written.
    case storeUnavailable
    /// The bundled designs cannot be read from the app.
    case bundledDesignsUnavailable
    /// An import named the identifier of a bundled design. The design is refused, whatever its version: a CV's design
    /// choice names the identifier, and bundled fixes must reach it.
    case bundledIdentifier(String)
}

/// Installing a design from untrusted bytes: validate, then refuse the identifier of a bundled design, then prove it
/// renders completely, then store it as an import. Nothing is stored unless every check passes.
/// - An import that names the identifier of a bundled design is refused (`DesignCatalogError.bundledIdentifier`),
///   whatever its version: it would shadow the bundled design, and later fixes would never reach a CV that names it.
///   Storing it under another identifier would change what the CV's design choice names. A bundled design is one the
///   source lists and the validator accepts, installed or not.
/// - The source is read after the package is validated, so an invalid package is reported as invalid. A source that cannot
///   be read stops the import (`DesignCatalogError.bundledDesignsUnavailable`), since the identifier cannot be judged.
public struct InstallDesign: Sendable {
    let source: any BundledDesignSource, validator: DesignPackageValidator, gate: any DesignRenderingGate, store: any DesignStore
    public init(source: any BundledDesignSource, validator: DesignPackageValidator = DesignPackageValidator(),
                gate: any DesignRenderingGate, store: any DesignStore) {
        self.source = source; self.validator = validator; self.gate = gate; self.store = store
    }
    public func callAsFunction(_ data: Data) async throws -> ValidatedDesign {
        let design = try validator.validate(data)
        let id = design.manifest.id
        guard try await !bundledIdentifiers().contains(id) else { throw DesignCatalogError.bundledIdentifier(id) }
        try await gate.verify(design)
        try await store.save(design)
        return design
    }

    /// The identifiers of the bundled packages that pass the validator. A package it refuses names nothing.
    private func bundledIdentifiers() async throws -> Set<String> {
        let packages: [(name: String, data: Data)]
        do { packages = try await source.bundledPackages() } catch let cancellation as CancellationError { throw cancellation } catch {
            throw DesignCatalogError.bundledDesignsUnavailable
        }
        var identifiers: Set<String> = []
        for package in packages {
            let design: ValidatedDesign
            do throws(DesignPackageRejected) { design = try validator.validate(package.data) } catch { continue }
            identifiers.insert(design.manifest.id)
        }
        return identifiers
    }
}

/// The installed designs, in the store's order (by identifier).
public struct ListDesigns: Sendable {
    let store: any DesignStore
    public init(store: any DesignStore) { self.store = store }
    public func callAsFunction() async throws(DesignCatalogError) -> [DesignManifest] {
        do { return try await store.installedDesigns() } catch { throw .storeUnavailable }
    }
}

/// One installed design.
public struct GetDesign: Sendable {
    let store: any DesignStore
    public init(store: any DesignStore) { self.store = store }
    public func callAsFunction(id: String) async throws(DesignCatalogError) -> ValidatedDesign {
        let design: ValidatedDesign?
        do { design = try await store.design(id: id) } catch { throw .storeUnavailable }
        guard let design else { throw .unknownDesign(id) }
        return design
    }
}

/// A bundled package that the validator refused, named as the source names it.
public struct RejectedBundledDesign: Equatable, Sendable {
    public let name: String
    public let violations: [DesignPackageViolation]
}

/// What a sync did, as design identifiers in the order the source listed the packages. A package appears in one list
/// only; the same identifier listed twice by the source appears once for each package.
public struct SyncReport: Equatable, Sendable {
    /// Rendered and saved because no design had the identifier.
    public internal(set) var installed: [String] = []
    /// Rendered and saved because the installed design was older.
    public internal(set) var upgraded: [String] = []
    /// Left alone: the installed design has the same or a newer version. It is not rendered, unless it became the same or
    /// newer while this design rendered: then the store kept it (`ConditionalSave.keptInstalled`).
    public internal(set) var unchanged: [String] = []
    /// Not saved: the validator refused the package. These are named as the source names them.
    public internal(set) var rejected: [RejectedBundledDesign] = []
    /// Not saved: the design is valid, but the rendering gate refused it or failed.
    public internal(set) var notRendered: [String] = []
    /// Not saved: the design is valid and rendered, but the store failed to save it.
    public internal(set) var failed: [String] = []
    /// Not saved: the store holds a design with this identifier that the sync did not install, so it is left alone,
    /// whatever the versions. That is an import, or a design with no recorded origin that is not the bundled one (the
    /// same identifier and version). It is not rendered, unless it appeared while this design rendered: then the store
    /// kept it (`ConditionalSave.keptImported`).
    public internal(set) var conflicts: [String] = []
}

/// Brings the designs that ship with the app into the store, at every launch. Each bundled package is validated, then
/// rendered through the gate, then saved, as `InstallDesign` does (R8).
/// - A package whose identifier no installed design has is installed. One newer than the installed design replaces it
///   (upgraded). One of the same or an older version is left alone and not rendered, so a bundled design is never
///   downgraded and the steady state does no rendering and no writing.
/// - The sync replaces only designs it installed itself. The store records each design's origin, and an installed design
///   that an import saved holds its identifier: it is left alone and not rendered, whatever the versions, and the
///   identifier is a `conflict`. A design with no recorded origin, one installed before origins were recorded, counts as
///   bundled only if its version is the bundled design's version exactly (then it is `unchanged`); otherwise it counts
///   as an import.
/// - Rendering takes long, and another caller may save the design meanwhile. So the save is `DesignStore.saveIfNewer`,
///   which compares again under the store's lock, and the report states what the store did: a design the store kept
///   because it became the same or a newer version is `unchanged`, and is never overwritten by the older one. A design
///   that an import saved meanwhile is kept as well, and is a `conflict`: the sync replaces only what it installed.
/// - The installed designs and their recorded origins are listed once, and only their manifests are compared. An installed design is never read, so
///   one whose file is damaged does not stop the sync while the bundled design is unchanged.
/// - A package fails on its own: the validator refuses it (`rejected`), the gate refuses it or fails (`notRendered`), or
///   the store fails to save it (`failed`). The other packages still sync.
/// - What stops the sync: a store that cannot list its designs (`DesignCatalogError.storeUnavailable`), a source that
///   cannot be read (`DesignCatalogError.bundledDesignsUnavailable`), and cancellation. The gate can be cancelled
///   (ADR 0003), so this throws untyped: a `DesignCatalogError`, or a `CancellationError` passed through unchanged.
public struct SyncBundledDesigns: Sendable {
    let source: any BundledDesignSource, validator: DesignPackageValidator, gate: any DesignRenderingGate, store: any DesignStore
    public init(source: any BundledDesignSource, validator: DesignPackageValidator = DesignPackageValidator(),
                gate: any DesignRenderingGate, store: any DesignStore) {
        self.source = source; self.validator = validator; self.gate = gate; self.store = store
    }

    public func callAsFunction() async throws -> SyncReport {
        let packages: [(name: String, data: Data)]
        do { packages = try await source.bundledPackages() } catch { throw DesignCatalogError.bundledDesignsUnavailable }
        var (versions, origins) = try await listInstalled()
        var report = SyncReport()
        for (name, data) in packages {
            let design: ValidatedDesign
            do throws(DesignPackageRejected) { design = try validator.validate(data) } catch {
                report.rejected.append(RejectedBundledDesign(name: name, violations: error.violations))
                continue
            }
            let id = design.manifest.id, version = design.manifest.version
            if let installed = versions[id] {
                switch origins[id] {
                case .bundled?:
                    if version <= installed {
                        report.unchanged.append(id)
                        continue
                    }
                case nil where version == installed:
                    report.unchanged.append(id)
                    continue
                case .imported?, nil:
                    report.conflicts.append(id)
                    continue
                }
            }
            do { try await gate.verify(design) } catch let cancellation as CancellationError { throw cancellation } catch {
                report.notRendered.append(id)
                continue
            }
            let outcome: ConditionalSave
            do { outcome = try await store.saveIfNewer(design) } catch {
                report.failed.append(id)
                continue
            }
            switch outcome {
            case .installed: report.installed.append(id)
            case .upgraded: report.upgraded.append(id)
            case .keptInstalled: report.unchanged.append(id)
            case .keptImported: report.conflicts.append(id)
            }
            origins[id] = outcome == .keptImported ? .imported : .bundled
            versions[id] = max(version, versions[id] ?? version)
        }
        return report
    }

    /// The installed versions and the recorded origins, by identifier.
    private func listInstalled() async throws(DesignCatalogError) -> (versions: [String: DesignVersion], origins: [String: DesignOrigin]) {
        let manifests: [DesignManifest], origins: [String: DesignOrigin]
        do { manifests = try await store.installedDesigns(); origins = try await store.installedOrigins() } catch { throw .storeUnavailable }
        return (Dictionary(manifests.map { ($0.id, $0.version) }, uniquingKeysWith: max), origins)
    }
}

/// What the renderer takes for one design choice.
public struct ResolvedDesign: Equatable, Sendable {
    public let id: String
    public let stylesheet: ValidatedStylesheet
    public let palette: Palette
    public let fonts: FontScheme
}

/// Turns a design choice into a stylesheet, a palette and a font scheme. The choice arrives as raw identifiers, because
/// the catalog does not know the domain that stores it. A palette or font identifier that is missing or unknown falls
/// back to the design's default; a design identifier that is unknown is an error.
public struct ResolveDesign: Sendable {
    let getDesign: GetDesign
    public init(store: any DesignStore) { getDesign = GetDesign(store: store) }

    public func callAsFunction(design: String, palette: String?, fonts: String?) async throws(DesignCatalogError) -> ResolvedDesign {
        let found = try await getDesign(id: design)
        let chosenPalette = palette.flatMap(NamedPalette.init(rawValue:)) ?? found.manifest.defaultPalette
        let chosenFonts = fonts.flatMap(FontScheme.init(rawValue:)) ?? found.manifest.defaultFonts
        return ResolvedDesign(id: found.manifest.id, stylesheet: found.stylesheet, palette: chosenPalette.palette, fonts: chosenFonts)
    }
}
