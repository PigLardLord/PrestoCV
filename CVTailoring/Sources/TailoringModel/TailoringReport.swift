/// The model's account of a tailoring: the one argument the CV makes, and what it cut, moved and reworded. It is what
/// the model says it did, kept to show the user; nothing checks it against the CV.
public struct TailoringReport: Hashable, Sendable {
    public let argument: String
    public let cut: [String]
    public let moved: [String]
    public let reworded: [String]

    /// Each list holds at most `TailoringLimits.maxEntriesPerSection` items, and each text is bounded (R8).
    public init(argument: String, cut: [String], moved: [String], reworded: [String]) throws(TailoringModelError) {
        try Bounds.text(argument, .argument)
        try Bounds.texts(cut, .reportItem, atMost: TailoringLimits.maxEntriesPerSection, .cut)
        try Bounds.texts(moved, .reportItem, atMost: TailoringLimits.maxEntriesPerSection, .moved)
        try Bounds.texts(reworded, .reportItem, atMost: TailoringLimits.maxEntriesPerSection, .reworded)
        self.argument = argument
        self.cut = cut
        self.moved = moved
        self.reworded = reworded
    }
}
