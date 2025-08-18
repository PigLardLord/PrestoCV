import Foundation

actor ParallelSearchService: ParallelSearchServiceProtocol {
    
    func findFirst<Source, Item>(
        in sources: [Source],
        loader: @escaping @Sendable (Source) async throws -> Item?,
        matcher: @escaping @Sendable (Item) -> Bool = { _ in true }
    ) async throws -> Item? where Source: Sendable, Item: Sendable {
        
        return await withThrowingTaskGroup(of: Item?.self) { group in
            scheduleParallelSearchTasks(in: &group, sources: sources, loader: loader, matcher: matcher)
            return await waitForFirstMatch(in: &group)
        }
    }
    
    func findAll<Source, Item>(
        in sources: [Source],
        loader: @escaping @Sendable (Source) async throws -> Item?,
        matcher: @escaping @Sendable (Item) -> Bool = { _ in true }
    ) async throws -> [Item] where Source: Sendable, Item: Sendable {
        
        return await withThrowingTaskGroup(of: Item?.self) { group in
            scheduleParallelSearchTasks(in: &group, sources: sources, loader: loader, matcher: matcher)
            return await collectAllMatches(from: &group)
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
    
    /// Extracts successful value from a task group result
    /// - Parameter result: The result from a task group
    /// - Returns: The unwrapped value if successful, nil otherwise
    private func extractSuccessValue<Item>(
        from result: Result<Item?, Error>
    ) -> Item? where Item: Sendable {
        guard case .success(let value) = result else { return nil }
        return value
    }
    
    /// Processes task group results with a handler that can control iteration
    /// - Parameters:
    ///   - group: The task group to iterate through
    ///   - handler: Function called for each successful item; return true to continue, false to stop
    private func processSuccessfulResults<Item>(
        in group: inout ThrowingTaskGroup<Item?, Error>,
        handler: (Item) -> Bool
    ) async where Item: Sendable {
        while let result = await group.nextResult() {
            if let item = extractSuccessValue(from: result) {
                if !handler(item) { return }
            }
        }
    }
    
    /// Waits for the first matching item and cancels remaining tasks
    /// - Parameter group: The task group to wait on
    /// - Returns: The first matching item found, or nil if none found
    private func waitForFirstMatch<Item>(
        in group: inout ThrowingTaskGroup<Item?, Error>
    ) async -> Item? where Item: Sendable {
        defer { group.cancelAll() }
        var foundItem: Item?
        await processSuccessfulResults(in: &group) { item in
            foundItem = item
            return false // Stop after finding first item
        }
        return foundItem
    }
    
    /// Collects all matching items from the task group
    /// - Parameter group: The task group to collect from
    /// - Returns: Array of all matching items found
    private func collectAllMatches<Item>(
        from group: inout ThrowingTaskGroup<Item?, Error>
    ) async -> [Item] where Item: Sendable {
        var items: [Item] = []
        await processSuccessfulResults(in: &group) { item in
            items.append(item)
            return true // Continue collecting all items
        }
        return items
    }
}