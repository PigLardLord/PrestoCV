import Testing
import Foundation
@testable import PrestoCVCore

/// A mock storage service that operates entirely in memory for isolated testing
public final class MockStorageService: StorageServiceProtocol, @unchecked Sendable {
    private let queue = DispatchQueue(label: "MockStorageService", qos: .userInteractive)
    private var _storage: [String: Data] = [:]
    
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
    
    public func load<T: Codable & Sendable>(_ type: T.Type, from identifier: String) async throws -> T? {
        return withStorage { storage in
            guard let data = storage[identifier] else { return nil }
            let decoder = makeDecoder()
            return try? decoder.decode(type, from: data)
        }
    }
    
    public func loadAll<T: Codable & Sendable>(_ type: T.Type) async throws -> [T] {
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
        return withStorage { storage in
            return Array(storage.keys)
        }
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