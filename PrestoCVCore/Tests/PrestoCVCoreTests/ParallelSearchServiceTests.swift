import Foundation
import Testing
@testable import PrestoCVCore

// MARK: - ParallelSearchService Tests

@Suite("ParallelSearchService Tests")
struct ParallelSearchServiceTests {
    
    // MARK: - Basic Functionality Tests
    
    @Test("ParallelSearchService initializes correctly")
    func initializesCorrectly() async {
        let service = ParallelSearchService()
        _ = service // Just verify it can be created
    }
    
    @Test("findFirst returns first matching item")
    func findFirstReturnsFirstMatchingItem() async throws {
        let service = ParallelSearchService()
        
        let sources = ["apple", "banana", "cherry", "date"]
        let loader: @Sendable (String) async throws -> String? = { source in
            return source
        }
        let matcher: @Sendable (String) -> Bool = { item in
            return item.contains("a") // Matches apple, banana, date
        }
        
        let result = try await service.findFirst(in: sources, loader: loader, matcher: matcher)
        
        #expect(result != nil)
        #expect(result?.contains("a") == true)
    }
    
    @Test("findFirst returns nil when no items match")
    func findFirstReturnsNilWhenNoItemsMatch() async throws {
        let service = ParallelSearchService()
        
        let sources = ["apple", "banana", "cherry"]
        let loader: @Sendable (String) async throws -> String? = { source in
            return source
        }
        let matcher: @Sendable (String) -> Bool = { item in
            return item.contains("z") // No items contain 'z'
        }
        
        let result = try await service.findFirst(in: sources, loader: loader, matcher: matcher)
        
        #expect(result == nil)
    }
    
    @Test("findFirst handles empty sources array")
    func findFirstHandlesEmptySourcesArray() async throws {
        let service = ParallelSearchService()
        
        let sources: [String] = []
        let loader: @Sendable (String) async throws -> String? = { source in
            return source
        }
        
        let result = try await service.findFirst(in: sources, loader: loader)
        
        #expect(result == nil)
    }
    
    @Test("findAll returns all matching items") 
    func findAllReturnsAllMatchingItems() async throws {
        let service = ParallelSearchService()
        
        let sources = ["apple", "banana", "cherry", "apricot"]
        let loader: @Sendable (String) async throws -> String? = { source in
            return source
        }
        let matcher: @Sendable (String) -> Bool = { item in
            return item.starts(with: "a") // Matches apple, apricot
        }
        
        let results = try await service.findAll(in: sources, loader: loader, matcher: matcher)
        
        #expect(results.count == 2)
        #expect(results.contains("apple"))
        #expect(results.contains("apricot"))
    }
    
    @Test("findAll returns empty array when no items match")
    func findAllReturnsEmptyArrayWhenNoItemsMatch() async throws {
        let service = ParallelSearchService()
        
        let sources = ["apple", "banana", "cherry"]
        let loader: @Sendable (String) async throws -> String? = { source in
            return source
        }
        let matcher: @Sendable (String) -> Bool = { item in
            return item.contains("z") // No items contain 'z'
        }
        
        let results = try await service.findAll(in: sources, loader: loader, matcher: matcher)
        
        #expect(results.isEmpty)
    }
    
    @Test("findAll handles empty sources array")
    func findAllHandlesEmptySourcesArray() async throws {
        let service = ParallelSearchService()
        
        let sources: [String] = []
        let loader: @Sendable (String) async throws -> String? = { source in
            return source
        }
        
        let results = try await service.findAll(in: sources, loader: loader)
        
        #expect(results.isEmpty)
    }
}