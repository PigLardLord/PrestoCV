#if canImport(WebKit)
import WebKit

/// The only way to configure a web view for rendering (R8). Shared by both Apple renderers and the preview.
/// NOT COMPILED OR TESTED YET: the prototype only runs on Linux. Block rules were exercised on WebKitGTK
/// by the security review; Apple builds must re-run that check.
@MainActor
public enum SecureWebViewConfiguration {
    public enum Failure: Error { case contentRulesUnavailable }

    /// Content-blocker regexes have no alternation: one rule per network scheme, plus a catch-all for
    /// every subresource type. The top-level document (loaded from a string, base URL nil) is not blocked.
    static let denyNetworkRules: String = {
        let schemes = ["^https?:", "^wss?:", "^ftp:", "^file:", "^data:", "^blob:"]
        var rules = schemes.map { #"{"trigger":{"url-filter":"\#($0)"},"action":{"type":"block"}}"# }
        rules.append(#"{"trigger":{"url-filter":".*","resource-type":["image","style-sheet","script","font","raw","svg-document","media","popup"]},"action":{"type":"block"}}"#)
        return "[" + rules.joined(separator: ",") + "]"
    }()

    /// Compiled once by the composition root (R4) and passed to every configuration.
    public static func compileRules() async throws -> WKContentRuleList {
        guard let store = WKContentRuleListStore.default(),
              let rules = try await store.compileContentRuleList(forIdentifier: "cv.deny-network",
                                                                 encodedContentRuleList: denyNetworkRules) else {
            throw Failure.contentRulesUnavailable
        }
        return rules
    }

    public static func make(rules: WKContentRuleList) -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        configuration.userContentController.add(rules)
        return configuration
    }
}

/// Allows the single initial load of the HTML string and cancels every later navigation
/// (meta refresh, link activation, redirects).
@MainActor
public final class SingleLoadNavigationDelegate: NSObject, WKNavigationDelegate {
    private var initialLoadStarted = false
    public override init() {}

    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                        decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        if !initialLoadStarted, navigationAction.request.url?.scheme ?? "about" == "about" {
            initialLoadStarted = true
            decisionHandler(.allow)
        } else {
            decisionHandler(.cancel)
        }
    }
}
#endif
