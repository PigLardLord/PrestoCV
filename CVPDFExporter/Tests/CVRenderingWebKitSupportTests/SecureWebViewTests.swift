#if canImport(WebKit)   // Apple platforms only (R11)
import Testing
import Foundation
import WebKit
@testable import CVRenderingWebKitSupport
import CVRenderingNativeTestSupport

/// Every kind of load a page can start, pointing at the test listener, and whether a web view without the rules makes
/// it offscreen. Recorded on iOS 26.5, iOS 27.0, macOS 26 and macOS 27: the table holds on every release the app
/// supports; iOS 26.2, below the minimum, lets the object and embed loads through the rules (`DeploymentTargetTests` in
/// `Tools/SourceChecks` fails if the project or a manifest sets an iOS release below 26.5). The kinds marked false are
/// not loaded even without the rules (a favicon, a prefetch hint, ftp:, which WebKit no longer supports, and media: on
/// iOS an offscreen web view does not fetch it even when a script starts muted, inline playback). None of these can
/// enter the document: the builder's closed tag set has no media, link or icon elements, and a link must be http(s)
/// (R8). If WebKit starts to make one of these loads, the control fails and the kind moves to the loaded ones, where
/// the rules are then proven against it.
let pageLoads: [(kind: String, html: @Sendable (_ base: String, _ port: String) -> String, loadedWithoutRules: Bool)] = [
    ("image", { b, _ in "<img src=\"\(b)/i.png\">" }, true),
    ("stylesheet", { b, _ in "<link rel=\"stylesheet\" href=\"\(b)/s.css\">" }, true),
    ("import", { b, _ in "<style>@import url(\"\(b)/i.css\");</style>" }, true),
    ("font", { b, _ in "<style>@font-face{font-family:R;src:url(\"\(b)/f.woff2\")} p{font-family:R}</style>" }, true),
    ("background", { b, _ in "<style>body{background-image:url(\"\(b)/b.png\")}</style>" }, true),
    ("svg image", { b, _ in "<svg><image href=\"\(b)/s.png\" width=\"10\" height=\"10\"/></svg>" }, true),
    ("script", { b, _ in "<script src=\"\(b)/s.js\"></script>" }, true),
    ("fetch", { b, _ in "<script>fetch(\"\(b)/f\").catch(() => {})</script>" }, true),
    ("websocket", { _, p in "<script>try { new WebSocket(\"ws://127.0.0.1:\(p)/ws\") } catch (e) {}</script>" }, true),
    ("https", { _, p in "<img src=\"https://127.0.0.1:\(p)/i.png\">" }, true),
    ("frame", { b, _ in "<iframe src=\"\(b)/f.html\"></iframe>" }, true),
    ("object", { b, _ in "<object data=\"\(b)/o.pdf\" type=\"application/pdf\"></object>" }, true),
    ("embed", { b, _ in "<embed src=\"\(b)/e.pdf\" type=\"application/pdf\">" }, true),
    ("preload", { b, _ in "<link rel=\"preload\" as=\"image\" href=\"\(b)/p.png\">" }, true),
    ("video", { b, _ in "<video src=\"\(b)/v.mp4\" preload=\"auto\"></video>" }, false),
    ("audio", { b, _ in "<audio src=\"\(b)/a.mp3\" preload=\"auto\"></audio>" }, false),
    ("icon", { b, _ in "<link rel=\"icon\" href=\"\(b)/f.ico\">" }, false),
    ("prefetch", { b, _ in "<link rel=\"prefetch\" href=\"\(b)/p.html\">" }, false),
    ("ftp", { _, p in "<img src=\"ftp://127.0.0.1:\(p)/i.png\">" }, false),
]

/// How a probe web view is set up. `production` is what the renderers use. The two others isolate the rule list: both
/// run JavaScript and allow every navigation, one with the rules and one without, so a load the control makes and the
/// rules-only view does not is one the rules blocked.
enum Setup { case production, rulesOnly, control }

/// A timeout no test reaches: an operation given it that ends early ended for another reason, such as a cancellation.
let unreachedTimeout: Duration = .seconds(3_600)


/// Allows every navigation, as a web view without a delegate does, and tells when the page's own load has ended.
@MainActor
final class PageLoadObserver: NSObject, WKNavigationDelegate {
    private var navigation: WKNavigation?
    private(set) var ended = false

    func load(_ html: String, baseURL: URL?, in view: WKWebView) {
        view.navigationDelegate = self
        navigation = view.loadHTMLString(html, baseURL: baseURL)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { end(navigation) }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) { end(navigation) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) { end(navigation) }

    private func end(_ navigation: WKNavigation?) {
        if navigation === self.navigation { ended = true }
    }
}

