import Foundation

// MARK: - Sample CV Repository Implementation
// Note: Sample CVs are pre-filled CV models that serve as starting points
// for users to create their own CVs.

public final class SampleCVRepository: SampleCVRepositoryProtocol, Sendable {
    private let storageService: StorageServiceProtocol
    private let categoryService: TemplateCategoryServiceProtocol
    private let bundleResourceService: BundleResourceServiceProtocol
    private let templateLoader: JSONTemplateLoaderProtocol
    private let parallelSearchService: ParallelSearchServiceProtocol
    
    public init(
        storageService: StorageServiceProtocol,
        categoryService: TemplateCategoryServiceProtocol,
        bundleResourceService: BundleResourceServiceProtocol,
        templateLoader: JSONTemplateLoaderProtocol,
        parallelSearchService: ParallelSearchServiceProtocol
    ) {
        self.storageService = storageService
        self.categoryService = categoryService
        self.bundleResourceService = bundleResourceService
        self.templateLoader = templateLoader
        self.parallelSearchService = parallelSearchService
    }
    
    public func getDefaultSample() async throws -> CVModel {
        // Return a default empty CV sample (starting point for users)
        return CVModel()
    }
    
    public func getAllSamples() async throws -> [CVModel] {
        let validTemplatePaths = await getValidTemplatePaths()
        let loadedSamples = await loadSamplesFromPaths(validTemplatePaths)
        
        return try await ensureAtLeastOneTemplate(samples: loadedSamples)
    }
    
    /// Gets all valid template paths (excluding default template)
    /// - Returns: Array of file paths for valid templates
    private func getValidTemplatePaths() async -> [String] {
        let allPaths = await bundleResourceService.getResourcePaths(ofType: "json", inDirectory: nil)
        return await bundleResourceService.filterPaths(allPaths, excluding: Set(["default"]))
    }
    
    /// Loads samples from the provided file paths
    /// - Parameter paths: Array of file paths to load from
    /// - Returns: Array of successfully loaded CV models
    private func loadSamplesFromPaths(_ paths: [String]) async -> [CVModel] {
        return await templateLoader.loadTemplates(from: paths)
    }
    
    /// Ensures at least one template is returned, adding default if needed
    /// - Parameter samples: Array of loaded samples
    /// - Returns: Array with at least one template
    private func ensureAtLeastOneTemplate(samples: [CVModel]) async throws -> [CVModel] {
        if samples.isEmpty {
            return [try await getDefaultSample()]
        }
        return samples
    }
    
    public func getSample(by name: String) async throws -> CVModel? {
        if await isDefaultTemplateName(name) {
            return try await getDefaultSample()
        }
        
        return try await findSampleUsingSearchStrategies(name)
    }
    
    /// Checks if the provided name refers to the default template
    /// - Parameter name: Template name to check
    /// - Returns: True if this is the default template name
    private func isDefaultTemplateName(_ name: String) async -> Bool {
        return name == "default"
    }
    
    /// Attempts to find a sample using multiple search strategies
    /// - Parameter name: Template name to search for
    /// - Returns: CV model if found, nil otherwise
    private func findSampleUsingSearchStrategies(_ name: String) async throws -> CVModel? {
        // Strategy 1: Try exact name match
        if let exactMatch = try await loadSampleByExactName(name) {
            return exactMatch
        }
        
        // Strategy 2: Fall back to category matching
        return try await loadSampleByCategoryMatch(name)
    }
    
    /// Loads a sample by exact file name match
    /// - Parameter name: The exact name to match
    /// - Returns: CV model if found and loaded successfully
    /// - Throws: AppError if decoding fails
    private func loadSampleByExactName(_ name: String) async throws -> CVModel? {
        guard let url = await bundleResourceService.getResourceURL(forResource: name, withExtension: "json") else {
            return nil
        }
        
        return try await templateLoader.loadTemplate(from: url)
    }
    
    /// Loads a sample by matching category keywords
    /// - Parameter name: The category name to match
    /// - Returns: CV model if a matching category is found
    /// - Throws: AppError if decoding fails
    private func loadSampleByCategoryMatch(_ name: String) async throws -> CVModel? {
        let searchablePaths = await getSearchableTemplatePaths()
        return try await searchForCategoryMatch(in: searchablePaths, categoryName: name)
    }
    
    /// Gets template paths that can be searched (excluding defaults)
    /// - Returns: Array of searchable file paths
    private func getSearchableTemplatePaths() async -> [String] {
        let allPaths = await bundleResourceService.getResourcePaths(ofType: "json", inDirectory: nil)
        return await bundleResourceService.filterPaths(allPaths, excluding: Set(["default"]))
    }
    
    /// Searches for a template matching the category name
    /// - Parameters:
    ///   - paths: Paths to search through
    ///   - categoryName: Category name to match
    /// - Returns: First matching template found
    private func searchForCategoryMatch(in paths: [String], categoryName: String) async throws -> CVModel? {
        return try await findFirstMatchingTemplate(in: paths, matching: categoryName)
    }
    
    /// Finds the first template that matches the category name using ParallelSearchService
    /// - Parameters:
    ///   - paths: Array of file paths to search
    ///   - name: Category name to match
    /// - Returns: CV model if a match is found
    /// - Throws: AppError if decoding fails
    private func findFirstMatchingTemplate(in paths: [String], matching name: String) async throws -> CVModel? {
        return try await parallelSearchService.findFirst(
            in: paths,
            loader: createTemplateLoader(for: name),
            matcher: { _ in true } // Default matcher that always returns true
        )
    }
    
    /// Creates a template loader function for the specified category
    /// - Parameter categoryName: The category name to match against
    /// - Returns: A loader function that loads templates matching the category
    private func createTemplateLoader(for categoryName: String) -> @Sendable (String) async throws -> CVModel? {
        let categoryMatcher = createCategoryMatcher(for: categoryName)
        
        return { [templateLoader] path in
            try await templateLoader.loadTemplateIfMatches(path: path, matcher: categoryMatcher)
        }
    }
    
    /// Creates a matcher function for category-based template matching
    /// - Parameter categoryName: The category name to match against
    /// - Returns: A function that checks if a filename matches the category
    private func createCategoryMatcher(for categoryName: String) -> @Sendable (String) -> Bool {
        return { [categoryService] fileName in
            categoryService.matchTemplateCategory(for: fileName, to: categoryName)
        }
    }
}