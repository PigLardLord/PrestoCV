import SwiftUI
import UIKit
import WebKit
import CVPDFExporter

@MainActor
final class HTMLPreviewCoordinator: NSObject, ObservableObject {
    let webView: WKWebView

    @Published private(set) var isLoading = false

    private var navigationContinuation: CheckedContinuation<Void, Error>?

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.suppressesIncrementalRendering = false

        let controller = configuration.userContentController
        controller.addUserScript(
            WKUserScript(
                source: PreviewReadinessScript.bootstrap,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )
        )
        controller.addUserScript(
            WKUserScript(
                source: PreviewReadinessScript.scalingBootstrap,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )
        )

        self.webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()

        // The page is shown on white paper, as it prints: in a dark interface its default text would be white on white
        webView.overrideUserInterfaceStyle = .light
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.navigationDelegate = self
    }

    func load(html: String, baseURL: URL? = nil) async throws {
        navigationContinuation?.resume(throwing: CancellationError())
        navigationContinuation = nil

        isLoading = true
        defer { isLoading = false }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            navigationContinuation = continuation
            webView.loadHTMLString(html, baseURL: baseURL)
        }

        _ = try? await webView.callAsyncJavaScript(
            PreviewReadinessScript.awaitReady,
            arguments: [:],
            in: nil,
            contentWorld: .page
        )

        _ = try? await webView.evaluateJavaScript("window.__cvPreview && window.__cvPreview.applyScale();")
    }
}

extension HTMLPreviewCoordinator: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        navigationContinuation?.resume(returning: ())
        navigationContinuation = nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        navigationContinuation?.resume(throwing: error)
        navigationContinuation = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        navigationContinuation?.resume(throwing: error)
        navigationContinuation = nil
    }
}

struct HTMLPreviewView: UIViewRepresentable {
    @ObservedObject var coordinator: HTMLPreviewCoordinator

    func makeUIView(context: Context) -> WKWebView {
        coordinator.webView
    }

    /// The scale is applied when a document has loaded and when the web view is resized, by the page's own script;
    /// SwiftUI updates of this view have nothing to do.
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
