import Foundation

/// A service that performs parallel searches across multiple data sources
/// Provides efficient concurrent searching with early termination upon finding a match
actor ParallelSearchService: ParallelSearchServiceProtocol {
    
    /// Searches for an item across multiple sources in parallel
    /// - Parameters:
    ///   - sources: Array of source identifiers to search through
    ///   - loader: Async closure that loads an item from a given source
    ///   - matcher: Optional closure that determines if a loaded item matches the search criteria (defaults to always match)
    /// - Returns: The first matching item found, or nil if no matches
    /// - Throws: Any errors encountered during the loading process
    func findFirst<Source, Item>(
        in sources: [Source],
        loader: @escaping @Sendable (Source) async throws -> Item?,
        matcher: @escaping @Sendable (Item) -> Bool = { _ in true }
    ) async throws -> Item? where Source: Sendable, Item: Sendable {
        
        return await withThrowingTaskGroup(of: Item?.self) { group in
            scheduleParallelSearchTasks(in: &group, sources: sources, loader: loader, matcher: matcher)
            return await waitForFirstMatch(in: group)
        }
    }
    
    /// Searches for all items that match the criteria across multiple sources
    /// - Parameters:
    ///   - sources: Array of source identifiers to search through
    ///   - loader: Async closure that loads an item from a given source
    ///   - matcher: Optional closure that determines if a loaded item matches the search criteria (defaults to always match)
    /// - Returns: Array of all matching items found
    /// - Throws: Any errors encountered during the loading process
    func findAll<Source, Item>(
        in sources: [Source],
        loader: @escaping @Sendable (Source) async throws -> Item?,
        matcher: @escaping @Sendable (Item) -> Bool = { _ in true }
    ) async throws -> [Item] where Source: Sendable, Item: Sendable {
        
        return await withThrowingTaskGroup(of: Item?.self) { group in
            scheduleParallelSearchTasks(in: &group, sources: sources, loader: loader, matcher: matcher)
            return await collectAllMatches(from: group)
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// Schedules parallel search tasks for each source in the task group
    /// - Parameters:
    ///   - group: The task group to add tasks to
    ///   - sources: Array of source identifiers to search
    ///   - loader: Function to load items from sources
    ///   - matcher: Function to validate loaded items
    private func scheduleParallelSearchTasks<Source, Item>(
        in group: inout ThrowingTaskGroup<Item?, Error>,
        sources: [Source],
        loader: @escaping @Sendable (Source) async throws -> Item?,
        matcher: @escaping @Sendable (Item) -> Bool
    ) where Source: Sendable, Item: Sendable {
        for source in sources {
            group.addTask {
                await self.loadAndValidateItem(from: source, loader: loader, matcher: matcher)
            }
        }
    }
    
    /// Loads an item from a source and validates it against the matcher
    /// - Parameters:
    ///   - source: The source to load from
    ///   - loader: Function to load the item
    ///   - matcher: Function to validate the item
    /// - Returns: The item if it matches, nil otherwise
    private func loadAndValidateItem<Source, Item>(
        from source: Source,
        loader: @Sendable (Source) async throws -> Item?,
        matcher: @Sendable (Item) -> Bool
    ) async -> Item? where Source: Sendable, Item: Sendable {
        return (try? await loader(source)).flatMap { matcher($0) ? $0 : nil }
    }
    
    /// Waits for the first matching item and cancels remaining tasks
    /// - Parameter group: The task group to wait on
    /// - Returns: The first matching item found, or nil if none found
    private func waitForFirstMatch<Item>(
        in group: ThrowingTaskGroup<Item?, Error>
    ) async -> Item? where Item: Sendable {
        do {
            for try await result in group {
                if let item = result {
                    group.cancelAll()
                    return item
                }
            }
        } catch {
            group.cancelAll()
        }
        return nil
    }
    
    /// Collects all matching items from the task group
    /// - Parameter group: The task group to collect from
    /// - Returns: Array of all matching items found
    private func collectAllMatches<Item>(
        from group: ThrowingTaskGroup<Item?, Error>
    ) async -> [Item] where Item: Sendable {
        var matchingItems: [Item] = []
        do {
            for try await result in group {
                if let item = result {
                    matchingItems.append(item)
                }
            }
        } catch {}
        return matchingItems
    }
}