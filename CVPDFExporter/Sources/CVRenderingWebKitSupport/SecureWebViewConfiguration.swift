#if canImport(WebKit)   // Apple-only adapter support (PlatformAdapters): the whole file is platform-guarded
import Foundation
import WebKit

/// The only way to configure a web view for rendering (ValidatingBoundary), shared by both Apple renderers and the preview:
/// no network, no JavaScript from the content, no persistent data, and media only on user action.
@MainActor
public enum SecureWebViewConfiguration {
    public enum Failure: Error, Equatable, Sendable { case contentRulesUnavailable }

    /// The schemes a document could reach the network or local data through. Content-blocker patterns have no
    /// alternation, so each gets a block rule of its own. Content blockers do not see data: URLs on Apple platforms
    /// (#79); none can enter the document, because the builder emits only http(s) links and the CSS policy has no url().
    static let blockedSchemes = ["^https?:", "^wss?:", "^ftp:", "^file:", "^data:", "^blob:"]
    /// Every subresource type is blocked too, whatever its URL. The top-level document, loaded from a string with no
    /// base URL, is not a subresource, so it still loads.
    static let blockedResourceTypes = ["image", "style-sheet", "script", "font", "raw", "svg-document", "media", "popup"]

    static let denyNetworkRules: String = {
        var rules = blockedSchemes.map { #"{"trigger":{"url-filter":"\#($0)"},"action":{"type":"block"}}"# }
        let types = blockedResourceTypes.map { "\"\($0)\"" }.joined(separator: ",")
        rules.append(#"{"trigger":{"url-filter":".*","resource-type":[\#(types)]},"action":{"type":"block"}}"#)
        return "[" + rules.joined(separator: ",") + "]"
    }()

    /// Compiled once by the composition root (DIP) and passed to every configuration. A list that cannot be compiled
    /// fails closed: there is no configuration without it.
    public static func compileRules() async throws(Failure) -> WKContentRuleList {
        try await compile(denyNetworkRules, identifier: "cv.deny-network")
    }

    static func compile(_ source: String, identifier: String) async throws(Failure) -> WKContentRuleList {
        guard let store = WKContentRuleListStore.default() else { throw .contentRulesUnavailable }
        let list: WKContentRuleList?
        do { list = try await store.compileContentRuleList(forIdentifier: identifier, encodedContentRuleList: source) }
        catch { throw .contentRulesUnavailable }
        guard let list else { throw .contentRulesUnavailable }
        return list
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

/// Loads the one HTML string a web view renders, and cancels every later navigation: a meta refresh, a link, a
/// redirect or a frame. The web view keeps a weak reference to its navigation delegate, so the caller keeps this
/// object alive for as long as the web view.
@MainActor
public final class SingleLoadNavigationDelegate: NSObject, WKNavigationDelegate {
    public enum Failure: Error, Equatable, Sendable { case alreadyUsed, loadFailed, contentProcessTerminated, timedOut, cancelled }

    private var initialNavigation: WKNavigation?
    private var loadStarted = false, initialLoadAllowed = false, initialResponseAllowed = false
    private var outcome: Result<Void, Failure>?
    private var waiter: CheckedContinuation<Result<Void, Failure>, Never>?
    private var timer: Task<Void, Never>?
    /// How many navigations were cancelled after the initial load, for tests and diagnostics.
    public private(set) var cancelledNavigations = 0

    public override init() {}

    /// Loads `html` with no base URL, so relative URLs resolve to nothing, and returns when that load has finished.
    /// A load that has not finished after `timeout`, or whose task is cancelled, is stopped and fails.
    public func load(_ html: String, in webView: WKWebView, timeout: Duration) async throws(Failure) {
        guard !loadStarted else { throw .alreadyUsed }
        loadStarted = true
        webView.navigationDelegate = self
        // No navigation means nothing will report back, for example on a closed web view: fail now, never wait.
        guard let navigation = webView.loadHTMLString(html, baseURL: nil) else { throw .loadFailed }
        initialNavigation = navigation
        let result = await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<Result<Void, Failure>, Never>) in
                if let outcome { continuation.resume(returning: outcome); return }
                waiter = continuation
                timer = Task { @MainActor [weak self, weak webView] in
                    do { try await Task.sleep(for: timeout) } catch { return }
                    self?.stop(webView, .timedOut)
                }
            }
        } onCancel: {
            Task { @MainActor [weak self, weak webView] in self?.stop(webView, .cancelled) }
        }
        timer?.cancel()
        try result.get()
    }

    private func stop(_ webView: WKWebView?, _ failure: Failure) {
        guard outcome == nil else { return }
        webView?.stopLoading()
        finish(initialNavigation, .failure(failure))
    }

    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        if !initialLoadAllowed, navigationAction.targetFrame?.isMainFrame == true, navigationAction.request.url?.scheme == "about" {
            initialLoadAllowed = true
            return .allow
        }
        cancelledNavigations += 1
        return .cancel
    }

