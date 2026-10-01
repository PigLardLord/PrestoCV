import Foundation

/// Why a catalog use case failed (R7). A failure of the store is reported as such, never passed through raw.
public enum DesignCatalogError: Error, Equatable, Sendable {
    /// No installed design has this identifier.
    case unknownDesign(String)
    /// The design store cannot be read or written.
    case storeUnavailable
    /// The bundled designs cannot be read from the app.
    case bundledDesignsUnavailable
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

/// What a sync did, as design identifiers in the order the source listed the packages.
public struct SyncReport: Equatable, Sendable {
    /// Saved because no design had the identifier.
    public internal(set) var installed: [String] = []
    /// Saved because the installed design was older.
    public internal(set) var upgraded: [String] = []
    /// Left alone because the installed design has the same or a newer version.
    public internal(set) var unchanged: [String] = []
    /// Not saved: the validator refused the package.
    public internal(set) var rejected: [RejectedBundledDesign] = []
}

/// Brings the designs that ship with the app into the store, at every launch. A bundled design is installed when no
/// design has its identifier and replaces an older installed one; it never replaces one of the same or a newer version,
/// so a design installed by other means is not downgraded. A package the validator rejects is reported and the others
/// still sync.
///
/// No rendering gate runs here, unlike `InstallDesign`: a bundled design is proved by the rendering tests when the app
/// is built, and this runs at every launch.
public struct SyncBundledDesigns: Sendable {
    let source: any BundledDesignSource, validator: DesignPackageValidator, store: any DesignStore
    public init(source: any BundledDesignSource, validator: DesignPackageValidator = DesignPackageValidator(), store: any DesignStore) {
        self.source = source; self.validator = validator; self.store = store
    }

    public func callAsFunction() async throws(DesignCatalogError) -> SyncReport {
        let packages: [(name: String, data: Data)]
        do { packages = try await source.bundledPackages() } catch { throw .bundledDesignsUnavailable }
        var report = SyncReport()
        for (name, data) in packages {
            let design: ValidatedDesign
            do throws(DesignPackageRejected) { design = try validator.validate(data) } catch {
                report.rejected.append(RejectedBundledDesign(name: name, violations: error.violations))
                continue
            }
            let id = design.manifest.id
            let installed: ValidatedDesign?
            do { installed = try await store.design(id: id) } catch { throw .storeUnavailable }
            if let installed, design.version <= installed.version {
                report.unchanged.append(id)
                continue
            }
            do { try await store.save(design) } catch { throw .storeUnavailable }
            if installed == nil { report.installed.append(id) } else { report.upgraded.append(id) }
        }
        return report
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
    let store: any DesignStore
    public init(store: any DesignStore) { self.store = store }

    public func callAsFunction(design: String, palette: String?, fonts: String?) async throws(DesignCatalogError) -> ResolvedDesign {
        let found = try await GetDesign(store: store)(id: design)
        let chosenPalette = palette.flatMap(NamedPalette.init(rawValue:)) ?? found.manifest.defaultPalette
        let chosenFonts = fonts.flatMap(FontScheme.init(rawValue:)) ?? found.manifest.defaultFonts
        return ResolvedDesign(id: found.manifest.id, stylesheet: found.stylesheet, palette: chosenPalette.palette, fonts: chosenFonts)
    }
}
