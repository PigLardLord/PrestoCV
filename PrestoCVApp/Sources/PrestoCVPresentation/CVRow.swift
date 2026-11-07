import Foundation
internal import PrestoCVDomain

/// What a row is called: a text of the CV, or none, which the view words as "Untitled CV" (R13).
public enum RowTitle: Hashable, Sendable {
    case text(String)
    case untitled
}

/// One CV of the list, as app values. The CV itself stays in the list's view model.
public struct CVRow: Hashable, Sendable, Identifiable {
    public let reference: CVReference
    public let title: RowTitle
    /// Which of the rows that read alike this is, from 2; nil for the first. The view words it.
    public let number: Int?
    /// The professional title of the person, or empty when the row is called by it.
    public let subtitle: String
    /// When the store saved the CV last. The view words the time since, from the list's `now`.
    public let lastSaved: Date?
    /// The tag of the language the document is written in, nil when automatic.
    public let language: String?

    public var id: CVReference { reference }
}

extension RowTitle {
    init(_ title: CVTitle) {
        switch title {
        case .name(let text), .person(let text), .role(let text): self = .text(text)
        case .untitled: self = .untitled
        }
    }
}
