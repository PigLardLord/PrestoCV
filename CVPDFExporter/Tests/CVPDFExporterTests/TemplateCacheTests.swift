import Testing
import Foundation
@testable import CVPDFExporter

// MARK: - Template Cache Tests (Sprint 4)

@Suite("Template Cache")
struct TemplateCacheTests {

    @Test("Template cache stores rendered HTML")
    func templateCacheStoresHTML() async {
        // Given
        let cache = TemplateCache()
        let key = "test-key"
        let html = "<html><body>Cached Content</body></html>"

        // When
        await cache.store(html: html, for: key)

        // Then
        let cached = await cache.retrieve(for: key)
        #expect(cached == html)
    }

    @Test("Template cache returns nil for missing key")
    func templateCacheReturnNilForMissingKey() async {
        // Given
        let cache = TemplateCache()

        // When
        let result = await cache.retrieve(for: "non-existent")

        // Then
        #expect(result == nil)
    }

    @Test("Template cache can clear specific entry")
    func templateCacheClearSpecificEntry() async {
        // Given
        let cache = TemplateCache()
        let key = "test-key"
        let html = "<html>Test</html>"

        // When
        await cache.store(html: html, for: key)
        let stored = await cache.retrieve(for: key)
        #expect(stored != nil)

        await cache.clear(key: key)
        let cleared = await cache.retrieve(for: key)

        // Then
        #expect(cleared == nil)
    }

    @Test("Template cache can clear all entries")
    func templateCacheClearAllEntries() async {
        // Given
        let cache = TemplateCache()

        // When
        await cache.store(html: "HTML1", for: "key1")
        await cache.store(html: "HTML2", for: "key2")
        await cache.store(html: "HTML3", for: "key3")

        // Verify stored
        #expect(await cache.retrieve(for: "key1") != nil)
        #expect(await cache.retrieve(for: "key2") != nil)
        #expect(await cache.retrieve(for: "key3") != nil)

        // Clear all
        await cache.clearAll()

        // Then
        #expect(await cache.retrieve(for: "key1") == nil)
        #expect(await cache.retrieve(for: "key2") == nil)
        #expect(await cache.retrieve(for: "key3") == nil)
    }

    @Test("Template cache generates consistent keys")
    func templateCacheGeneratesConsistentKeys() {
        // Given
        let cache = TemplateCache()
        let template = Template(
            id: "test",
            name: "Test",
            description: "Test template",
            htmlContent: "<html></html>",
            supportedVariables: []
        )
        let document = CVDocument(
            personalInfo: PersonalInfo(name: "John", email: "john@example.com"),
            sections: [],
            metadata: DocumentMetadata()
        )
        let options = ExportOptions.default

        // When
        let key1 = cache.generateKey(
            template: template.id,
            document: document,
            options: options
        )
        let key2 = cache.generateKey(
            template: template.id,
            document: document,
            options: options
        )

        // Then
        #expect(key1 == key2)
    }

    @Test("Template cache key changes with different inputs")
    func templateCacheKeyChangesWithDifferentInputs() {
        // Given
        let cache = TemplateCache()
        let document1 = CVDocument(
            personalInfo: PersonalInfo(name: "John", email: "john@example.com"),
            sections: [],
            metadata: DocumentMetadata()
        )
        let document2 = CVDocument(
            personalInfo: PersonalInfo(name: "Jane", email: "jane@example.com"),
            sections: [],
            metadata: DocumentMetadata()
        )

        // When
        let key1 = cache.generateKey(
            template: "test",
            document: document1,
            options: .default
        )
        let key2 = cache.generateKey(
            template: "test",
            document: document2,
            options: .default
        )

        // Then
        #expect(key1 != key2)
    }

    @Test("Template cache is thread safe")
    func templateCacheIsThreadSafe() async {
        // Given
        let cache = TemplateCache()

        // When - perform concurrent operations
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    await cache.store(html: "HTML\(i)", for: "key\(i)")
                }
            }
        }

        // Then - all values should be stored
        for i in 0..<10 {
            let result = await cache.retrieve(for: "key\(i)")
            #expect(result == "HTML\(i)")
        }
    }

    @Test("Template cache has size limit")
    func templateCacheHasSizeLimit() async {
        // Given
        let cache = TemplateCache(maxEntries: 3)

        // When - store more than max entries
        await cache.store(html: "HTML1", for: "key1")
        await cache.store(html: "HTML2", for: "key2")
        await cache.store(html: "HTML3", for: "key3")
        await cache.store(html: "HTML4", for: "key4")

        // Then - oldest should be evicted
        let count = await cache.count
        #expect(count <= 3)
    }
}