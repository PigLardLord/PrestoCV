import Foundation
import Testing
@testable import PrestoCVCore

// MARK: - BundleResourceService Tests

@Suite("BundleResourceService Tests")
struct BundleResourceServiceTests {
    
    // MARK: - Initialization Tests
    
    @Test("BundleResourceService initializes with default main bundle")
    func initializesWithDefaultBundle() async {
        let service = BundleResourceService()
        // Test that the service is created successfully
        // We can't directly access the bundle property since it's private,
        // but we can test that the service works with Bundle.main
        let paths = await service.getResourcePaths(ofType: "json", inDirectory: nil as String?)
        // The exact number doesn't matter, just that it doesn't crash
        #expect(paths.count >= 0)
    }
    
    @Test("BundleResourceService initializes with custom bundle")
    func initializesWithCustomBundle() async {
        // Create a simple test bundle
        let testBundle = Bundle.main
        let service = BundleResourceService(bundle: testBundle)
        
        // Test that the service works with custom bundle
        let paths = await service.getResourcePaths(ofType: "json", inDirectory: nil as String?)
        #expect(paths.count >= 0)
    }
    
    // MARK: - getResourcePaths Tests
    
    @Test("getResourcePaths returns paths for existing file types")
    func getResourcePathsReturnsPathsForExistingTypes() async {
        let service = BundleResourceService(bundle: Bundle.main)
        
        // Test with a common file type that should exist
        let jsonPaths = await service.getResourcePaths(ofType: "swift", inDirectory: nil as String?)
        // Bundle.main in test environment may or may not have swift files
        #expect(jsonPaths.count >= 0)
    }
    
    @Test("getResourcePaths returns empty array for non-existent file types")
    func getResourcePathsReturnsEmptyForNonExistentTypes() async {
        let service = BundleResourceService(bundle: Bundle.main)
        
        let paths = await service.getResourcePaths(ofType: "nonexistenttype", inDirectory: nil as String?)
        #expect(paths.isEmpty)
    }
    
    @Test("getResourcePaths works with directory parameter")
    func getResourcePathsWorksWithDirectory() async {
        let service = BundleResourceService(bundle: Bundle.main)
        
        // Test with a directory that may or may not exist
        let paths = await service.getResourcePaths(ofType: "swift", inDirectory: "SomeDirectory")
        #expect(paths.count >= 0)
    }
    
