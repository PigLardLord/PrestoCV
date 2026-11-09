/// Time the system grants the app to end its work after the person left it, before it suspends the app. The shell asks
/// for it while it stores the open CV on its way to the background, so that a write begun is not cut off (#402).
public protocol BackgroundTime: Sendable {
    /// Asks for time from now until the hold returned ends, or until the system takes it back first.
    @MainActor func hold() -> BackgroundHold
}

/// Time asked for with `BackgroundTime.hold()`, kept until `end()`. Ending it more than once ends it once.
@MainActor
public final class BackgroundHold {
    private var ending: (@MainActor () -> Void)?

    /// - Parameter end: Gives the time back to the system; it is called once, by the first `end()`.
    public init(end: @escaping @MainActor () -> Void) {
        ending = end
    }

    /// Gives the time back to the system, unless it was given back already.
    public func end() {
        guard let ending else { return }
        self.ending = nil
        ending()
    }
}
