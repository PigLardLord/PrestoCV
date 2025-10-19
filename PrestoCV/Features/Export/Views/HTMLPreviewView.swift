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

        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.navigationDelegate = self
    }

    func load(html: String, baseURL: URL? = nil) async throws {
        navigationContinuation?.resume(throwing: CancellationError())
        navigationContinuation = nil

        isLoading = true

        do {
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

            #if DEBUG
            await dumpRenderedHTML()
            #endif

            _ = try? await webView.evaluateJavaScript("window.__cvPreview && window.__cvPreview.applyScale();")

            isLoading = false
        } catch {
            isLoading = false
            throw error
        }
    }

    #if DEBUG
    private func dumpRenderedHTML() async {
        do {
            let html = try await webView.evaluateJavaScript("document.documentElement.outerHTML") as? String
            guard let html else {
                print("[PreviewDump] Failed to capture HTML: unexpected result type")
                return
            }
            
            print("\n[PreviewDump] BEGIN HTML\n\(html)\n[PreviewDump] END HTML\n")
            UIPasteboard.general.string = html
            print("[PreviewDump] Copied HTML to pasteboard.")
        } catch {
            print("[PreviewDump] Failed to capture HTML: \(error)")
        }
    }
    #endif
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

    func updateUIView(_ uiView: WKWebView, context: Context) {
        Task {
            #if DEBUG
            _ = try? await uiView.evaluateJavaScript("window.__cvPreview && window.__cvPreview.reset();")
            #endif
            _ = try? await uiView.evaluateJavaScript("window.__cvPreview && window.__cvPreview.applyScale();")
        }
    }
}
