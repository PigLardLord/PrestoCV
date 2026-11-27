import Foundation

/// One CV of the list, as app values. The CV itself stays in the list's view model.
public struct CVRow: Hashable, Sendable, Identifiable {
    public let reference: CVReference
    /// The text the row shows as its title, in the view's words: no other row of the list shows the same (the domain's
    /// `CVTitle.labels`).
    public let label: String
    /// The title the person gave, empty when none: the rename starts from it, never from the label.
    public let title: String
    /// The line under the title, by the domain's rule (`CVSubtitle`); empty when it has none.
    public let subtitle: String
    /// When the store saved the CV last. The view words the time since, from the list's `now`.
    public let lastSaved: Date?
    /// The tag of the language the document is written in, nil when automatic.
    public let language: String?

    public var id: CVReference { reference }
}
