import Foundation
import CVPDFExporter

// MARK: - Platform Renderer Provider

/// This demonstrates how the consuming app provides its own renderer implementation
/// The library doesn't know about UIKit/AppKit - complete dependency inversion

#if canImport(UIKit) && canImport(WebKit)
import UIKit
import WebKit

/// iOS implementation of HTMLToPDFRenderer
/// This lives in the app, not the library
@MainActor
final class iOSPDFRenderer: HTMLToPDFRenderer {

    nonisolated init() {}

    func renderToPDF(html: String, options: ExportOptions) async throws -> Data {
        let configuration = WKWebViewConfiguration()
        configuration.suppressesIncrementalRendering = true

        let frame = CGRect(x: 0, y: 0, width: options.pageSize.width, height: options.pageSize.height)
        let webView = WKWebView(frame: frame, configuration: configuration)

        // Load and wait
        webView.loadHTMLString(html, baseURL: nil)
        try await Task.sleep(nanoseconds: 500_000_000) // Simple wait for demo

        // Generate PDF
        let printFormatter = webView.viewPrintFormatter()
        let renderer = UIPrintPageRenderer()
        renderer.addPrintFormatter(printFormatter, startingAtPageAt: 0)

        let paperRect = CGRect(x: 0, y: 0, width: options.pageSize.width, height: options.pageSize.height)
        let printableRect = CGRect(
            x: options.margins.left,
            y: options.margins.top,
            width: options.pageSize.width - options.margins.left - options.margins.right,
            height: options.pageSize.height - options.margins.top - options.margins.bottom
        )

        renderer.setValue(paperRect, forKey: "paperRect")
        renderer.setValue(printableRect, forKey: "printableRect")

        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, paperRect, nil)

        for pageIndex in 0..<renderer.numberOfPages {
            UIGraphicsBeginPDFPage()
            let bounds = UIGraphicsGetPDFContextBounds()
            renderer.drawPage(at: pageIndex, in: bounds)
        }

        UIGraphicsEndPDFContext()

        return pdfData as Data
    }
}

#elseif canImport(AppKit) && canImport(WebKit)
import AppKit
import WebKit

/// macOS implementation of HTMLToPDFRenderer
/// This lives in the app, not the library
@MainActor
final class macOSPDFRenderer: HTMLToPDFRenderer {

    nonisolated init() {}

    func renderToPDF(html: String, options: ExportOptions) async throws -> Data {
        let configuration = WKWebViewConfiguration()
        configuration.suppressesIncrementalRendering = true

        let frame = NSRect(x: 0, y: 0, width: options.pageSize.width, height: options.pageSize.height)
        let webView = WKWebView(frame: frame, configuration: configuration)

        // Load and wait
        webView.loadHTMLString(html, baseURL: nil)
        try await Task.sleep(nanoseconds: 500_000_000) // Simple wait for demo

        // Generate PDF using NSView's dataWithPDF
        let printRect = NSRect(x: 0, y: 0, width: options.pageSize.width, height: options.pageSize.height)
        return webView.dataWithPDF(inside: printRect)
    }
}

#else

/// Fallback renderer for unsupported platforms
/// Shows that the library can work anywhere with any renderer
final class StubPDFRenderer: HTMLToPDFRenderer, @unchecked Sendable {

    init() {}

    func renderToPDF(html: String, options: ExportOptions) async throws -> Data {
        // Return a minimal valid PDF
        let pdf = """
        %PDF-1.4
        1 0 obj
        << /Type /Catalog /Pages 2 0 R >>
        endobj
        2 0 obj
        << /Type /Pages /Kids [3 0 R] /Count 1 >>
        endobj
        3 0 obj
        << /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] >>
        endobj
        xref
        0 4
        0000000000 65535 f
        0000000010 00000 n
        0000000053 00000 n
        0000000102 00000 n
        trailer
        << /Size 4 /Root 1 0 R >>
        startxref
        164
        %%EOF
        """
        return pdf.data(using: .utf8) ?? Data()
    }
}

#endif

// MARK: - Renderer Factory

/// Factory to create platform-appropriate renderer
/// This is app code, not library code
public struct PlatformRendererFactory {

    public static func createRenderer() -> HTMLToPDFRenderer {
        #if canImport(UIKit)
        return iOSPDFRenderer()
        #elseif canImport(AppKit)
        return macOSPDFRenderer()
        #else
        return StubPDFRenderer()
        #endif
    }

    public static var rendererName: String {
        #if canImport(UIKit)
        return "iOS PDF Renderer (UIKit)"
        #elseif canImport(AppKit)
        return "macOS PDF Renderer (AppKit)"
        #else
        return "Stub PDF Renderer"
        #endif
    }
}