import Foundation

actor BundleResourceService: BundleResourceServiceProtocol {
    
    private let bundle: Bundle
    
    init(bundle: Bundle) {
        self.bundle = bundle
    }
    
    func getResourceURL(forResource name: String, withExtension ext: String) async -> URL? {
        return bundle.url(forResource: name, withExtension: ext)
    }
}