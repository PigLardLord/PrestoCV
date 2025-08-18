import Foundation

// MARK: - Service Protocols

/// Protocol for categorizing templates based on file names and keywords
public protocol TemplateCategoryServiceProtocol: Sendable {
    /// Determines if a file name matches a specific category based on keywords
    /// - Parameters:
    ///   - fileName: The name of the file to categorize
    ///   - category: The target category to match against
    /// - Returns: true if the file matches the category, false otherwise
    func matchTemplateCategory(for fileName: String, to category: String) -> Bool
    
    /// Retrieves the mapping of categories to their associated keywords
    /// - Returns: Dictionary where keys are category names and values are arrays of keywords
    func getCategoryKeywords() -> [String: [String]]
}

/// Protocol for performing parallel searches across multiple data sources
public protocol ParallelSearchServiceProtocol: Sendable {
    /// Searches for the first matching item across multiple sources in parallel
    /// - Parameters:
    ///   - sources: Array of source identifiers to search through
    ///   - loader: Async closure that loads an item from a given source
    ///   - matcher: Optional closure that determines if a loaded item matches the search criteria (defaults to always match)
    /// - Returns: The first matching item found, or nil if no matches
    /// - Throws: Any errors encountered during the loading process
    func findFirst<Source, Item>(
        in sources: [Source],
        loader: @escaping @Sendable (Source) async throws -> Item?,
        matcher: @escaping @Sendable (Item) -> Bool
    ) async throws -> Item? where Source: Sendable, Item: Sendable
    
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
        matcher: @escaping @Sendable (Item) -> Bool
    ) async throws -> [Item] where Source: Sendable, Item: Sendable
}

/// Protocol for accessing bundle resources and filtering paths
public protocol BundleResourceServiceProtocol: Sendable {
    /// Retrieves resource paths of a specific type from the bundle
    /// - Parameters:
    ///   - type: The file extension type to search for
    ///   - directory: Optional directory within the bundle to search in
    /// - Returns: Array of file paths matching the criteria
    func getResourcePaths(ofType type: String, inDirectory directory: String?) async -> [String]
    
    /// Gets the URL for a specific resource in the bundle
    /// - Parameters:
    ///   - name: The name of the resource file
    ///   - ext: The file extension
    /// - Returns: URL of the resource if found, nil otherwise
    func getResourceURL(forResource name: String, withExtension ext: String) async -> URL?
    
    /// Filters a list of paths by excluding files with specific names
    /// - Parameters:
    ///   - paths: Array of file paths to filter
    ///   - excludedNames: Set of file names to exclude from results
    /// - Returns: Filtered array of paths
    func filterPaths(_ paths: [String], excluding excludedNames: Set<String>) async -> [String]
}

/// Protocol for loading CV templates from JSON files
public protocol JSONTemplateLoaderProtocol: Sendable {
    /// Loads a CV template from a file path
    /// - Parameter path: The file path to load from
    /// - Returns: CVModel if successfully loaded, nil if loading fails
    func loadTemplate(from path: String) async -> CVModel?
    
    /// Loads a CV template from a URL with error throwing
    /// - Parameter url: The URL to load from
    /// - Returns: The loaded CVModel
    /// - Throws: AppError if loading or parsing fails
    func loadTemplate(from url: URL) async throws -> CVModel
    
    /// Loads multiple CV templates from an array of file paths
    /// - Parameter paths: Array of file paths to load from
    /// - Returns: Array of successfully loaded CVModel instances
    func loadTemplates(from paths: [String]) async -> [CVModel]
    
    /// Loads a template only if the path matches the given criteria
    /// - Parameters:
    ///   - path: The file path to potentially load from
    ///   - matcher: Closure that determines if the path should be loaded
    /// - Returns: CVModel if path matches and loads successfully, nil otherwise
    /// - Throws: AppError if loading fails for a matching path
    func loadTemplateIfMatches(
        path: String,
        matcher: @Sendable (String) -> Bool
    ) async throws -> CVModel?
}