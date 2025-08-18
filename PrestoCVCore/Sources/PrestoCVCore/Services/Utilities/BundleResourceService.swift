import Foundation

actor BundleResourceService: BundleResourceServiceProtocol {
    
    private let bundle: Bundle
    
    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }
    
    func getResourcePaths(ofType type: String, inDirectory directory: String? = nil) async -> [String] {
        return bundle.paths(forResourcesOfType: type, inDirectory: directory)
    }
    
    func getResourceURL(forResource name: String, withExtension ext: String) async -> URL? {
        return bundle.url(forResource: name, withExtension: ext)
    }
    
    func filterPaths(_ paths: [String], excluding excludedNames: Set<String>) async -> [String] {
        return paths.filter { path in
            let fileName = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
            return !excludedNames.contains(fileName)
        }
    }
}