import Foundation

/// Stores validated designs. Owned by the catalog (DIP); adapters live in CVDesignCatalogFileStore and test support,
/// and pass `DesignStoreContract`. Saving an identifier again replaces its design.
public protocol DesignStore: Sendable {
    func save(_ design: ValidatedDesign) async throws
    /// nil only when no design has this identifier; a stored design that cannot be read is an error (CleanErrors).
    func design(id: String) async throws -> ValidatedDesign?
    /// The stored designs' manifests, ordered by identifier.
    func installedDesigns() async throws -> [DesignManifest]
}

/// Proves that a design renders a fixture document without losing content (ADR 0011). Owned by the
/// catalog, implemented downstream by CVRendering (the allowed Rendering → Catalog edge).
public protocol DesignRenderingGate: Sendable {
    func verify(_ design: ValidatedDesign) async throws
}

/// Installing a design from untrusted bytes: validate, then prove it renders completely, then store.
/// Nothing is stored unless both checks pass.
public struct InstallDesign: Sendable {
    let validator: DesignPackageValidator, gate: any DesignRenderingGate, store: any DesignStore
    public init(validator: DesignPackageValidator = DesignPackageValidator(), gate: any DesignRenderingGate, store: any DesignStore) {
        self.validator = validator; self.gate = gate; self.store = store
    }
    public func callAsFunction(_ data: Data) async throws -> ValidatedDesign {
        let design = try validator.validate(data)
        try await gate.verify(design)
        try await store.save(design)
        return design
    }
}

/// Outbound port, owned by the catalog (DIP). Raw bytes: validation happens in the catalog, not the source.
public protocol BundledDesignSource: Sendable {
    func bundledPackages() async throws -> [(name: String, data: Data)]
}
