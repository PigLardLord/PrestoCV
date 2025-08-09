import Testing
import Foundation
@testable import PrestoCVCore

/// A mock storage service that operates entirely in memory for isolated testing
public final class MockStorageService: StorageServiceProtocol {
    private var storage: [String: Data] = [:]
    
    private func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
    
    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
    
    public func save<T: Codable>(_ object: T, to identifier: String) async throws {
        let encoder = makeEncoder()
        let data = try encoder.encode(object)
        storage[identifier] = data
    }
    
    public func load<T: Codable>(_ type: T.Type, from identifier: String) async throws -> T? {
        guard let data = storage[identifier] else { return nil }
        let decoder = makeDecoder()
        return try decoder.decode(type, from: data)
    }
    
    public func loadAll<T: Codable>(_ type: T.Type) async throws -> [T] {
        var objects: [T] = []
        let decoder = makeDecoder()
        for data in storage.values {
            if let object = try? decoder.decode(type, from: data) {
                objects.append(object)
            }
        }
        return objects
    }
    
    public func delete(identifier: String) async throws {
        storage.removeValue(forKey: identifier)
    }
    
    public func exists(identifier: String) async -> Bool {
        return storage[identifier] != nil
    }
    
    public func getAllIdentifiers() async throws -> [String] {
        return Array(storage.keys)
    }
    
    // Test helper methods
    public func clear() {
        storage.removeAll()
    }
    
    public func isEmpty() -> Bool {
        return storage.isEmpty
    }
}