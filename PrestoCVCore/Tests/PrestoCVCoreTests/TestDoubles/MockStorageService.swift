import Testing
import Foundation
@testable import PrestoCVCore

/// A mock storage service that operates entirely in memory for isolated testing
public final class MockStorageService: StorageServiceProtocol, @unchecked Sendable {
    private let queue = DispatchQueue(label: "MockStorageService", qos: .userInteractive)
    private var _storage: [String: Data] = [:]
    private var _listingError: Error?
    private var _listingCount = 0
    private var _unreadableCount = 0
    private var _acknowledgeCount = 0
    
    /// How many files `loadAllReporting` says it could not read.
    public var unreadableCount: Int {
        get { queue.sync { _unreadableCount } }
        set { queue.sync { _unreadableCount = newValue } }
    }
    
    /// How many times `acknowledgeQuarantined` was called.
    public var acknowledgeCount: Int { queue.sync { _acknowledgeCount } }
    
    /// How many times the storage was listed, by `loadAll` or `getAllIdentifiers`.
    public var listingCount: Int { queue.sync { _listingCount } }
    
    /// When set, `loadAll` and `getAllIdentifiers` throw it, as a storage that cannot be listed does.
    public var listingError: Error? {
        get { queue.sync { _listingError } }
        set { queue.sync { _listingError = newValue } }
    }
    
    private var storage: [String: Data] {
        get {
            return queue.sync { _storage }
        }
        set {
            queue.sync { _storage = newValue }
        }
    }
    
    private func withStorage<T>(_ operation: ([String: Data]) -> T) -> T {
        return queue.sync { operation(_storage) }
    }
    
    private func modifyStorage(_ operation: (inout [String: Data]) -> Void) {
        queue.sync { operation(&_storage) }
    }
    
    private func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        return encoder
    }
    
    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
    
    public func save<T: Codable & Sendable>(_ object: T, to identifier: String) async throws {
        let encoder = makeEncoder()
        let data = try encoder.encode(object)
        modifyStorage { storage in
            storage[identifier] = data
        }
    }
    
    public func save<T: Codable & Sendable>(to identifier: String, updating transform: @Sendable (T?) -> T) async throws {
        let encoder = makeEncoder()
        let decoder = makeDecoder()
        try queue.sync {
            let stored = _storage[identifier].flatMap { try? decoder.decode(T.self, from: $0) }
            _storage[identifier] = try encoder.encode(transform(stored))
        }
    }
    
    public func load<T: Codable & Sendable>(_ type: T.Type, from identifier: String) async throws -> T? {
        return withStorage { storage in
            guard let data = storage[identifier] else { return nil }
            let decoder = makeDecoder()
            return try? decoder.decode(type, from: data)
        }
    }
    
    public func loadAll<T: Codable & Sendable>(_ type: T.Type) async throws -> [T] {
        recordListing()
        if let listingError { throw listingError }
        return withStorage { storage in
            var objects: [T] = []
            let decoder = makeDecoder()
            for data in storage.values {
                if let object = try? decoder.decode(type, from: data) {
                    objects.append(object)
                }
            }
            return objects
        }
    }
    
    public func loadIdentified<T: Codable & Sendable & StorageIdentified>(_ type: T.Type, from identifier: String) async throws -> T? {
        guard let object = try await load(type, from: identifier), object.storageIdentifier == identifier else {
            return nil
        }
        return object
    }
    
    public func loadAllReporting<T: Codable & Sendable & StorageIdentified>(_ type: T.Type) async throws -> StorageLoadReport<T> {
        let objects = try await loadAll(type)
        let belonging = objects.filter { object in withStorage { $0[object.storageIdentifier] != nil } }
        return StorageLoadReport(items: belonging, unreadableCount: unreadableCount + objects.count - belonging.count)
    }
    
    public func acknowledgeQuarantined() async throws {
        queue.sync {
            _acknowledgeCount += 1
            _unreadableCount = 0
        }
    }
    
    public func delete(identifier: String) async throws {
        modifyStorage { storage in
            storage.removeValue(forKey: identifier)
        }
    }
    
    public func exists(identifier: String) async -> Bool {
        return withStorage { storage in
            return storage[identifier] != nil
        }
    }
    
    public func getAllIdentifiers() async throws -> [String] {
        recordListing()
        if let listingError { throw listingError }
        return withStorage { storage in
            return Array(storage.keys)
        }
    }
    
    private func recordListing() {
        queue.sync { _listingCount += 1 }
    }
    
    // Test helper methods
    public func clear() {
        modifyStorage { storage in
            storage.removeAll()
        }
    }
    
    public func isEmpty() -> Bool {
        return withStorage { storage in
            return storage.isEmpty
        }
    }
}

// MARK: - Mock Service Implementations

public final class MockParallelSearchService: ParallelSearchServiceProtocol, @unchecked Sendable {
    public func findFirst<Source, Item>(
        in sources: [Source],
        loader: @escaping @Sendable (Source) async throws -> Item?,
        matcher: @escaping @Sendable (Item) -> Bool
    ) async throws -> Item? where Source: Sendable, Item: Sendable {
        // Simple implementation for testing - just try each source sequentially
        for source in sources {
            if let item = try await loader(source), matcher(item) {
                return item
            }
        }
        return nil
    }
    
    public func findAll<Source, Item>(
        in sources: [Source],
        loader: @escaping @Sendable (Source) async throws -> Item?,
        matcher: @escaping @Sendable (Item) -> Bool
    ) async throws -> [Item] where Source: Sendable, Item: Sendable {
        var results: [Item] = []
        for source in sources {
            if let item = try await loader(source), matcher(item) {
                results.append(item)
            }
        }
        return results
    }
}

public final class MockBundleResourceService: BundleResourceServiceProtocol, @unchecked Sendable {
    public func getResourceURL(forResource name: String, withExtension ext: String) async -> URL? {
        // Return nil for tests
        return nil
    }
}

public final class MockJSONTemplateLoader: JSONTemplateLoaderProtocol, @unchecked Sendable {
    public func loadTemplate(from path: String) async -> CVModel? {
        // Return a default CV for tests
        return CVModel()
    }
    
    public func loadTemplate(from url: URL) async throws -> CVModel {
        // Return a default CV for tests
        return CVModel()
    }
    
    public func loadTemplates(from paths: [String]) async -> [CVModel] {
        // Return default CVs for each path
        return paths.map { _ in CVModel() }
    }
    
    public func loadTemplateIfMatches(
        path: String,
        matcher: @Sendable (String) -> Bool
    ) async throws -> CVModel? {
        let fileName = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        return matcher(fileName) ? CVModel() : nil
    }
}