/// Tells that a script in the readiness world has started, through the message it posts first.
@MainActor
final class ScriptStart: NSObject, WKScriptMessageHandler {
    static let name = "started"
    private(set) var started = false

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) { started = true }
}

@MainActor
@Suite("#79 · the secure web view on Apple platforms", .serialized, .timeLimit(.minutes(10)))
struct SecureWebViewTests {
    /// A web view with the secure configuration, or with a plain one (JavaScript off, no rules) as the control.
    func webView(secure: Bool) async throws -> WKWebView {
        let configuration: WKWebViewConfiguration
        if secure {
            configuration = SecureWebViewConfiguration.make(rules: try await SecureWebViewConfiguration.compileRules())
        } else {
            configuration = WKWebViewConfiguration()
            configuration.websiteDataStore = .nonPersistent()
            configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        }
        return WKWebView(frame: CGRect(x: 0, y: 0, width: 595, height: 842), configuration: configuration)
    }

    /// Loads `html` and waits until it is ready.
    func load(_ html: String, in view: WKWebView, delegate: SingleLoadNavigationDelegate) async throws {
        try await delegate.load(html, in: view, timeout: patience)
        try await DocumentReadiness.wait(in: view, timeout: patience)
    }

    /// Loads `html` as `setup` does, and returns once the page is ready. The delegate is returned so it stays alive
    /// while the page is inspected: the web view holds it weakly.
    func load(_ html: String, as setup: Setup, baseURL: URL? = nil) async throws -> (WKWebView, NSObject) {
        if setup == .production {
            let view = try await webView(secure: true), delegate = SingleLoadNavigationDelegate()
            try await load(html, in: view, delegate: delegate)
            return (view, delegate)
        }
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        if setup == .rulesOnly { configuration.userContentController.add(try await SecureWebViewConfiguration.compileRules()) }
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 595, height: 842), configuration: configuration)
        let observer = PageLoadObserver()
        observer.load(html, baseURL: baseURL, in: view)
        #expect(await eventually { observer.ended }, "the page did not finish loading")
        try await DocumentReadiness.wait(in: view, timeout: patience)
        return (view, observer)
    }

    /// A page can only be shown to make no request over a window of time. This closes the window: a page without the
    /// rules, loaded after the page under test, makes a request, and the wait ends when the listener has it. A request
    /// the page under test was going to make had at least as long to arrive, however slow the machine.
    func waitForALaterPageToMakeARequest() async throws {
        let counter = try LoopbackListener()
        defer { counter.stop() }
        let base = try await counter.start()
        let (view, observer) = try await load("<p>Probe</p><img src=\"\(base)/probe.png\">", as: .control)
        #expect(await eventually { counter.requestCount > 0 }, "the later page made no request, so the window could not be closed")
        withExtendedLifetime((view, observer)) {}
    }

    @Test("the rule list compiles, and a list that does not compile fails closed")
    func rules() async throws {
        _ = try await SecureWebViewConfiguration.compileRules()
        await #expect(throws: SecureWebViewConfiguration.Failure.contentRulesUnavailable) {
            _ = try await SecureWebViewConfiguration.compile("[{\"trigger\":", identifier: "cv.test.invalid")
        }
    }

    @Test("the configuration keeps no data, runs no content JavaScript, and plays media only on user action")
    func configuration() async throws {
        let configuration = SecureWebViewConfiguration.make(rules: try await SecureWebViewConfiguration.compileRules())
        #expect(!configuration.websiteDataStore.isPersistent)
        #expect(!configuration.defaultWebpagePreferences.allowsContentJavaScript)
        #expect(configuration.mediaTypesRequiringUserActionForPlayback == .all)
    }

    @Test("the rules alone block every load a page can start, and so does production; without the rules, the loads happen",
          arguments: pageLoads.indices)
    func pageLoad(index: Int) async throws {
        let probe = pageLoads[index]
        // The control is loaded last, and every page stays open until the end: the request the control makes closes
        // the window in which the pages with the rules could have made theirs.
        var pages: [(setup: Setup, counter: LoopbackListener, view: WKWebView, delegate: NSObject)] = []
        defer { pages.forEach { $0.counter.stop() } }
        for setup in [Setup.production, .rulesOnly, .control] {
            let counter = try LoopbackListener()
            let base = try await counter.start()
            let port = String(base.split(separator: ":").last ?? "")
            let (view, delegate) = try await load("<p>Loaded</p>" + probe.html(base, port), as: setup)
            pages.append((setup, counter, view, delegate))
            #expect(try await DocumentReadiness.evaluate("return document.body.innerText.trim()", in: view, timeout: patience) == "Loaded")
        }
        let control = pages[pages.count - 1].counter
        if probe.loadedWithoutRules {
            #expect(await eventually { control.requestCount > 0 }, "\(probe.kind): the control made no request, so the test could not see one")
        } else {
            try await waitForALaterPageToMakeARequest()
            #expect(control.count == 0, "\(probe.kind): WebKit now loads this without the rules; mark it as loaded")
        }
        for page in pages where page.setup != .control {
            #expect(page.counter.count == 0, "\(probe.kind), \(page.setup): a load escaped the rules")
        }
    }

    /// Whether a web view without the rules loads a file: image into a page loaded from a string under a file: base URL.
    /// Recorded on iOS 26.5, iOS 27.0, macOS 26.6 and macOS 27.0: it loads on all of them but macOS 27, where WebKit does
    /// not grant such a page read access to its base URL's directory, and so blocks the image before the rules do. The
    /// rules are proven against file: on the releases that still load it. A blob: image loads without the rules on all
    /// four. If WebKit changes either, the control fails and the page's value changes with it.
    static var fileLoadedWithoutRules: Bool {
        #if os(macOS)
        if #available(macOS 27, *) { return false }
        #endif
        return true
    }

    @Test("file: and blob: URLs are blocked by the rules; without them, they load")
    func fileAndBlob() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("web-view-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let png = dir.appendingPathComponent("p.png")
        try #require(Data(base64Encoded: onePixelPNG)).write(to: png)
        let pages: [(kind: String, html: String, baseURL: URL?, loadedWithoutRules: Bool)] = [
            ("file", "<p>Loaded</p><img id=\"i\" src=\"\(png.absoluteString)\">", dir, Self.fileLoadedWithoutRules),   // the base URL grants file access, but not on macOS 27
            ("blob", "<p>Loaded</p><img id=\"i\"><script>const b = new Blob([Uint8Array.from(atob('\(onePixelPNG)'), c => c.charCodeAt(0))], {type: 'image/png'}); document.getElementById('i').src = URL.createObjectURL(b);</script>", nil, true),
        ]
        for page in pages {
            for setup in [Setup.rulesOnly, .control] {
                let (view, _) = try await load(page.html, as: setup, baseURL: page.baseURL)
                let width = try await DocumentReadiness.evaluate("return String(document.getElementById('i').naturalWidth)", in: view, timeout: patience)
                switch setup {
                case .production, .rulesOnly:
                    #expect(width == "0", "\(page.kind), \(setup): the rules let it load")
                case .control where page.loadedWithoutRules:
                    #expect(width == "1", "\(page.kind): the control did not load it, so the test could not see a load")
                case .control:
                    #expect(width == "0", "\(page.kind): WebKit now loads this without the rules; mark it as loaded")
                }
            }
        }
    }

    /// Characterisation: content blockers do not see data: URLs on Apple platforms, whatever the rule list says. A
    /// data: URL is not a network load, and none can enter the document: the builder emits only http(s) links, and the
    /// CSS policy has no url() (R8). If WebKit starts to block them, this test fails and the note in modules.md changes.
    @Test("content blockers do not see data: URLs; the document never contains one")
    func dataScheme() async throws {
        for secure in [true, false] {
            let view = try await webView(secure: secure), delegate = SingleLoadNavigationDelegate()
            try await load("<img id=\"i\" src=\"data:image/png;base64,\(onePixelPNG)\">", in: view, delegate: delegate)
            let width = try await DocumentReadiness.evaluate("return String(document.getElementById('i').naturalWidth)", in: view, timeout: patience)
            #expect(width == "1")
        }
    }

    @Test("only the initial load happens: a meta refresh and a link are cancelled, and nothing is requested")
    func singleLoad() async throws {
        let counter = try LoopbackListener()
        defer { counter.stop() }
        let base = try await counter.start()
        let view = try await webView(secure: false), delegate = SingleLoadNavigationDelegate()   // no rules: the delegate alone
        try await load("<meta http-equiv=\"refresh\" content=\"0; url=\(base)/refresh\"><a id=\"a\" href=\"\(base)/link\">link</a>",
                       in: view, delegate: delegate)
        #expect(await eventually { delegate.cancelledNavigations >= 1 })
        let afterRefresh = delegate.cancelledNavigations
        _ = try await DocumentReadiness.evaluate("document.getElementById('a').click(); return 'clicked'", in: view, timeout: patience)
        #expect(await eventually { delegate.cancelledNavigations > afterRefresh })
        try await waitForALaterPageToMakeARequest()
        #expect(counter.requestCount == 0)
        #expect(view.url?.absoluteString == "about:blank")
        await #expect(throws: SingleLoadNavigationDelegate.Failure.alreadyUsed) { try await delegate.load("<p>again</p>", in: view, timeout: patience) }
    }

    /// As in production, with the rules and the delegate. A document's links and a refresh make no connection at all.
    /// A click is a user's gesture, possible in the preview only: WebKit may open a connection to the link's host
    /// before the navigation is cancelled (a preconnect), but sends nothing over it.
    @Test("in production, links and a refresh do not connect; a clicked link connects at most, and sends nothing")
    func productionNavigation() async throws {
        let counter = try LoopbackListener()
        defer { counter.stop() }
        let base = try await counter.start()
        let view = try await webView(secure: true), delegate = SingleLoadNavigationDelegate()
        try await load("<meta http-equiv=\"refresh\" content=\"0; url=\(base)/refresh\"><p><a id=\"a\" href=\"\(base)/link\">\(base)/link</a></p>",
                       in: view, delegate: delegate)
        try await waitForALaterPageToMakeARequest()
        #expect(counter.count == 0)
        _ = try await DocumentReadiness.evaluate("document.getElementById('a').click(); return 'clicked'", in: view, timeout: patience)
        #expect(await eventually { delegate.cancelledNavigations >= 2 })
        try await waitForALaterPageToMakeARequest()
        #expect(counter.requestCount == 0)
        #expect(view.url?.absoluteString == "about:blank")
    }

    @Test("the readiness script runs in its own world: it cannot see what the page defines")
    func ownWorld() async throws {
        let view = try await webView(secure: true), delegate = SingleLoadNavigationDelegate()
        try await load("<p>World</p>", in: view, delegate: delegate)
        _ = try await view.evaluateJavaScript("window.cvMarker = 'page'", in: nil, contentWorld: .page)
        #expect(try await view.evaluateJavaScript("typeof window.cvMarker", in: nil, contentWorld: .page) as? String == "string")
        #expect(try await DocumentReadiness.evaluate("return typeof window.cvMarker", in: view, timeout: patience) == "undefined")
    }

    @Test("a web view that returns no navigation fails the load at once, and the delegate stays used")
    func noNavigation() async throws {
        final class ClosedWebView: WKWebView {
            override func loadHTMLString(_ string: String, baseURL: URL?) -> WKNavigation? { nil }
        }
        let view = ClosedWebView(frame: .zero, configuration: SecureWebViewConfiguration.make(rules: try await SecureWebViewConfiguration.compileRules()))
        let delegate = SingleLoadNavigationDelegate()
        await #expect(throws: SingleLoadNavigationDelegate.Failure.loadFailed) { try await delegate.load("<p>x</p>", in: view, timeout: .seconds(30)) }
        await #expect(throws: SingleLoadNavigationDelegate.Failure.alreadyUsed) { try await delegate.load("<p>x</p>", in: view, timeout: .seconds(30)) }
    }

    @Test("a load whose task is cancelled stops and fails at once")
    func loadCancelled() async throws {
        let view = try await webView(secure: true), delegate = SingleLoadNavigationDelegate()
        let start = ContinuousClock.now
        let task = Task { @MainActor in try await delegate.load("<p>Cancelled</p>", in: view, timeout: unreachedTimeout) }
        task.cancel()
        let result = await task.result
        #expect(throws: SingleLoadNavigationDelegate.Failure.cancelled) { try result.get() }
        #expect(ContinuousClock.now - start < patience, "the load should end with the cancellation, not with its timeout")
    }

    @Test("a readiness script whose task is cancelled is abandoned at once")
    func readinessCancelled() async throws {
        let view = try await webView(secure: true), delegate = SingleLoadNavigationDelegate()
        let script = ScriptStart()
        view.configuration.userContentController.add(script, contentWorld: DocumentReadiness.world, name: ScriptStart.name)
        try await delegate.load("<p>Waiting</p>", in: view, timeout: patience)
        let neverEnding = "webkit.messageHandlers.\(ScriptStart.name).postMessage(true); await new Promise(() => {}); return 'never'"
        let task = Task { @MainActor in try await DocumentReadiness.evaluate(neverEnding, in: view, timeout: unreachedTimeout) }
        #expect(await eventually { script.started }, "the script did not start")
        let cancelled = ContinuousClock.now
        task.cancel()
        let result = await task.result
        #expect(throws: DocumentReadiness.Failure.cancelled) { _ = try result.get() }
        #expect(ContinuousClock.now - cancelled < patience, "the script should be abandoned with the cancellation, not with its timeout")
    }

    @Test("a readiness script that never finishes times out")
    func timeout() async throws {
        let view = try await webView(secure: true), delegate = SingleLoadNavigationDelegate()
        try await delegate.load("<p>Slow</p>", in: view, timeout: patience)
        let start = ContinuousClock.now
        await #expect(throws: DocumentReadiness.Failure.timedOut) {
            _ = try await DocumentReadiness.evaluate("await new Promise(() => {}); return 'never'", in: view, timeout: .milliseconds(300))
        }
        #expect(ContinuousClock.now - start < patience, "the script should end at its timeout")
    }
}
#endif
