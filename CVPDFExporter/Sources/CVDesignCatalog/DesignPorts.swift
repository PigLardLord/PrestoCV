import Foundation

/// Stores validated designs. Owned by the catalog (DIP); adapters live in CVDesignCatalogFileStore and test support,
/// and pass `DesignStoreContract`. Saving an identifier again replaces its design.
public protocol DesignStore: Sendable {
    /// Stores `design`, replacing the one with the same identifier.
    func save(_ design: ValidatedDesign) async throws
    /// nil only when no design has this identifier; a stored design that cannot be read is an error (CleanErrors).
    func design(id: String) async throws -> ValidatedDesign?
    /// The stored designs' manifests, ordered by identifier.
    func installedDesigns() async throws -> [DesignManifest]
}

/// Proves that a design renders a fixture document without losing content (ADR 0011). Owned by the
/// catalog, implemented downstream by CVRendering (the allowed Rendering → Catalog edge).
public protocol DesignRenderingGate: Sendable {
    /// Returns when `design` renders the fixture document completely; throws otherwise.
    func verify(_ design: ValidatedDesign) async throws
}

/// Installing a design from untrusted bytes: validate, then prove it renders completely, then store.
/// Nothing is stored unless both checks pass.
public struct InstallDesign: Sendable {
    let validator: DesignPackageValidator, gate: any DesignRenderingGate, store: any DesignStore
    /// - Parameters:
    ///   - validator: checks the package bytes; the default bounds apply when omitted.
    ///   - gate: proves that the validated design renders completely.
    ///   - store: keeps the design once both checks have passed.
    public init(validator: DesignPackageValidator = DesignPackageValidator(), gate: any DesignRenderingGate, store: any DesignStore) {
        self.validator = validator; self.gate = gate; self.store = store
    }

    /// Installs the design in the bytes of a `.mcvt` file.
    ///
    /// - Throws: `DesignPackageRejected` when the package is not valid, what the gate throws when the design does not
    ///   render completely, or what the store throws when it cannot save.
    public func callAsFunction(_ data: Data) async throws -> ValidatedDesign {
        let design = try validator.validate(data)
        try await gate.verify(design)
        try await store.save(design)
        return design
    }
}

/// Outbound port, owned by the catalog (DIP). Raw bytes: validation happens in the catalog, not the source.
public protocol BundledDesignSource: Sendable {
    /// The bundled packages as `(file name without extension, bytes)`, ordered by file name.
    func bundledPackages() async throws -> [(name: String, data: Data)]
}
