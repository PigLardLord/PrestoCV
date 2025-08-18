import Foundation

/// Service for loading and decoding JSON template files
actor JSONTemplateLoader: JSONTemplateLoaderProtocol {
    
    private let decoder = JSONDecoder()
    
    /// Loads a single CV model from a file path
    /// - Parameter path: File path to load from
    /// - Returns: CV model if successful, nil if failed
    func loadTemplate(from path: String) async -> CVModel? {
        let url = URL(fileURLWithPath: path)
        
        guard let data = try? Data(contentsOf: url),
              let cv = try? decoder.decode(CVModel.self, from: data) else {
            print("Failed to load template from \(url.lastPathComponent)")
            return nil
        }
        
        return cv
    }
    
    /// Loads a CV model from a URL with proper error handling
    /// - Parameter url: URL to load from
    /// - Returns: CV model if successful
    /// - Throws: AppError if loading or decoding fails
    func loadTemplate(from url: URL) async throws -> CVModel {
        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(CVModel.self, from: data)
        } catch {
            throw AppError.decodingError("Failed to decode \(url.lastPathComponent): \(error.localizedDescription)")
        }
    }
    
    /// Loads multiple templates from file paths, skipping invalid ones
    /// - Parameter paths: Array of file paths to load from
    /// - Returns: Array of successfully loaded CV models
    func loadTemplates(from paths: [String]) async -> [CVModel] {
        var templates: [CVModel] = []
        for path in paths {
            if let template = await loadTemplate(from: path) {
                templates.append(template)
            }
        }
        return templates
    }
    
    /// Loads a template if it matches the given criteria
    /// - Parameters:
    ///   - path: File path to check and load
    ///   - matcher: Closure that determines if the file should be loaded
    /// - Returns: CV model if criteria match and loading succeeds
    /// - Throws: AppError if decoding fails for a matching file
    func loadTemplateIfMatches(
        path: String,
        matcher: @Sendable (String) -> Bool
    ) async throws -> CVModel? {
        let url = URL(fileURLWithPath: path)
        let fileName = url.deletingPathExtension().lastPathComponent
        
        guard matcher(fileName) else {
            return nil
        }
        
        return try await loadTemplate(from: url)
    }
}