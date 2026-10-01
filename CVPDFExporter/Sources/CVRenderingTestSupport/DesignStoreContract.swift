import Foundation
import CVDesignCatalog

/// In-memory `DesignStore` for tests.
public actor InMemoryDesignStore: DesignStore {
    var designs: [String: ValidatedDesign] = [:]
    public init() {}
    public func save(_ design: ValidatedDesign) async throws { designs[design.manifest.id] = design }
    public func saveIfNewer(_ design: ValidatedDesign) async throws -> ConditionalSave {
        let id = design.manifest.id
        guard let installed = designs[id] else { designs[id] = design; return .installed }
        guard design.manifest.version > installed.manifest.version else { return .keptInstalled }
        designs[id] = design
        return .upgraded
    }
    public func design(id: String) async throws -> ValidatedDesign? { designs[id] }
    public func installedDesigns() async throws -> [DesignManifest] { designs.values.map(\.manifest).sorted { $0.id < $1.id } }
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
        try await store.save(clean)
        try check(await store.design(id: "clean") == clean, "a saved design comes back unchanged, preview included")
        try await store.save(bold)
        try check(await store.installedDesigns() == [bold.manifest, clean.manifest], "designs are listed by id")
        try await store.save(cleanV2)
        try check(await store.design(id: "clean") == cleanV2, "saving an id again replaces the design")
        try check(await store.installedDesigns() == [bold.manifest, cleanV2.manifest], "a replaced design is listed once")
        for id in ["unknown", "", "../clean", "Clean", "clean\n", "clean/../clean"] {
            try check(await store.design(id: id) == nil, "no design for the identifier \(id.debugDescription)")
        }

        // A conditional save compares and writes in one step, and versions are compared by number.
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
