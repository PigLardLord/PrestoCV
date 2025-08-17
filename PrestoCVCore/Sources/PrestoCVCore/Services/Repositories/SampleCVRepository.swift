import Foundation

// MARK: - Sample CV Repository Implementation
// Note: Sample CVs are pre-filled CV models that serve as starting points
// for users to create their own CVs.

public final class SampleCVRepository: SampleCVRepositoryProtocol, Sendable {
    private let storageService: StorageServiceProtocol
    private let categoryService: TemplateCategoryServiceProtocol
    private let bundleResourceService = BundleResourceService()
    private let templateLoader = JSONTemplateLoader()
    private let parallelSearchService = ParallelSearchService()
    
    public init(storageService: StorageServiceProtocol) {
        self.storageService = storageService
        self.categoryService = TemplateCategoryService()
    }
    
    public func getDefaultSample() async throws -> CVModel {
        // Return a default empty CV sample (starting point for users)
        return CVModel()
    }
    
    public func getAllSamples() async throws -> [CVModel] {
        let resourcePaths = await bundleResourceService.getResourcePaths(ofType: "json")
        let validPaths = await bundleResourceService.filterPaths(resourcePaths, excluding: ["default"])
        let samples = await templateLoader.loadTemplates(from: validPaths)
        
        return samples.isEmpty ? [try await getDefaultSample()] : samples
    }
    
    public func getSample(by name: String) async throws -> CVModel? {
        // Handle default case early
        if name == "default" {
            return try await getDefaultSample()
        }
        
        // Try exact name match first
        if let sample = try await loadSampleByExactName(name) {
            return sample
        }
        
        // Fall back to category matching
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
        let resourcePaths = await bundleResourceService.getResourcePaths(ofType: "json")
        let validPaths = await bundleResourceService.filterPaths(resourcePaths, excluding: ["default"])
        
        return try await findFirstMatchingTemplate(in: validPaths, matching: name)
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
            loader: createTemplateLoader(for: name)
            // Using default matcher that always returns true
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