    /// Only the initial document's response is accepted; the action policy already cancels everything else, so this
    /// holds even if that policy changes.
    public func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse) async -> WKNavigationResponsePolicy {
        if !initialResponseAllowed, navigationResponse.isForMainFrame, navigationResponse.response.url?.scheme == "about" {
            initialResponseAllowed = true
            return .allow
        }
        cancelledNavigations += 1
        return .cancel
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { finish(navigation, .success(())) }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        finish(navigation, .failure(.loadFailed))
    }

    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
        finish(navigation, .failure(.loadFailed))
    }

    public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { finish(initialNavigation, .failure(.contentProcessTerminated)) }

    /// Only the initial navigation's outcome counts; a cancelled later navigation also reports a failure.
    private func finish(_ navigation: WKNavigation?, _ result: Result<Void, Failure>) {
        guard let navigation, navigation === initialNavigation, outcome == nil else { return }
        outcome = result
        waiter?.resume(returning: result)
        waiter = nil
    }
}

/// Waits until a loaded document is ready to print: complete, with its fonts ready. The script runs in a content
/// world of its own, so the page can neither see nor change it, and the wait gives up after a timeout.
@MainActor
public enum DocumentReadiness {
    public enum Failure: Error, Equatable, Sendable { case timedOut, scriptFailed, notReady, cancelled }

    public static let world = WKContentWorld.world(name: "cv.readiness")
    static let script = "await document.fonts.ready; return document.readyState === 'complete';"

    public static func wait(in webView: WKWebView, timeout: Duration) async throws(Failure) {
        guard try await evaluate(script, in: webView, timeout: timeout) == "true" else { throw .notReady }
    }

    /// Runs `script` as the body of an async function in the readiness world and returns its result as text: a
    /// boolean as "true" or "false", a string as itself, anything else as nil. On timeout or cancellation the result
    /// is abandoned rather than awaited. WebKit cannot cancel a script, so until it settles the pending call keeps its
    /// web view; the readiness script only awaits the fonts, which settle once their loads finish or fail.
    static func evaluate(_ script: String, in webView: WKWebView, timeout: Duration) async throws(Failure) -> String? {
        let first = FirstResult<Result<String?, Failure>>()
        let result = await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<Result<String?, Failure>, Never>) in
                first.start(continuation)
                let timer = Task { @MainActor in
                    do { try await Task.sleep(for: timeout) } catch { return }
                    first.resume(.failure(.timedOut))
                }
                Task { @MainActor in
                    do {
                        let value = try await webView.callAsyncJavaScript(script, contentWorld: world)
                        first.resume(.success((value as? Bool).map { String($0) } ?? value as? String))
                    } catch {
                        first.resume(.failure(.scriptFailed))
                    }
                    timer.cancel()
                }
            }
        } onCancel: {
            Task { @MainActor in first.resume(.failure(.cancelled)) }
        }
        return try result.get()
    }
}

/// Resumes a continuation once, with whichever result comes first. A result that arrives before the continuation is
/// kept, and resumes it as soon as it starts.
@MainActor
private final class FirstResult<Value: Sendable> {
    private var continuation: CheckedContinuation<Value, Never>?
    private var early: Value?, done = false
    func start(_ continuation: CheckedContinuation<Value, Never>) {
        if let early { continuation.resume(returning: early); done = true } else { self.continuation = continuation }
    }
    func resume(_ value: Value) {
        guard !done else { return }
        guard let continuation else { if early == nil { early = value }; return }
        continuation.resume(returning: value)
        self.continuation = nil
        done = true
    }
}
#endif
