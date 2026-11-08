#if canImport(WebKit)   // Apple platforms only (R11)
import Foundation
import Network
import Synchronization
import WebKit

/// A local TCP port that counts connections, and the requests sent over them. The pages under test point every
/// resource at it, so anything that escapes the web view shows up. WebKit may open a connection ahead of a navigation
/// (a preconnect) without sending anything, so a connection alone is not a request.
public final class LoopbackListener: Sendable {
    private let listener: NWListener
    private let connections = Mutex(0), requests = Mutex(0), started = Mutex(false)
    public var count: Int { connections.withLock { $0 } }
    public var requestCount: Int { requests.withLock { $0 } }

    public init() throws {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: .any)
        listener = try NWListener(using: parameters)
    }

    /// Starts listening; returns the base URL the pages use.
    public func start() async throws -> String {
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

    public func stop() { listener.cancel() }
}

/// The bound on a wait for something that must happen. It is generous: it costs time only when the code is broken, and the
/// first page a newly created simulator loads has taken more than a minute.
public let patience: Duration = .seconds(300)

/// Waits until `condition` holds or `timeout` passes, and says which. A slow machine then delays a test instead of
/// failing it.
@MainActor public func eventually(within timeout: Duration = patience, _ condition: () -> Bool) async -> Bool {
    let deadline = ContinuousClock.now + timeout
    while !condition() {
        guard ContinuousClock.now < deadline else { return false }
        do { try await Task.sleep(for: .milliseconds(50)) } catch { return condition() }
    }
    return true
}

/// A PNG of one pixel, in base64.
public let onePixelPNG = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="

/// A page can only be shown to make no request over a window of time. This closes the window: a page without the
/// rules, loaded after the page under test, makes a request to a listener of its own, and the wait ends when the
/// listener has it. A request the page under test was going to make had at least as long to arrive, however slow the
/// machine. Says whether the later page's request arrived within `patience`.
@MainActor public func laterPageMakesARequest() async throws -> Bool {
    let listener = try LoopbackListener()
    defer { listener.stop() }
    let base = try await listener.start()
    let configuration = WKWebViewConfiguration()
    configuration.websiteDataStore = .nonPersistent()
    let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 595, height: 842), configuration: configuration)
    _ = view.loadHTMLString("<p>Probe</p><img src=\"\(base)/probe.png\">", baseURL: nil)
    let arrived = await eventually { listener.requestCount > 0 }
    withExtendedLifetime(view) {}
    return arrived
}
#endif
