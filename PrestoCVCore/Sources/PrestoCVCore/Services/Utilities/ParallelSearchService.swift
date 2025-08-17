import Foundation

/// A service that performs parallel searches across multiple data sources
/// Provides efficient concurrent searching with early termination upon finding a match
actor ParallelSearchService {
    
    /// Searches for an item across multiple sources in parallel
    /// - Parameters:
    ///   - sources: Array of source identifiers to search through
    ///   - loader: Async closure that loads an item from a given source
    ///   - matcher: Closure that determines if a loaded item matches the search criteria
    /// - Returns: The first matching item found, or nil if no matches
    /// - Throws: Any errors encountered during the loading process
    func findFirst<Source, Item>(
        in sources: [Source],
        loader: @escaping @Sendable (Source) async throws -> Item?,
        matcher: @escaping @Sendable (Item) -> Bool
    ) async throws -> Item? where Source: Sendable, Item: Sendable {
        
        return try await withThrowingTaskGroup(of: Item?.self) { group in
            // Schedule parallel loading tasks
            for source in sources {
                group.addTask {
                    guard let item = try await loader(source) else {
                        return nil
                    }
                    return matcher(item) ? item : nil
                }
            }
            
            // Return first matching item and cancel remaining tasks
            for try await result in group {
                if let item = result {
                    group.cancelAll()
                    return item
                }
            }
            
            return nil
        }
    }
    
    /// Searches for all items that match the criteria across multiple sources
    /// - Parameters:
    ///   - sources: Array of source identifiers to search through
    ///   - loader: Async closure that loads an item from a given source
    ///   - matcher: Closure that determines if a loaded item matches the search criteria
    /// - Returns: Array of all matching items found
    /// - Throws: Any errors encountered during the loading process
    func findAll<Source, Item>(
        in sources: [Source],
        loader: @escaping @Sendable (Source) async throws -> Item?,
        matcher: @escaping @Sendable (Item) -> Bool
    ) async throws -> [Item] where Source: Sendable, Item: Sendable {
        
        return try await withThrowingTaskGroup(of: Item?.self) { group in
            // Schedule parallel loading tasks
            for source in sources {
                group.addTask {
                    guard let item = try await loader(source) else {
                        return nil
                    }
                    return matcher(item) ? item : nil
                }
            }
            
            // Collect all matching items
            var matchingItems: [Item] = []
            for try await result in group {
                if let item = result {
                    matchingItems.append(item)
                }
            }
            
            return matchingItems
        }
    }
}