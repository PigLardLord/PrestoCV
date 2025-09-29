import Foundation

/// Use case for generating template previews
public final class TemplatePreviewUseCase: Sendable {
    private let templateEngine: TemplateEngine
    private let repository: TemplateRepositoryProtocol
    private let cache = PreviewCache()

    public init(
        templateEngine: TemplateEngine,
        repository: TemplateRepositoryProtocol
    ) {
        self.templateEngine = templateEngine
        self.repository = repository
    }

    /// Generates a preview of a template with CV data
    public func generatePreview(
        templateId: String,
        cv: CVDocument,
        customization: CustomizationOptions
    ) async throws -> TemplatePreview {
        // Check cache first
        let cacheKey = makeCacheKey(templateId: templateId, cv: cv, customization: customization)
        if let cached = await cache.get(key: cacheKey) {
            return cached
        }

        // Get template
        guard let template = try await repository.getTemplate(byId: templateId) else {
            throw TemplatePreviewError.templateNotFound(templateId)
        }

        // Render HTML
        let html = try await templateEngine.render(
            template: template,
            data: cv,
            customization: customization
        )

        // Create preview
        let preview = TemplatePreview(
            templateId: templateId,
            html: html,
            generatedAt: Date()
        )

        // Cache it
        await cache.set(key: cacheKey, value: preview)

        return preview
    }

    /// Generates multiple previews in parallel
    public func batchGeneratePreviews(
        templateIds: [String],
        cv: CVDocument,
        customization: CustomizationOptions
    ) async throws -> [TemplatePreview] {
        try await withThrowingTaskGroup(of: TemplatePreview.self) { group in
            for templateId in templateIds {
                group.addTask {
                    try await self.generatePreview(
                        templateId: templateId,
                        cv: cv,
                        customization: customization
                    )
                }
            }

            var previews: [TemplatePreview] = []
            for try await preview in group {
                previews.append(preview)
            }
            return previews
        }
    }

    /// Generates a thumbnail image from a preview
    public func generateThumbnail(for preview: TemplatePreview) async throws -> String {
        // This would use WKWebView or similar to render HTML to image
        // For now, return a placeholder
        let placeholderData = Data([0xFF, 0xD8, 0xFF]) // JPEG header
        let base64 = placeholderData.base64EncodedString()
        return "data:image/jpeg;base64,\(base64)"
    }

    /// Caches a preview
    public func cachePreview(_ preview: TemplatePreview, for key: String) async {
        await cache.set(key: key, value: preview)
    }

    /// Gets a cached preview
    public func getCachedPreview(for key: String) async -> TemplatePreview? {
        await cache.get(key: key)
    }

    /// Clears all cached previews
    public func clearCache() async {
        await cache.clear()
    }

    // MARK: - Private Methods

    private func makeCacheKey(
        templateId: String,
        cv: CVDocument,
        customization: CustomizationOptions
    ) -> String {
        // Create a unique key based on inputs
        let cvHash = String(cv.hashValue)
        let customizationHash = String(customization.hashValue)
        return "\(templateId)-\(cvHash)-\(customizationHash)"
    }
}

// MARK: - Template Preview Model

public struct TemplatePreview: Sendable, Equatable {
    public let templateId: String
    public let html: String
    public let generatedAt: Date
    public let thumbnail: String?

    public init(
        templateId: String,
        html: String,
        generatedAt: Date,
        thumbnail: String? = nil
    ) {
        self.templateId = templateId
        self.html = html
        self.generatedAt = generatedAt
        self.thumbnail = thumbnail
    }
}

// MARK: - Template Preview Error

public enum TemplatePreviewError: Error, Equatable, Sendable {
    case templateNotFound(String)
    case renderingFailed(String)
    case thumbnailGenerationFailed
}

// MARK: - Preview Cache

actor PreviewCache {
    private var storage: [String: TemplatePreview] = [:]
    private let maxItems = 20

    func get(key: String) -> TemplatePreview? {
        storage[key]
    }

    func set(key: String, value: TemplatePreview) {
        // Implement LRU cache if needed
        if storage.count >= maxItems {
            // Remove oldest item (simplified - should use LRU)
            if let firstKey = storage.keys.first {
                storage.removeValue(forKey: firstKey)
            }
        }
        storage[key] = value
    }

    func clear() {
        storage.removeAll()
    }
}