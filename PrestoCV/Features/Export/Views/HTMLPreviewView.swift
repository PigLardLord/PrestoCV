import SwiftUI
import WebKit
import CVPDFExporter

@MainActor
final class HTMLPreviewCoordinator: NSObject, ObservableObject {
    let webView: WKWebView

    @Published private(set) var isLoading: Bool = false

    private var navigationContinuation: CheckedContinuation<Void, Error>?

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.suppressesIncrementalRendering = false

        self.webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()

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

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                navigationContinuation = continuation
                webView.loadHTMLString(html, baseURL: baseURL)
            }

            if #available(iOS 15.0, *) {
                let waitScript = """
                    (function() {
                        const awaitFonts = () => {
                            if (document.fonts && document.fonts.ready) {
                                return document.fonts.ready.catch(() => {});
                            }
                            return Promise.resolve();
                        };

                        const awaitImages = () => {
                            const images = Array.from(document.images || []);
                            if (images.length === 0) { return Promise.resolve(); }
                            return Promise.all(images.map(image => {
                                if (image.complete) { return Promise.resolve(); }
                                return new Promise(resolve => {
                                    image.addEventListener('load', resolve, { once: true });
                                    image.addEventListener('error', resolve, { once: true });
                                });
                            }));
                        };

                        const awaitDom = () => {
                            if (document.readyState === 'complete') {
                                return Promise.resolve();
                            }
                            return new Promise(resolve => {
                                window.addEventListener('load', () => resolve(), { once: true });
                            });
                        };

                        return Promise.all([awaitDom(), awaitFonts(), awaitImages()])
                            .then(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
                    })();
                """

                _ = try? await webView.callAsyncJavaScript(
                    waitScript,
                    arguments: [:],
                    in: nil,
                    contentWorld: .page
                )
            } else {
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s grace period for older OS versions
            }
        }
    }

    func exportPDF(options: ExportOptions) async throws -> Data {
        guard #available(iOS 14.0, *) else {
            throw PDFExportError.renderingFailed("PDF export requires iOS 14 or later")
        }

        let configuration = WKPDFConfiguration()
        return try await withCheckedThrowingContinuation { continuation in
            webView.createPDF(configuration: configuration) { result in
                continuation.resume(with: result)
            }
        }
    }
}

// MARK: - WKNavigationDelegate

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

// MARK: - SwiftUI Wrapper

struct HTMLPreviewView: UIViewRepresentable {
    @ObservedObject var coordinator: HTMLPreviewCoordinator

    func makeUIView(context: Context) -> WKWebView {
        coordinator.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
