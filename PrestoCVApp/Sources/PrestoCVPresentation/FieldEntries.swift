/// What the fields of a form were handed last, so that a text handed over twice is one entry (#478). A text field can
/// hand the same text over twice: the second time it comes against the text the field kept, and a pasted text with a
/// line break, kept with a space, would then read as the return key over that space (`FieldEntry`), and the focus would
/// move on. The same text handed over again, while the field still holds what it kept of it, changes nothing. A return
/// key is not remembered, so that it moves on each time it comes.
public struct FieldEntries: Hashable, Sendable {
    private struct Last: Hashable, Sendable {
        let handedOver: String
        let kept: String
    }

    private var last: [EditorField: Last] = [:]

    public init() {}

    /// What `field` keeps when its text `old` became `new`, as `FieldEntry` says, unless `new` is what the field was
    /// handed last and `old` what it kept of it: then the field keeps `old`.
    public mutating func entry(_ new: String, after old: String, in field: EditorField) -> FieldEntry {
        if let last = last[field], last.handedOver == new, last.kept == old { return .text(old) }
        let entry = FieldEntry(new, after: old, in: field)
        switch entry {
        case .text(let kept): last[field] = Last(handedOver: new, kept: kept)
        case .returnKey: last[field] = nil
        }
        return entry
    }
}
