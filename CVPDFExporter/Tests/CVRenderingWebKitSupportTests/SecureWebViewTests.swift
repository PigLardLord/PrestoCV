#if canImport(WebKit)   // Apple platforms only (R11)
import Testing
import Foundation
import Network
import Synchronization
import WebKit
@testable import CVRenderingWebKitSupport

/// A local TCP port that counts connections, and the requests sent over them. The pages under test point every
/// resource at it, so anything that escapes the web view shows up. WebKit may open a connection ahead of a navigation
/// (a preconnect) without sending anything, so a connection alone is not a request.
final class ConnectionCounter: Sendable {
    private let listener: NWListener
    private let connections = Mutex(0), requests = Mutex(0), started = Mutex(false)
    var count: Int { connections.withLock { $0 } }
    var requestCount: Int { requests.withLock { $0 } }

    init() throws {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: .any)
        listener = try NWListener(using: parameters)
    }

    /// Starts listening; returns the base URL the pages use.
    func start() async throws -> String {
        let port: UInt16 = try await withCheckedThrowingContinuation { continuation in
            listener.stateUpdateHandler = { [self] state in
                let result: Result<UInt16, any Error>?
                switch state {
                case .ready: result = listener.port.map { .success($0.rawValue) } ?? .failure(NWError.posix(.EADDRNOTAVAIL))
                case .failed(let error): result = .failure(error)
                default: result = nil
                }
                guard let result, started.withLock({ was in defer { was = true }; return !was }) else { return }
                continuation.resume(with: result)
            }
            listener.newConnectionHandler = { [self] connection in
                connections.withLock { $0 += 1 }
                connection.start(queue: .global())
                connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [self] data, _, _, _ in
                    guard let data, !data.isEmpty else { connection.cancel(); return }
                    requests.withLock { $0 += 1 }
                    // A prompt answer, so a web view does not retry or wait on a resource that blocks rendering.
                    let notFound = Data("HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".utf8)
                    connection.send(content: notFound, completion: .contentProcessed { _ in connection.cancel() })
                }
            }
            listener.start(queue: .global())
        }
        return "http://127.0.0.1:\(port)"
    }

    func stop() { listener.cancel() }
}

/// Every kind of load a page can start, pointing at the test listener, and whether a web view without the rules makes it
/// offscreen. Recorded on iOS 26.5 and macOS 26: the kinds marked false are not loaded even without the rules (a
/// favicon, a prefetch hint, ftp:, which WebKit no longer supports, and media: on iOS an offscreen web view does not
/// fetch it even when a script starts muted, inline playback). None of these can enter the document: the builder's
/// closed tag set has no media, link or icon elements, and a link must be http(s) (R8). If WebKit starts to make one of
/// these loads, the control fails and the kind moves to the loaded ones, where the rules are then proven against it.
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
enum Setup: CaseIterable { case production, rulesOnly, control }

/// Waits until `condition` holds or `timeout` passes, and says which. A slow machine then delays a test instead of
/// failing it.
@MainActor func eventually(within timeout: Duration = .seconds(5), _ condition: () -> Bool) async -> Bool {
    let deadline = ContinuousClock.now + timeout
    while !condition() {
        guard ContinuousClock.now < deadline else { return false }
        do { try await Task.sleep(for: .milliseconds(50)) } catch { return condition() }
    }
    return true
}

let onePixelPNG = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="