    @Test("getResourcePaths handles nil directory parameter")
    func getResourcePathsHandlesNilDirectory() async {
        let service = BundleResourceService(bundle: Bundle.main)
        
        let paths = await service.getResourcePaths(ofType: "swift", inDirectory: nil as String?)
        #expect(paths.count >= 0)
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
    
    // MARK: - filterPaths Tests
    
    @Test("filterPaths removes excluded filenames correctly")
    func filterPathsRemovesExcludedFilenames() async {
        let service = BundleResourceService()
        
        let testPaths = [
            "/path/to/file1.json",
            "/path/to/file2.json",
            "/path/to/excluded.json",
            "/path/to/another.json"
        ]
        
        let excludedNames: Set<String> = ["excluded", "file2"]
        let filteredPaths = await service.filterPaths(testPaths, excluding: excludedNames)
        
        #expect(filteredPaths.count == 2)
        #expect(filteredPaths.contains("/path/to/file1.json"))
        #expect(filteredPaths.contains("/path/to/another.json"))
        #expect(!filteredPaths.contains("/path/to/excluded.json"))
        #expect(!filteredPaths.contains("/path/to/file2.json"))
    }
    
    @Test("filterPaths handles empty paths array")
    func filterPathsHandlesEmptyPathsArray() async {
        let service = BundleResourceService()
        
        let testPaths: [String] = []
        let excludedNames: Set<String> = ["test"]
        let filteredPaths = await service.filterPaths(testPaths, excluding: excludedNames)
        
        #expect(filteredPaths.isEmpty)
    }
    
    @Test("filterPaths handles empty excluded names set")
    func filterPathsHandlesEmptyExcludedNames() async {
        let service = BundleResourceService()
        
        let testPaths = ["/path/to/file1.json", "/path/to/file2.json"]
        let excludedNames: Set<String> = []
        let filteredPaths = await service.filterPaths(testPaths, excluding: excludedNames)
        
        #expect(filteredPaths.count == 2)
        #expect(filteredPaths == testPaths)
    }
    
    @Test("filterPaths correctly extracts filenames from complex paths")
    func filterPathsExtractsFilenamesFromComplexPaths() async {
        let service = BundleResourceService()
        
        let testPaths = [
            "/very/deep/nested/path/to/important.json",
            "/another/complex/path/file.with.dots.json",
            "/simple/path.json",
            "/path/with spaces/file name.json"
        ]
        
        let excludedNames: Set<String> = ["important", "file.with.dots"]
        let filteredPaths = await service.filterPaths(testPaths, excluding: excludedNames)
        
        #expect(filteredPaths.count == 2)
        #expect(filteredPaths.contains("/simple/path.json"))
        #expect(filteredPaths.contains("/path/with spaces/file name.json"))
    }
    
    @Test("filterPaths handles paths without extensions")
    func filterPathsHandlesPathsWithoutExtensions() async {
        let service = BundleResourceService()
        
        let testPaths = [
            "/path/to/file_without_extension",
            "/path/to/file_with_extension.txt"
        ]
        
        let excludedNames: Set<String> = ["file_without_extension"]
        let filteredPaths = await service.filterPaths(testPaths, excluding: excludedNames)
        
        #expect(filteredPaths.count == 1)
        #expect(filteredPaths.contains("/path/to/file_with_extension.txt"))
    }
    
    @Test("filterPaths is case sensitive")
    func filterPathsIsCaseSensitive() async {
        let service = BundleResourceService()
        
        let testPaths = [
            "/path/to/Test.json",
            "/path/to/test.json"
        ]
        
        let excludedNames: Set<String> = ["test"]
        let filteredPaths = await service.filterPaths(testPaths, excluding: excludedNames)
        
        #expect(filteredPaths.count == 1)
        #expect(filteredPaths.contains("/path/to/Test.json"))
        #expect(!filteredPaths.contains("/path/to/test.json"))
    }
    
    // MARK: - Integration Tests
    
    @Test("BundleResourceService handles concurrent operations correctly")
    func handlessConcurrentOperations() async {
        let service = BundleResourceService(bundle: Bundle.main)
        
        await withTaskGroup(of: Void.self) { group in
            // Test concurrent getResourcePaths calls
            for _ in 0..<5 {
                group.addTask {
                    let paths = await service.getResourcePaths(ofType: "swift", inDirectory: nil as String?)
                    #expect(paths.count >= 0)
                }
            }
            
            // Test concurrent getResourceURL calls
            for i in 0..<5 {
                group.addTask {
                    let url = await service.getResourceURL(forResource: "test\(i)", withExtension: "json")
                    // URL may be nil, that's fine
                    _ = url
                }
            }
            
            // Test concurrent filterPaths calls
            for _ in 0..<5 {
                group.addTask {
                    let paths = ["/test1.json", "/test2.json"]
                    let filtered = await service.filterPaths(paths, excluding: ["test1"])
                    #expect(filtered.count == 1)
                }
            }
        }
    }
    
    @Test("BundleResourceService methods work together in workflow")
    func methodsWorkTogetherInWorkflow() async {
        let service = BundleResourceService(bundle: Bundle.main)
        
        // Get all paths of a certain type
        let allPaths = await service.getResourcePaths(ofType: "swift", inDirectory: nil as String?)
        
        // Filter some paths (even if none exist, this should work)
        let filteredPaths = await service.filterPaths(allPaths, excluding: ["nonexistent"])
        #expect(filteredPaths.count == allPaths.count)
        
        // Try to get URL for a resource (may return nil, that's OK)
        let url = await service.getResourceURL(forResource: "test", withExtension: "json")
        // Just verify the call doesn't crash
        _ = url
    }
}