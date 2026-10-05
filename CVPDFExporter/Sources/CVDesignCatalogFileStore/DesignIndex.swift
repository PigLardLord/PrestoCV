import Foundation
import CVDesignCatalog

/// Index schema 1: the stored designs, each with its manifest and the generation of its file. `index.json` holds it.
struct DesignIndex: Codable {
    struct Entry: Codable {
        let manifest: DesignManifest
        let generation: Int
    }

    static let version = 1, maxBytes = 1024 * 1024, maxGeneration = Int(Int32.max)

    let schemaVersion: Int
    let designs: [Entry]

    init(designs: [Entry]) {
        schemaVersion = Self.version
        self.designs = designs
    }

    /// The entries of an index file's bytes, or why the file is not a usable index.
    static func entries(from data: Data) throws(FileDesignStoreError) -> [Entry] {
        try requireSupported(version: try schemaVersion(of: data))
        let index = try decode(data)
        try requireValid(index.designs)
        return index.designs
    }

    private static func schemaVersion(of data: Data) throws(FileDesignStoreError) -> Int {
        struct Envelope: Decodable { let schemaVersion: Int }
        do { return try JSONDecoder().decode(Envelope.self, from: data).schemaVersion } catch { throw .indexCorrupt("no schema version") }
    }

    private static func requireSupported(version found: Int) throws(FileDesignStoreError) {
        guard found <= version else { throw .indexFromNewerVersion(found) }
        guard found == version else { throw .indexCorrupt("schema version \(found)") }
    }

    private static func decode(_ data: Data) throws(FileDesignStoreError) -> DesignIndex {
        do { return try JSONDecoder().decode(DesignIndex.self, from: data) } catch { throw .indexCorrupt("not an index") }
    }

    /// Identifiers are valid, in order and unique, and every generation is a positive number a file name can hold.
    private static func requireValid(_ entries: [Entry]) throws(FileDesignStoreError) {
        let ids = entries.map(\.manifest.id)
        guard ids.allSatisfy(DesignManifest.isValidID), ids == ids.sorted(), Set(ids).count == ids.count,
              entries.allSatisfy({ (1...maxGeneration).contains($0.generation) }) else {
            throw .indexCorrupt("entries")
        }
    }
}
