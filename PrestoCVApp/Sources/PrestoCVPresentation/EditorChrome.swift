/// How much room the editor's notice may take (#402, decision 9). Where the form is short of room (a compact height, as in
/// landscape on an iPhone, or an accessibility text size), the notice above the form takes at most a quarter of the
/// editor's height and scrolls inside, so the form stays in reach; elsewhere it takes what it needs. The view reads the
/// size class, the text size and the heights; the rule is here, where a test reaches it without a screen.
public struct EditorChrome: Hashable, Sendable {
    /// The share of the editor's height the notice takes at most where the form is short of room.
    public static let noticeShareOfHeight = 0.25

    /// Whether the editor's height is compact (an unknown size class is not).
    public let isCompactHeight: Bool
    /// Whether the person reads at an accessibility text size.
    public let isAccessibilitySize: Bool

    public init(isCompactHeight: Bool, isAccessibilitySize: Bool) {
        self.isCompactHeight = isCompactHeight
        self.isAccessibilitySize = isAccessibilitySize
    }

    /// Whether the form is short of room, so that the notice above it is capped.
    public var isShortOfRoom: Bool { isCompactHeight || isAccessibilitySize }

    /// The height the notice is given, or nil when it takes its own: `fullHeight` is the notice's own height, and
    /// `editorHeight` the editor's (0 while it is not known yet).
    public func noticeHeight(fullHeight: Double, editorHeight: Double) -> Double? {
        guard isShortOfRoom, editorHeight > 0 else { return nil }
        return min(fullHeight, editorHeight * Self.noticeShareOfHeight)
    }
}
