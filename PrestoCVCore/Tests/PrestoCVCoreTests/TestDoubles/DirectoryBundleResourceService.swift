import Foundation
@testable import PrestoCVCore

/// A bundle resource service that finds resources in a plain directory, standing in for the app bundle
final class DirectoryBundleResourceService: BundleResourceServiceProtocol, @unchecked Sendable {
    private let directory: URL
    
    init(directory: URL) {
        self.directory = directory
    }
    
    func getResourceURL(forResource name: String, withExtension ext: String) async -> URL? {
        let url = directory.appendingPathComponent("\(name).\(ext)")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
