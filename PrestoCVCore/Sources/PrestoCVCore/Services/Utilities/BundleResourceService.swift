import Foundation

/// Service for accessing and managing bundle resources
actor BundleResourceService {
    
    private let bundle: Bundle
    
    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }
    
    /// Gets all file paths for a specific resource type
    /// - Parameters:
    ///   - type: File extension to search for
    ///   - directory: Directory to search in (nil for root)
    /// - Returns: Array of file paths
    func getResourcePaths(ofType type: String, inDirectory directory: String? = nil) -> [String] {
        return bundle.paths(forResourcesOfType: type, inDirectory: directory)
    }
    
    /// Gets a URL for a specific resource
    /// - Parameters:
    ///   - name: Resource name without extension
    ///   - ext: File extension
    /// - Returns: URL if resource exists, nil otherwise
    func getResourceURL(forResource name: String, withExtension ext: String) -> URL? {
        return bundle.url(forResource: name, withExtension: ext)
    }
    
    /// Filters paths excluding specific filenames
    /// - Parameters:
    ///   - paths: Array of file paths to filter
    ///   - excludedNames: Filenames to exclude (without extensions)
    /// - Returns: Filtered array of paths
    func filterPaths(_ paths: [String], excluding excludedNames: Set<String>) -> [String] {
        return paths.filter { path in
            let fileName = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
            return !excludedNames.contains(fileName)
        }
    }
}