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
    /// A bundled package, named as the source names it, cannot be inspected for its identifier: it is over the validator's
    /// cap, or it is not a design package. Every import is refused: the bundle is the app's own, so this is a defect of the
    /// app, and the package may name any identifier once it is repaired.
    case bundledPackageUninspectable(String)
}

/// Installing a design from untrusted bytes: validate, then refuse the identifier of a bundled design, then prove it
/// renders completely, then store it as an import. Nothing is stored unless every check passes.
/// - An import that names the identifier of a bundled design is refused (`DesignCatalogError.bundledIdentifier`),
///   whatever its version: it would shadow the bundled design, and later fixes would never reach a CV that names it.
///   Storing it under another identifier would change what the CV's design choice names. A bundled identifier is one the
///   source's packages claim, whether or not the validator accepts the package and whether or not the sync has installed
///   the design, and one the store records as bundled, even if the design has left the bundle. The reservation fails
///   closed: a bundled package that cannot be inspected (over the cap, not a design package) may name any identifier once it
///   is repaired, so it stops every import (`DesignCatalogError.bundledPackageUninspectable`).
/// - The checks before rendering are an early out. The store decides at the save, under its lock, and refuses an import
///   over a design it records as bundled (`ImportSave.keptBundled`), which is the same error.
/// - The source is read after the package is validated, so an invalid package is reported as invalid. A source that cannot
///   be read stops the import (`DesignCatalogError.bundledDesignsUnavailable`), and so does a store that cannot list its
///   origins, since the identifier cannot be judged, or that fails to save the design (`DesignCatalogError.storeUnavailable`).
///   A validation or rendering failure passes through as the validator's or the gate's error, and a cancellation unchanged.
public struct InstallDesign: Sendable {
    let source: any BundledDesignSource, validator: DesignPackageValidator, gate: any DesignRenderingGate, store: any DesignStore
    public init(source: any BundledDesignSource, validator: DesignPackageValidator = DesignPackageValidator(),
                gate: any DesignRenderingGate, store: any DesignStore) {
        self.source = source; self.validator = validator; self.gate = gate; self.store = store
    }
    public func callAsFunction(_ data: Data) async throws -> ValidatedDesign {
        let design = try validator.validate(data)
        let id = design.manifest.id
        guard try await !holdsBundledIdentifier(id) else { throw DesignCatalogError.bundledIdentifier(id) }
        try await gate.verify(design)
        let saved: ImportSave
        do { saved = try await store.save(design) } catch let cancellation as CancellationError { throw cancellation } catch {
            throw DesignCatalogError.storeUnavailable
        }
        guard saved == .saved else { throw DesignCatalogError.bundledIdentifier(id) }
        return design
    }

    /// Whether a bundled design has this identifier: one the source lists, or one the store records as bundled.
    private func holdsBundledIdentifier(_ id: String) async throws -> Bool {
        if try await bundledIdentifiers().contains(id) { return true }
        do { return try await store.installedOrigins()[id] == .bundled } catch let cancellation as CancellationError { throw cancellation } catch {
            throw DesignCatalogError.storeUnavailable
        }
    }

    /// The identifiers the bundled packages claim, whether or not the validator accepts them. A package whose manifest
    /// names no valid identifier reserves nothing. One that cannot be inspected stops the import: it fails closed.
    private func bundledIdentifiers() async throws -> Set<String> {
        let packages: [(name: String, data: Data)]
        do { packages = try await source.bundledPackages() } catch let cancellation as CancellationError { throw cancellation } catch {
            throw DesignCatalogError.bundledDesignsUnavailable
        }
        var identifiers: Set<String> = []
        for package in packages {
            switch validator.claimedIdentifier(in: package.data) {
            case .identifier(let id): identifiers.insert(id)
            case .noIdentifier: break
            case .uninspectable: throw DesignCatalogError.bundledPackageUninspectable(package.name)
            }
        }
        return identifiers
    }
}

/// The installed designs, in the store's order (by identifier). A cancellation is passed through (R7); any other failure
/// of the store is `storeUnavailable`.
public struct ListDesigns: Sendable {
    let store: any DesignStore
    public init(store: any DesignStore) { self.store = store }
    public func callAsFunction() async throws -> [DesignManifest] {
        do { return try await store.installedDesigns() } catch is CancellationError { throw CancellationError() } catch { throw DesignCatalogError.storeUnavailable }
    }
}

