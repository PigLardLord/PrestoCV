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
        customization: CustomizationOptions,
        pageSize: PageSize = .a4
    ) async throws -> TemplatePreview {
        // Check cache first
        let cacheKey = makeCacheKey(templateId: templateId, cv: cv, customization: customization, pageSize: pageSize)
        if let cached = await cache.get(key: cacheKey) {
            return cached
        }

        // Get template
        guard let template = try await repository.getTemplate(byId: templateId) else {
            throw TemplatePreviewError.templateNotFound(templateId)
        }

        // Render HTML
        let rawHTML = try await templateEngine.render(
            template: template,
            data: cv,
            customization: customization
        )
        let previewHTML = wrapHTMLForPreview(rawHTML, pageSize: pageSize)

        // Create preview
        let preview = TemplatePreview(
            templateId: templateId,
            html: previewHTML,
            rawHTML: rawHTML,
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
        customization: CustomizationOptions,
        pageSize: PageSize = .a4
    ) async throws -> [TemplatePreview] {
        try await withThrowingTaskGroup(of: TemplatePreview.self) { group in
            for templateId in templateIds {
                group.addTask {
                    try await self.generatePreview(
                        templateId: templateId,
                        cv: cv,
                        customization: customization,
                        pageSize: pageSize
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

    private func wrapHTMLForPreview(_ html: String, pageSize: PageSize) -> String {
        let pageWidth = pageSize.width
        let pageHeight = pageSize.height

        let previewStyling = """
        <style id=\"cv-preview-sizing\">
            :root {
                --cv-preview-scale: 1;
                --cv-preview-stage-width: \(pageWidth)pt;
                --cv-preview-viewport-height: \(pageHeight)pt;
                --cv-preview-page-width: \(pageWidth)pt;
                --cv-preview-page-height: \(pageHeight)pt;
                --cv-preview-shell-padding: 16px;
            }

            @media screen {
                html {
                    background-color: var(--color-background, #ffffff);
                }

                body {
                    margin: 0;
                    padding: 0;
                    display: block;
                    box-sizing: border-box;
                    background-color: var(--color-background, #ffffff);
                }

                .cv-preview-shell {
                    width: 100%;
                    max-width: 100%;
                    padding: 0;
                    box-sizing: border-box;
                }

                .cv-preview-stage {
                    width: var(--cv-preview-stage-width);
                    margin: 0 auto;
                    overflow-y: auto;
                    overflow-x: hidden;
                    -webkit-overflow-scrolling: touch;
                    background: transparent;
                    position: relative;
                }

                .cv-preview-stage::-webkit-scrollbar {
                    display: none;
                }

                .cv-preview-page {
                    width: var(--cv-preview-page-width);
                    min-height: var(--cv-preview-page-height);
                    transform-origin: top left;
                    transform: scale(var(--cv-preview-scale));
                    background-color: var(--color-background, #ffffff);
                }

                .cv-preview-content {
                    width: var(--cv-preview-page-width);
                    min-height: var(--cv-preview-page-height);
                }
            }

            @media print {
                html {
                    background-color: initial !important;
                }

                body {
                    margin: 0 !important;
                    padding: 0 !important;
                    display: block !important;
                    background-color: inherit !important;
                }

                .cv-preview-shell,
                .cv-preview-stage {
                    width: auto !important;
                    height: auto !important;
                    padding: 0 !important;
                    box-shadow: none !important;
                    background-color: inherit !important;
                    overflow: visible !important;
                }

                .cv-preview-page {
                    transform: none !important;
                    box-shadow: none !important;
                    border-radius: 0 !important;
                }
            }
        </style>
        """

        let makeScriptTag: (String) -> String = { script in
            "<script type=\"text/javascript\">\n\(script)\n</script>\n"
        }

        let readinessScripts = makeScriptTag(PreviewReadinessScript.bootstrap) + makeScriptTag(PreviewReadinessScript.scalingBootstrap)

        var result = html

        if let headRange = result.range(of: "</head>", options: [.caseInsensitive]) {
            result.insert(contentsOf: previewStyling + readinessScripts, at: headRange.lowerBound)
        } else {
            result = "<head>\(previewStyling)\(readinessScripts)</head>" + result
        }

        if let bodyRange = result.range(of: "<body", options: [.caseInsensitive]),
           let closeIndex = result[bodyRange.upperBound...].firstIndex(of: ">") {
            let insertionIndex = result.index(after: closeIndex)
            result.insert(contentsOf: "<div class=\"cv-preview-shell\"><div class=\"cv-preview-stage\"><div class=\"cv-preview-page\"><div class=\"cv-preview-content\">", at: insertionIndex)
        }

        if let bodyClose = result.range(of: "</body>", options: [.caseInsensitive])?.lowerBound {
            result.insert(contentsOf: "</div></div></div></div>", at: bodyClose)
        }

        return result
    }

    private func makeCacheKey(
        templateId: String,
        cv: CVDocument,
        customization: CustomizationOptions,
        pageSize: PageSize
    ) -> String {
        // Create a unique key based on inputs
        let cvHash = String(cv.hashValue)
        let customizationHash = String(customization.hashValue)
        return "\(templateId)-\(cvHash)-\(customizationHash)-\(pageSize.width)-\(pageSize.height)"
    }
}

// MARK: - Template Preview Model

public struct TemplatePreview: Sendable, Equatable {
    public let templateId: String
    public let html: String
    public let rawHTML: String
    public let generatedAt: Date
    public let thumbnail: String?

    public init(
        templateId: String,
        html: String,
        rawHTML: String,
        generatedAt: Date,
        thumbnail: String? = nil
    ) {
        self.templateId = templateId
        self.html = html
        self.rawHTML = rawHTML
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
