import Foundation

// MARK: - Infrastructure Protocols

/// An object that knows the identifier it must be stored under, so that a storage can tell a file that is
/// stored under the wrong one.
public protocol StorageIdentified {
    /// The identifier the object is stored under.
    var storageIdentifier: String { get }
}

/// Protocol for generic storage operations with type safety.
///
/// One storage instance owns its storage: it serialises every operation on it, which a second instance on the same
/// directory would bypass. The dependency container creates exactly one.
public protocol StorageServiceProtocol: Sendable {
    /// Saves a Codable object to storage with a unique identifier
    /// - Parameters:
    ///   - object: The object to save (must be Codable & Sendable)
    ///   - identifier: Unique string identifier for the object
    /// - Throws: `AppError.encodingError` if serialization fails, `AppError.fileSystemError` if writing fails
    func save<T: Codable & Sendable>(_ object: T, to identifier: String) async throws
    
    /// Saves the object that `transform` returns, handing it the object already stored under the identifier.
    ///
    /// Reading, `transform` and writing are one operation: no other operation on this storage runs in between,
    /// so an update that depends on the stored object cannot lose or reorder another one. `transform` must not
    /// call back into the storage.
    /// - Parameters:
    ///   - identifier: Unique string identifier for the object
    ///   - transform: Receives the stored object, or nil when there is none or it cannot be read (the save replaces it)
    /// - Throws: `AppError.encodingError` if serialization fails, `AppError.fileSystemError` if writing fails
    func save<T: Codable & Sendable>(to identifier: String, updating transform: @Sendable (T?) -> T) async throws
    
    /// Loads a specific object type from storage by identifier
    /// - Parameters:
    ///   - type: The type of object to load
    ///   - identifier: The unique identifier of the object
    /// - Returns: The deserialized object if found, nil otherwise
    /// - Throws: `AppError.fileSystemError` if the stored data cannot be read, `AppError.decodingError` if it is not a valid object
    func load<T: Codable & Sendable>(_ type: T.Type, from identifier: String) async throws -> T?
    
    /// Loads an object by identifier, like `load`, and checks that the stored object belongs under that identifier.
    ///
    /// A file whose object belongs under another identifier is not the object asked for. It is renamed to its own
    /// identifier when that is free, and left untouched when it is not.
    /// - Returns: The object, or nil if there is none under this identifier or the file is named wrongly
    /// - Throws: `AppError.fileSystemError` if the stored data cannot be read, `AppError.decodingError` if it is not a valid object
    func loadIdentified<T: Codable & Sendable & StorageIdentified>(_ type: T.Type, from identifier: String) async throws -> T?
    
    /// Loads all objects of a specific type from storage.
    ///
    /// A stored file that cannot be opened is skipped and stays where it is, to be read again next time.
    /// A file whose content is not a valid object is set aside, not deleted, and skipped.
    /// - Parameter type: The type of objects to load
    /// - Returns: Array of all objects that could be read
    /// - Throws: `AppError.fileSystemError` if the storage cannot be listed
    func loadAll<T: Codable & Sendable>(_ type: T.Type) async throws -> [T]
    
    /// Loads all objects of a specific type, like `loadAll`, checks that each belongs under the identifier it is
    /// stored under (as `loadIdentified` does), and counts the stored files that could not be used.
    ///
    /// The count covers the files that stay where they are (unreadable, or named after another object's
    /// identifier while that name is taken), and the files set aside that have not been acknowledged yet, so it
    /// does not depend on which load did the setting aside.
    /// - Parameter type: The type of objects to load
    /// - Returns: The objects that could be used, and the number of files that could not
    /// - Throws: `AppError.fileSystemError` if the storage cannot be listed
    func loadAllReporting<T: Codable & Sendable & StorageIdentified>(_ type: T.Type) async throws -> StorageLoadReport<T>
    
    /// Marks the files that were set aside as seen, so that `loadAllReporting` stops counting them.
    ///
    /// The files are kept, not deleted. Files set aside after this call are counted again.
    /// - Throws: `AppError.fileSystemError` if the files cannot be moved
    func acknowledgeQuarantined() async throws
    
    /// Deletes an object from storage by identifier. Deleting an object that is not stored is not an error.
    /// - Parameter identifier: The unique identifier of the object to delete
    /// - Throws: `AppError.fileSystemError` if the removal fails
    func delete(identifier: String) async throws
    
    /// Checks if an object exists in storage
    /// - Parameter identifier: The unique identifier to check
    /// - Returns: true if object exists, false otherwise
    func exists(identifier: String) async -> Bool
    
    /// Retrieves all stored identifiers
    /// - Returns: Array of all unique identifiers in storage
    /// - Throws: `AppError.fileSystemError` if the storage cannot be listed
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