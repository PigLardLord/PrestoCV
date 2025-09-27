import Foundation
import CryptoKit

// MARK: - Template Cache

/// Cache for rendered HTML templates to improve performance
/// Sprint 4: Template caching for performance optimization
public actor TemplateCache {

    /// Cache storage
    private var cache: [String: CacheEntry] = [:]

    /// Maximum number of cached entries
    private let maxEntries: Int

    /// Cache entry with timestamp
    private struct CacheEntry {
        let html: String
        let timestamp: Date
    }

    /// Initialize with maximum cache size
    public init(maxEntries: Int = 10) {
        self.maxEntries = maxEntries
    }

    /// Store rendered HTML in cache
    public func store(html: String, for key: String) {
        // Remove oldest entry if at capacity
        if cache.count >= maxEntries {
            evictOldest()
        }

        cache[key] = CacheEntry(html: html, timestamp: Date())
    }

    /// Retrieve cached HTML
    public func retrieve(for key: String) -> String? {
        return cache[key]?.html
    }

    /// Clear specific cache entry
    public func clear(key: String) {
        cache.removeValue(forKey: key)
    }

    /// Clear all cached entries
    public func clearAll() {
        cache.removeAll()
    }

    /// Get current cache count
    public var count: Int {
        return cache.count
    }

    /// Generate cache key from template, document, and options
    public nonisolated func generateKey(
        template: String,
        document: CVDocument,
        options: ExportOptions
    ) -> String {
        // Create a unique key based on inputs
        var hasher = Hasher()

        // Hash template ID
        hasher.combine(template)

        // Hash document content
        hasher.combine(document.personalInfo.name)
        hasher.combine(document.personalInfo.email)
        hasher.combine(document.personalInfo.phone)
        hasher.combine(document.personalInfo.location)
        hasher.combine(document.personalInfo.website)
        hasher.combine(document.personalInfo.summary)

        // Hash sections
        for section in document.sections {
            hasher.combine(section.id)
            hasher.combine(section.type.rawValue)
            for item in section.items {
                hasher.combine(item.title)
                hasher.combine(item.subtitle)
                hasher.combine(item.description)
            }
        }

        // Hash export options
        hasher.combine(options.pageSize.width)
        hasher.combine(options.pageSize.height)
        hasher.combine(options.customization.colorPalette.rawValue)
        hasher.combine(options.customization.fontScheme.rawValue)

        let hashValue = hasher.finalize()
        return "cache_\(template)_\(hashValue)"
    }

    // MARK: - Private Methods

    private func evictOldest() {
        // Find and remove the oldest entry
        if let oldestKey = cache.min(by: { $0.value.timestamp < $1.value.timestamp })?.key {
            cache.removeValue(forKey: oldestKey)
        }
    }
}