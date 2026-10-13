import Foundation

// MARK: - Sample CV Repository Implementation
// Note: Sample CVs are pre-filled CV models that serve as starting points
// for users to create their own CVs.

public final class SampleCVRepository: SampleCVRepositoryProtocol, Sendable {
    /// The sample CVs the app ships, in the order they are offered. They are listed by name because the bundle
    /// holds other JSON files that are not CVs in this format, which a scan for `*.json` would pick up as blank CVs.
    static let bundledSampleNames = ["technical_cv", "business_cv", "creative_cv", "academic_cv", "healthcare_cv"]
    
    private let storageService: StorageServiceProtocol
    private let categoryService: TemplateCategoryServiceProtocol
    private let bundleResourceService: BundleResourceServiceProtocol
    private let templateLoader: JSONTemplateLoaderProtocol
    private let parallelSearchService: ParallelSearchServiceProtocol
    
    // MARK: - Initialization
    
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
    
    // MARK: - Public Protocol Implementation
    
    public func getDefaultSample() async throws -> CVModel {
        return CVModel()
    }
    
    public func getAllSamples() async throws -> [CVModel] {
        let samplePaths = await getBundledSamplePaths()
        let loadedSamples = await loadSamplesFromPaths(samplePaths)
        
        return try await ensureAtLeastOneTemplate(samples: loadedSamples)
    }
    
    public func getSample(by name: String) async throws -> CVModel? {
        if await isDefaultTemplateName(name) {
            return try await getDefaultSample()
        }
        
        return try await findSampleUsingSearchStrategies(name)
    }

}

// MARK: - Private Helper Methods

extension SampleCVRepository {
    
    // MARK: Template Path Management
    
    private func getBundledSamplePaths() async -> [String] {
        var paths: [String] = []
        for name in Self.bundledSampleNames {
            if let url = await bundleResourceService.getResourceURL(forResource: name, withExtension: "json") {
                paths.append(url.path)
            }
        }
        return paths
    }
    
    // MARK: Template Loading
    
    private func loadSamplesFromPaths(_ paths: [String]) async -> [CVModel] {
        return await templateLoader.loadTemplates(from: paths)
    }
    
    private func ensureAtLeastOneTemplate(samples: [CVModel]) async throws -> [CVModel] {
        if samples.isEmpty {
            return [try await getDefaultSample()]
        }
        return samples
    }
    
    // MARK: Sample Search Logic
    
    private func isDefaultTemplateName(_ name: String) async -> Bool {
        return name == "default"
    }
    
    private func findSampleUsingSearchStrategies(_ name: String) async throws -> CVModel? {
        // Strategy 1: Try exact name match
        if let exactMatch = try await loadSampleByExactName(name) {
            return exactMatch
        }
        
        // Strategy 2: Fall back to category matching
        return try await loadSampleByCategoryMatch(name)
    }
    
    private func loadSampleByExactName(_ name: String) async throws -> CVModel? {
        guard Self.bundledSampleNames.contains(name),
              let url = await bundleResourceService.getResourceURL(forResource: name, withExtension: "json") else {
            return nil
        }
        
        return try await templateLoader.loadTemplate(from: url)
    }
    
    private func loadSampleByCategoryMatch(_ name: String) async throws -> CVModel? {
        let samplePaths = await getBundledSamplePaths()
        return try await searchForCategoryMatch(in: samplePaths, categoryName: name)
    }
    
    // MARK: Category Matching
    
    private func searchForCategoryMatch(in paths: [String], categoryName: String) async throws -> CVModel? {
        return try await findFirstMatchingTemplate(in: paths, matching: categoryName)
    }
    
    private func findFirstMatchingTemplate(in paths: [String], matching name: String) async throws -> CVModel? {
        return try await parallelSearchService.findFirst(
            in: paths,
            loader: createTemplateLoader(for: name),
            matcher: { _ in true }
        )
    }
    
    // MARK: Function Factories
    
    private func createTemplateLoader(for categoryName: String) -> @Sendable (String) async throws -> CVModel? {
        let categoryMatcher = createCategoryMatcher(for: categoryName)
        
        return { [templateLoader] path in
            try await templateLoader.loadTemplateIfMatches(path: path, matcher: categoryMatcher)
        }
    }
    
    private func createCategoryMatcher(for categoryName: String) -> @Sendable (String) -> Bool {
        return { [categoryService] fileName in
            categoryService.matchTemplateCategory(for: fileName, to: categoryName)
        }
    }
}