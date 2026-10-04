import Foundation
import CVDesignCatalog

/// In-memory `DesignStore` for tests.
public actor InMemoryDesignStore: DesignStore {
    var designs: [String: ValidatedDesign] = [:]
    var origins: [String: DesignOrigin] = [:]
    public init() {}
    public func save(_ design: ValidatedDesign) async throws {
        designs[design.manifest.id] = design
        origins[design.manifest.id] = .imported
    }
    public func saveIfNewer(_ design: ValidatedDesign) async throws -> ConditionalSave {
        let id = design.manifest.id
        guard let installed = designs[id] else { designs[id] = design; origins[id] = .bundled; return .installed }
        guard origins[id] == .bundled else { return .keptImported }
        guard design.manifest.version > installed.manifest.version else { return .keptInstalled }
        designs[id] = design
        return .upgraded
    }
    public func design(id: String) async throws -> ValidatedDesign? { designs[id] }
    public func installedDesigns() async throws -> [DesignManifest] { designs.values.map(\.manifest).sorted { $0.id < $1.id } }
    public func installedOrigins() async throws -> [String: DesignOrigin] { origins }
    public func adoptAsBundled(_ manifest: DesignManifest) async throws -> Bool {
        guard designs[manifest.id]?.manifest.version == manifest.version else { return false }
        switch origins[manifest.id] {
        case .bundled?: return true
        case .imported?: return false
        case nil:
            origins[manifest.id] = .bundled
            return true
        }
    }
}

public struct DesignStoreContractFailure: Error, Equatable, CustomStringConvertible {
    public let description: String
}

/// The behaviour every `DesignStore` adapter shares (R10). `verify` needs an empty store.
public enum DesignStoreContract {
    public static func verify(_ store: any DesignStore) async throws {
        func check(_ holds: Bool, _ rule: String) throws(DesignStoreContractFailure) {
            if !holds { throw DesignStoreContractFailure(description: rule) }
        }
        let clean = try design(id: "clean", preview: true), bold = try design(id: "bold")
        let cleanV2 = try design(id: "clean", version: "2.0.0", css: ".cv-entry-title{font-weight:600}")

        try check(await store.installedDesigns().isEmpty, "an empty store lists no designs")
        try check(await store.design(id: "clean") == nil, "an empty store has no design")
        try check(await store.installedOrigins().isEmpty, "an empty store has no origins")
        try await store.save(clean)
        try check(await store.design(id: "clean") == clean, "a saved design comes back unchanged, preview included")
        try check(await store.installedOrigins() == ["clean": .imported], "a saved design is recorded as imported")
        try await store.save(bold)
        try check(await store.installedDesigns() == [bold.manifest, clean.manifest], "designs are listed by id")
        try await store.save(cleanV2)
        try check(await store.design(id: "clean") == cleanV2, "saving an id again replaces the design")
        try check(await store.installedDesigns() == [bold.manifest, cleanV2.manifest], "a replaced design is listed once")
        for id in ["unknown", "", "../clean", "Clean", "clean\n", "clean/../clean"] {
            try check(await store.design(id: id) == nil, "no design for the identifier \(id.debugDescription)")
        }

        // A conditional save compares and writes in one step, and versions are compared by number.
        let unknown = try design(id: "unknown")
        let first = try design(id: "fresh", version: "1.0.9"), later = try design(id: "fresh", version: "1.0.10", css: ".cv-entry-title{font-weight:600}")
        let sameVersion = try design(id: "fresh", version: "1.0.10", css: ".cv-skill{font-weight:700}")
        try check(await store.saveIfNewer(first) == .installed, "a conditional save of an identifier no design has installs the design")
        try check(await store.design(id: "fresh") == first, "an installed design comes back unchanged")
        try check(await store.saveIfNewer(later) == .upgraded, "a conditional save of a newer version replaces the installed design")
        try check(await store.design(id: "fresh") == later, "an upgraded design comes back unchanged")
        try check(await store.saveIfNewer(sameVersion) == .keptInstalled, "a conditional save of the same version keeps the installed design")
        try check(await store.design(id: "fresh") == later, "a kept design is not replaced")
        try check(await store.saveIfNewer(first) == .keptInstalled, "a conditional save of an older version keeps the installed design")
        try check(await store.design(id: "fresh") == later, "a design is never replaced by an older one")
        try check(await store.installedDesigns() == [bold.manifest, cleanV2.manifest, later.manifest], "a conditional save lists a design once")
        try check(await store.installedOrigins() == ["bold": .imported, "clean": .imported, "fresh": .bundled],
                  "a conditional save records the design as bundled, and an upgrade keeps the origin")

        // A conditional save is the sync's: it never replaces a design that an import saved, whatever its version.
        let mine = try design(id: "mine"), bundledNewer = try design(id: "mine", version: "9.0.0", css: ".cv-skill{font-weight:700}")
        try await store.save(mine)
        try check(await store.saveIfNewer(bundledNewer) == .keptImported, "a conditional save keeps an imported design, even an older one")
        try check(await store.design(id: "mine") == mine, "a kept imported design is not replaced")
        try check(await store.installedOrigins()["mine"] == .imported, "a kept imported design stays imported")

        // Adopting records an installed design as bundled only when its version matches and no import made it.
        try check(await store.adoptAsBundled(mine.manifest) == false, "an imported design is not adopted")
        try check(await store.installedOrigins()["mine"] == .imported, "an imported design stays imported")
        try check(await store.adoptAsBundled(later.manifest) == true, "a design recorded as bundled with the same version counts as adopted")
        try check(await store.adoptAsBundled(first.manifest) == false, "a design of another version is not adopted")
        try check(await store.adoptAsBundled(unknown.manifest) == false, "a design that is not installed is not adopted")
        try check(await store.design(id: "unknown") == nil, "adopting a design that is not installed installs nothing")
        try check(await store.installedOrigins() == ["bold": .imported, "clean": .imported, "fresh": .bundled, "mine": .imported],
                  "adopting changes no origin that is recorded")
    }

    /// A design as the validator accepts it; `preview` adds a PNG preview, which is stored too.
    public static func design(id: String, version: String = "1.0.0", css: String = ".cv-name{color:var(--color-primary)}",
                              preview: Bool = false, defaultPalette: NamedPalette = .ink, defaultFonts: FontScheme = .system) throws -> ValidatedDesign {
        try DesignPackageValidator().validate(package(id: id, version: version, css: css, preview: preview,
                                                      defaultPalette: defaultPalette, defaultFonts: defaultFonts))
    }

    /// The raw bytes of a design package, valid unless the arguments make it invalid.
    public static func package(id: String, version: String = "1.0.0", css: String = ".cv-name{color:var(--color-primary)}",
                               preview: Bool = false, defaultPalette: NamedPalette = .ink, defaultFonts: FontScheme = .system) throws -> Data {
        var object: [String: Any] = [
            "manifest": ["id": id, "name": id, "version": version, "description": "", "defaultPalette": defaultPalette.rawValue,
                         "defaultFonts": defaultFonts.rawValue, "markupContract": MarkupContract.version],
            "cssContent": css,
        ]
        if preview { object["previewImageBase64"] = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x2A]).base64EncodedString() }
        return try JSONSerialization.data(withJSONObject: object)
    }
}