/// One installed design. A cancellation is passed through (R7); any other failure of the store is `storeUnavailable`.
public struct GetDesign: Sendable {
    let store: any DesignStore
    public init(store: any DesignStore) { self.store = store }
    public func callAsFunction(id: String) async throws -> ValidatedDesign {
        let design: ValidatedDesign?
        do { design = try await store.design(id: id) } catch is CancellationError { throw CancellationError() } catch { throw DesignCatalogError.storeUnavailable }
        guard let design else { throw DesignCatalogError.unknownDesign(id) }
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
    /// Left alone: the installed design, a bundled one, has the same or a newer version. It is not rendered, unless it
    /// became the same or newer while this design rendered: then the store kept it (`ConditionalSave.keptInstalled`).
    public internal(set) var unchanged: [String] = []
    /// Not saved: the validator refused the package. These are named as the source names them.
    public internal(set) var rejected: [RejectedBundledDesign] = []
    /// Not saved: the design is valid, but the rendering gate refused it or failed.
    public internal(set) var notRendered: [String] = []
    /// Not saved: the design is valid and rendered, but the store failed to save it. Also a design the store failed to
    /// adopt.
    public internal(set) var failed: [String] = []
    /// Left alone, and its origin recorded as bundled: it was installed before origins were recorded, and equals this
    /// bundled design (identifier, version and content). From now on the sync upgrades it like any bundled design. Not
    /// rendered.
    public internal(set) var adopted: [String] = []
    /// Not saved: the store holds a design with this identifier that the sync did not install, so it is left alone,
    /// whatever the versions. That is an import, or a design with no recorded origin that is not the bundled one (the same
    /// identifier, version and content), or one the store no longer adopts because an import took it meanwhile. It is
    /// not rendered, unless it appeared while this design rendered: then the store kept it
    /// (`ConditionalSave.keptImported`).
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
///   bundled only if it equals the bundled design (identifier, version and content): the sync adopts it
///   (`DesignStore.adoptAsBundled` compares the two, then records the origin, without rendering) and upgrades it later like
///   any bundled design. Otherwise it counts as an import.
/// - Rendering takes long, and another caller may save the design meanwhile. So the save is `DesignStore.saveIfNewer`,
///   which compares again under the store's lock, and the report states what the store did: a design the store kept
///   because it became the same or a newer version is `unchanged`, and is never overwritten by the older one. A design
///   that an import saved meanwhile is kept as well, and is a `conflict`: the sync replaces only what it installed.
/// - The installed designs and their recorded origins are listed once, and only their manifests are compared. An installed
///   design is never read, so one whose file is damaged does not stop the sync while the bundled design is unchanged. The one
///   exception is a design with no recorded origin and the bundled design's version: the store reads it to adopt it, and
///   a store that cannot reports it as `failed`.
/// - A package fails on its own: the validator refuses it (`rejected`), the gate refuses it or fails (`notRendered`), or
///   the store fails to save it (`failed`). The other packages still sync.
/// - What stops the sync: a store that cannot list its designs (`DesignCatalogError.storeUnavailable`), a source that
///   cannot be read (`DesignCatalogError.bundledDesignsUnavailable`), and cancellation. A cancellation passes through
///   unchanged at every call (the source, the listings, the adoption, the gate and the save), and the designs saved before it
///   stay saved (ADR 0003), so this throws untyped: a `DesignCatalogError`, or a `CancellationError`.
public struct SyncBundledDesigns: Sendable {
    let source: any BundledDesignSource, validator: DesignPackageValidator, gate: any DesignRenderingGate, store: any DesignStore
    public init(source: any BundledDesignSource, validator: DesignPackageValidator = DesignPackageValidator(),
                gate: any DesignRenderingGate, store: any DesignStore) {
        self.source = source; self.validator = validator; self.gate = gate; self.store = store
    }

    public func callAsFunction() async throws -> SyncReport {
        let packages: [(name: String, data: Data)]
        do { packages = try await source.bundledPackages() } catch let cancellation as CancellationError { throw cancellation } catch {
            throw DesignCatalogError.bundledDesignsUnavailable
        }
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
                    do {
                        if try await store.adoptAsBundled(design) {
                            origins[id] = .bundled
                            report.adopted.append(id)
                        } else {
                            report.conflicts.append(id)
                        }
                    } catch let cancellation as CancellationError {
                        throw cancellation
                    } catch {
                        report.failed.append(id)
                    }
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
            do { outcome = try await store.saveIfNewer(design) } catch let cancellation as CancellationError { throw cancellation } catch {
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
    private func listInstalled() async throws -> (versions: [String: DesignVersion], origins: [String: DesignOrigin]) {
        let manifests: [DesignManifest], origins: [String: DesignOrigin]
        do { manifests = try await store.installedDesigns(); origins = try await store.installedOrigins() } catch let cancellation as CancellationError {
            throw cancellation
        } catch {
            throw DesignCatalogError.storeUnavailable
        }
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

    public func callAsFunction(design: String, palette: String?, fonts: String?) async throws -> ResolvedDesign {
        let found = try await getDesign(id: design)
        let chosenPalette = palette.flatMap(NamedPalette.init(rawValue:)) ?? found.manifest.defaultPalette
        let chosenFonts = fonts.flatMap(FontScheme.init(rawValue:)) ?? found.manifest.defaultFonts
        return ResolvedDesign(id: found.manifest.id, stylesheet: found.stylesheet, palette: chosenPalette.palette, fonts: chosenFonts)
    }
}