@MainActor
@Suite("#79 · the secure web view on Apple platforms", .serialized, .timeLimit(.minutes(2)))
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

    /// Loads `html`, waits until it is ready, then lets late requests arrive.
    func load(_ html: String, in view: WKWebView, delegate: SingleLoadNavigationDelegate) async throws {
        try await delegate.load(html, in: view, timeout: .seconds(60))   // generous: a cold simulator starts its web content slowly
        try await DocumentReadiness.wait(in: view, timeout: .seconds(10))
        try await Task.sleep(for: .milliseconds(500))
    }

    /// Loads `html` as `setup` does, and returns once the page is ready and late requests have had time to arrive. The
    /// production delegate is returned so it stays alive while the page is inspected.
    func load(_ html: String, as setup: Setup, baseURL: URL? = nil) async throws -> (WKWebView, SingleLoadNavigationDelegate?) {
        if setup == .production {
            let view = try await webView(secure: true), delegate = SingleLoadNavigationDelegate()
            try await load(html, in: view, delegate: delegate)
            return (view, delegate)
        }
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        if setup == .rulesOnly { configuration.userContentController.add(try await SecureWebViewConfiguration.compileRules()) }
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 595, height: 842), configuration: configuration)
        view.loadHTMLString(html, baseURL: baseURL)
        try await Task.sleep(for: .milliseconds(200))
        #expect(await eventually(within: .seconds(60)) { !view.isLoading }, "the page did not finish loading")
        try await DocumentReadiness.wait(in: view, timeout: .seconds(10))
        try await Task.sleep(for: .milliseconds(500))
        return (view, nil)
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
        for setup in Setup.allCases {
            let counter = try ConnectionCounter()
            defer { counter.stop() }
            let base = try await counter.start()
            let port = String(base.split(separator: ":").last ?? "")
            let (view, delegate) = try await load("<p>Loaded</p>" + probe.html(base, port), as: setup)
            #expect(try await DocumentReadiness.evaluate("return document.body.innerText.trim()", in: view, timeout: .seconds(5)) == "Loaded")
            switch setup {
            case .production, .rulesOnly:
                #expect(counter.count == 0, "\(probe.kind), \(setup): a load escaped the rules")
            case .control where probe.loadedWithoutRules:
                #expect(await eventually { counter.requestCount > 0 }, "\(probe.kind): the control made no request, so the test could not see one")
            case .control:
                #expect(counter.count == 0, "\(probe.kind): WebKit now loads this without the rules; mark it as loaded")
            }
            withExtendedLifetime(delegate) {}
        }
    }

    @Test("file: and blob: URLs are blocked by the rules; without them, they load")
    func fileAndBlob() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("web-view-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let png = dir.appendingPathComponent("p.png")
        try #require(Data(base64Encoded: onePixelPNG)).write(to: png)
        let pages: [(kind: String, html: String, baseURL: URL?)] = [
            ("file", "<p>Loaded</p><img id=\"i\" src=\"\(png.absoluteString)\">", dir),   // the base URL grants file access
            ("blob", "<p>Loaded</p><img id=\"i\"><script>const b = new Blob([Uint8Array.from(atob('\(onePixelPNG)'), c => c.charCodeAt(0))], {type: 'image/png'}); document.getElementById('i').src = URL.createObjectURL(b);</script>", nil),
        ]
        for page in pages {
            for setup in [Setup.rulesOnly, .control] {
                let (view, _) = try await load(page.html, as: setup, baseURL: page.baseURL)
                let width = try await DocumentReadiness.evaluate("return String(document.getElementById('i').naturalWidth)", in: view, timeout: .seconds(5))
                #expect(width == (setup == .rulesOnly ? "0" : "1"), "\(page.kind), \(setup)")
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
            let width = try await DocumentReadiness.evaluate("return String(document.getElementById('i').naturalWidth)", in: view, timeout: .seconds(5))
            #expect(width == "1")
        }
    }

    @Test("only the initial load happens: a meta refresh and a link are cancelled, and nothing is requested")
    func singleLoad() async throws {
        let counter = try ConnectionCounter()
        defer { counter.stop() }
        let base = try await counter.start()
        let view = try await webView(secure: false), delegate = SingleLoadNavigationDelegate()   // no rules: the delegate alone
        try await load("<meta http-equiv=\"refresh\" content=\"0; url=\(base)/refresh\"><a id=\"a\" href=\"\(base)/link\">link</a>",
                       in: view, delegate: delegate)
        #expect(await eventually { delegate.cancelledNavigations >= 1 })
        let afterRefresh = delegate.cancelledNavigations
        _ = try await DocumentReadiness.evaluate("document.getElementById('a').click(); return 'clicked'", in: view, timeout: .seconds(5))
        #expect(await eventually { delegate.cancelledNavigations > afterRefresh })
        try await Task.sleep(for: .seconds(1))   // the window in which a request would arrive
        #expect(counter.requestCount == 0)
        #expect(view.url?.absoluteString == "about:blank")
        await #expect(throws: SingleLoadNavigationDelegate.Failure.alreadyUsed) { try await delegate.load("<p>again</p>", in: view, timeout: .seconds(20)) }
    }

    /// As in production, with the rules and the delegate. A document's links and a refresh make no connection at all.
    /// A click is a user's gesture, possible in the preview only: WebKit may open a connection to the link's host
    /// before the navigation is cancelled (a preconnect), but sends nothing over it.
    @Test("in production, links and a refresh do not connect; a clicked link connects at most, and sends nothing")
    func productionNavigation() async throws {
        let counter = try ConnectionCounter()
        defer { counter.stop() }
        let base = try await counter.start()
        let view = try await webView(secure: true), delegate = SingleLoadNavigationDelegate()
        try await load("<meta http-equiv=\"refresh\" content=\"0; url=\(base)/refresh\"><p><a id=\"a\" href=\"\(base)/link\">\(base)/link</a></p>",
                       in: view, delegate: delegate)
        #expect(counter.count == 0)
        _ = try await DocumentReadiness.evaluate("document.getElementById('a').click(); return 'clicked'", in: view, timeout: .seconds(5))
        #expect(await eventually { delegate.cancelledNavigations >= 2 })
        try await Task.sleep(for: .seconds(1))   // the window in which a request would arrive
        #expect(counter.requestCount == 0)
        #expect(view.url?.absoluteString == "about:blank")
    }

    @Test("the readiness script runs in its own world: it cannot see what the page defines")
    func ownWorld() async throws {
        let view = try await webView(secure: true), delegate = SingleLoadNavigationDelegate()
        try await load("<p>World</p>", in: view, delegate: delegate)
        _ = try await view.evaluateJavaScript("window.cvMarker = 'page'", in: nil, contentWorld: .page)
        #expect(try await view.evaluateJavaScript("typeof window.cvMarker", in: nil, contentWorld: .page) as? String == "string")
        #expect(try await DocumentReadiness.evaluate("return typeof window.cvMarker", in: view, timeout: .seconds(5)) == "undefined")
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
        let task = Task { @MainActor in try await delegate.load("<p>Cancelled</p>", in: view, timeout: .seconds(30)) }
        task.cancel()
        let result = await task.result
        #expect(throws: SingleLoadNavigationDelegate.Failure.cancelled) { try result.get() }
        #expect(ContinuousClock.now - start < .seconds(5))
    }

    @Test("a readiness script whose task is cancelled is abandoned at once")
    func readinessCancelled() async throws {
        let view = try await webView(secure: true), delegate = SingleLoadNavigationDelegate()
        try await delegate.load("<p>Waiting</p>", in: view, timeout: .seconds(20))
        let start = ContinuousClock.now
        let task = Task { @MainActor in try await DocumentReadiness.evaluate("await new Promise(() => {}); return 'never'", in: view, timeout: .seconds(30)) }
        try await Task.sleep(for: .milliseconds(200))
        task.cancel()
        let result = await task.result
        #expect(throws: DocumentReadiness.Failure.cancelled) { _ = try result.get() }
        #expect(ContinuousClock.now - start < .seconds(5))
    }

    @Test("a readiness script that never finishes times out")
    func timeout() async throws {
        let view = try await webView(secure: true), delegate = SingleLoadNavigationDelegate()
        try await delegate.load("<p>Slow</p>", in: view, timeout: .seconds(20))
        let start = ContinuousClock.now
        await #expect(throws: DocumentReadiness.Failure.timedOut) {
            _ = try await DocumentReadiness.evaluate("await new Promise(() => {}); return 'never'", in: view, timeout: .milliseconds(300))
        }
        #expect(ContinuousClock.now - start < .seconds(5))
    }
}
#endif
