import Foundation

// MARK: - Sample CV Repository Implementation
// Note: Sample CVs are pre-filled CV models that serve as starting points
// for users to create their own CVs.

public final class SampleCVRepository: SampleCVRepositoryProtocol, Sendable {
    private let storageService: StorageServiceProtocol
    private let categoryService: TemplateCategoryServiceProtocol
    
    public init(storageService: StorageServiceProtocol) {
        self.storageService = storageService
        self.categoryService = TemplateCategoryService()
    }
    
    public func getDefaultSample() async throws -> CVModel {
        // Return a default empty CV sample (starting point for users)
        return CVModel()
    }
    
    public func getAllSamples() async throws -> [CVModel] {
        // Since the JSON files are in the app's Resources folder, we should use the main bundle
        let bundle = Bundle.main
        
        // Get all JSON files from the bundle
        let resources = bundle.paths(forResourcesOfType: "json", inDirectory: nil)
        
        var samples: [CVModel] = []
        
        // Load each JSON file that represents a CV
        for resourcePath in resources {
            let url = URL(fileURLWithPath: resourcePath)
            // Skip the default empty template
            if url.lastPathComponent == "default.json" {
                continue
            }
            
            do {
                let data = try Data(contentsOf: url)
                let cv = try JSONDecoder().decode(CVModel.self, from: data)
                samples.append(cv)
            } catch {
                // Log error but continue loading other samples
                print("Failed to load sample CV from \(url.lastPathComponent): \(error)")
            }
        }
        
        // If no samples loaded, return default
        if samples.isEmpty {
            samples.append(try await getDefaultSample())
        }
        
        return samples
    }
    
    public func getSample(by name: String) async throws -> CVModel? {
        // Retrieve a specific CV sample by name
        if name == "default" {
            return try await getDefaultSample()
        }
        
        // Since the JSON files are in the app's Resources folder, we should use the main bundle
        let bundle = Bundle.main
        
        // Try to load by exact file name first
        if let url = bundle.url(forResource: name, withExtension: "json") {
            do {
                let data = try Data(contentsOf: url)
                return try JSONDecoder().decode(CVModel.self, from: data)
            } catch {
                print("Failed to load sample CV from \(name).json: \(error)")
            }
        }
        
        // Try to match by category keywords in file names
        let resources = bundle.paths(forResourcesOfType: "json", inDirectory: nil)
        
        for resourcePath in resources {
            let url = URL(fileURLWithPath: resourcePath)
            let fileName = url.deletingPathExtension().lastPathComponent
            
            // Skip the default template
            if fileName == "default" {
                continue
            }
            
            // Use the category service to check for matches
            if categoryService.matchTemplateCategory(for: fileName, to: name) {
                do {
                    let data = try Data(contentsOf: url)
                    return try JSONDecoder().decode(CVModel.self, from: data)
                } catch {
                    print("Failed to load sample CV from \(url.lastPathComponent): \(error)")
                }
            }
        }
        
        return nil
    }
}