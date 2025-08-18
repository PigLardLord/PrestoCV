import Foundation

// MARK: - Infrastructure Protocols

/// Protocol for generic storage operations with type safety
public protocol StorageServiceProtocol: Sendable {
    /// Saves a Codable object to storage with a unique identifier
    /// - Parameters:
    ///   - object: The object to save (must be Codable & Sendable)
    ///   - identifier: Unique string identifier for the object
    /// - Throws: AppError if serialization or storage fails
    func save<T: Codable & Sendable>(_ object: T, to identifier: String) async throws
    
    /// Loads a specific object type from storage by identifier
    /// - Parameters:
    ///   - type: The type of object to load
    ///   - identifier: The unique identifier of the object
    /// - Returns: The deserialized object if found, nil otherwise
    /// - Throws: AppError if deserialization fails
    func load<T: Codable & Sendable>(_ type: T.Type, from identifier: String) async throws -> T?
    
    /// Loads all objects of a specific type from storage
    /// - Parameter type: The type of objects to load
    /// - Returns: Array of all objects of the specified type
    /// - Throws: AppError if loading or deserialization fails
    func loadAll<T: Codable & Sendable>(_ type: T.Type) async throws -> [T]
    
    /// Deletes an object from storage by identifier
    /// - Parameter identifier: The unique identifier of the object to delete
    /// - Throws: AppError if deletion fails
    func delete(identifier: String) async throws
    
    /// Checks if an object exists in storage
    /// - Parameter identifier: The unique identifier to check
    /// - Returns: true if object exists, false otherwise
    func exists(identifier: String) async -> Bool
    
    /// Retrieves all stored identifiers
    /// - Returns: Array of all unique identifiers in storage
    /// - Throws: AppError if retrieval fails
    func getAllIdentifiers() async throws -> [String]
}

/// Protocol for network-based synchronization operations
public protocol NetworkServiceProtocol {
    /// Uploads an object to a remote endpoint
    /// - Parameters:
    ///   - object: The Codable object to upload
    ///   - endpoint: The target endpoint URL string
    /// - Returns: The server response as the same object type
    /// - Throws: AppError for network or serialization failures
    func upload<T: Codable>(_ object: T, to endpoint: String) async throws -> T
    
    /// Downloads an object from a remote endpoint
    /// - Parameters:
    ///   - type: The type of object to download
    ///   - endpoint: The source endpoint URL string
    /// - Returns: The deserialized object from the server
    /// - Throws: AppError for network or deserialization failures
    func download<T: Codable>(_ type: T.Type, from endpoint: String) async throws -> T
    
    /// Synchronizes local objects with remote endpoint
    /// - Parameters:
    ///   - objects: Array of local objects to sync
    ///   - endpoint: The sync endpoint URL string
    /// - Returns: Array of synchronized objects from server
    /// - Throws: AppError for network or synchronization failures
    func sync<T: Codable>(_ objects: [T], with endpoint: String) async throws -> [T]
}

/// Protocol for caching operations with async support
public protocol CacheServiceProtocol {
    /// Stores an object in cache with a key
    /// - Parameters:
    ///   - object: The Codable object to cache
    ///   - key: The cache key for later retrieval
    func set<T: Codable>(_ object: T, forKey key: String) async
    
    /// Retrieves an object from cache by key
    /// - Parameters:
    ///   - type: The type of object to retrieve
    ///   - key: The cache key
    /// - Returns: The cached object if found, nil otherwise
    func get<T: Codable>(_ type: T.Type, forKey key: String) async -> T?
    
    /// Removes a specific item from cache
    /// - Parameter key: The cache key to remove
    func remove(forKey key: String) async
    
    /// Clears all items from cache
    func clear() async
}