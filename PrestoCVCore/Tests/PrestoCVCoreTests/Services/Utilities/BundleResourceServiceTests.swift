import Foundation
import Testing
@testable import PrestoCVCore

// MARK: - BundleResourceService Tests

@Suite("BundleResourceService Tests")
struct BundleResourceServiceTests {
    
    // MARK: - Initialization Tests
    
    @Test("BundleResourceService initializes with custom bundle")
    func initializesWithCustomBundle() async {
        let service = BundleResourceService(bundle: Bundle.main)
        
        let url = await service.getResourceURL(forResource: "nonexistent_file", withExtension: "json")
        #expect(url == nil)
    }
    
    // MARK: - getResourceURL Tests
    
    @Test("getResourceURL returns nil for non-existent resources")
    func getResourceURLReturnsNilForNonExistentResources() async {
        let service = BundleResourceService(bundle: Bundle.main)
        
        let url = await service.getResourceURL(forResource: "nonexistent_file", withExtension: "txt")
        #expect(url == nil)
    }
    
    @Test("getResourceURL handles empty resource name")
    func getResourceURLHandlesEmptyResourceName() async {
        let service = BundleResourceService(bundle: Bundle.main)
        
        let url = await service.getResourceURL(forResource: "", withExtension: "txt")
        #expect(url == nil)
    }
    
    @Test("getResourceURL handles empty extension")
    func getResourceURLHandlesEmptyExtension() async {
        let service = BundleResourceService(bundle: Bundle.main)
        
        let url = await service.getResourceURL(forResource: "test", withExtension: "")
        #expect(url == nil)
    }
    
    // MARK: - Concurrency Tests
    
    @Test("BundleResourceService handles concurrent operations correctly")
    func handlesConcurrentOperations() async {
        let service = BundleResourceService(bundle: Bundle.main)
        
        await withTaskGroup(of: URL?.self) { group in
            for i in 0..<5 {
                group.addTask {
                    await service.getResourceURL(forResource: "test\(i)", withExtension: "json")
                }
            }
            
            for await url in group {
                #expect(url == nil)
            }
        }
    }
}
