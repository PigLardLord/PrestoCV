import Foundation

/// Why a catalog use case failed (R7). A failure of the store is reported as such, never passed through raw.
public enum DesignCatalogError: Error, Equatable, Sendable {
    /// No installed design has this identifier.
    case unknownDesign(String)
    /// The design store cannot be read or written.
    case storeUnavailable
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
