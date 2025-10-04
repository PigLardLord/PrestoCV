import Foundation

/// Factory for creating platform-appropriate PDF renderers
public enum PDFRendererFactory {

    /// Creates the best available PDF renderer for the current platform
    /// - Returns: A PDF renderer appropriate for the current platform
    public static func createRenderer() -> PDFRendererProtocol {
        #if canImport(UIKit) && canImport(WebKit)
        // iOS/iPadOS - Use enhanced WKWebView renderer
        return MainActor.assumeIsolated {
            EnhancedWKWebViewPDFRenderer()
        }
        #elseif canImport(AppKit) && canImport(WebKit)
        // macOS - Use proper macOS PDF renderer
        return ProperMacOSPDFRenderer()
        #else
        // Fallback - Use test renderer
        return TestPDFRenderer()
        #endif
    }

    /// Creates a renderer with specific configuration
    /// - Parameter configuration: Renderer configuration options
    /// - Returns: A configured PDF renderer
    public static func createRenderer(configuration: RendererConfiguration) -> PDFRendererProtocol {
        let renderer = createRenderer()

        // Apply configuration if renderer supports it
        if let configurableRenderer = renderer as? ConfigurableRenderer {
            configurableRenderer.apply(configuration)
        }

        return renderer
    }

    /// Checks if a high-quality renderer is available on the current platform
    public static var hasNativeRenderer: Bool {
        #if (canImport(UIKit) || canImport(AppKit)) && canImport(WebKit)
        return true
        #else
        return false
        #endif
    }
}

/// Configuration options for PDF renderers
public struct RendererConfiguration: Sendable {
    /// Enable JavaScript execution for dynamic content
    public let enableJavaScript: Bool

    /// Timeout for page loading in seconds
    public let pageLoadTimeout: TimeInterval

    /// Timeout for JavaScript execution in seconds
    public let javascriptTimeout: TimeInterval

    /// Enable performance monitoring
    public let enablePerformanceMonitoring: Bool

    /// Enable debug logging
    public let enableDebugLogging: Bool

    /// Cache rendered pages for performance
    public let enablePageCaching: Bool

    /// Maximum memory usage in MB
    public let maxMemoryUsage: Int

    public init(
        enableJavaScript: Bool = true,
        pageLoadTimeout: TimeInterval = 30.0,
        javascriptTimeout: TimeInterval = 5.0,
        enablePerformanceMonitoring: Bool = true,
        enableDebugLogging: Bool = false,
        enablePageCaching: Bool = true,
        maxMemoryUsage: Int = 100
    ) {
        self.enableJavaScript = enableJavaScript
        self.pageLoadTimeout = pageLoadTimeout
        self.javascriptTimeout = javascriptTimeout
        self.enablePerformanceMonitoring = enablePerformanceMonitoring
        self.enableDebugLogging = enableDebugLogging
        self.enablePageCaching = enablePageCaching
        self.maxMemoryUsage = maxMemoryUsage
    }

    /// Default production configuration
    public static let production = RendererConfiguration(
        enableJavaScript: true,
        pageLoadTimeout: 30.0,
        javascriptTimeout: 5.0,
        enablePerformanceMonitoring: true,
        enableDebugLogging: false,
        enablePageCaching: true,
        maxMemoryUsage: 100
    )

    /// Debug configuration with extra logging
    public static let debug = RendererConfiguration(
        enableJavaScript: true,
        pageLoadTimeout: 60.0,
        javascriptTimeout: 10.0,
        enablePerformanceMonitoring: true,
        enableDebugLogging: true,
        enablePageCaching: false,
        maxMemoryUsage: 200
    )

    /// Minimal configuration for testing
    public static let test = RendererConfiguration(
        enableJavaScript: false,
        pageLoadTimeout: 5.0,
        javascriptTimeout: 1.0,
        enablePerformanceMonitoring: false,
        enableDebugLogging: false,
        enablePageCaching: false,
        maxMemoryUsage: 50
    )
}

/// Protocol for renderers that support configuration
protocol ConfigurableRenderer {
    func apply(_ configuration: RendererConfiguration)
}
