/// An experience of a source CV, by its position counted from 0. Only a `SourceCV` makes one, so a reference to an
/// experience its snapshot does not have cannot be built. It is meaningful only for the snapshot that made it.
public struct ExperienceRef: Hashable, Sendable {
    public let index: Int

    init(index: Int) { self.index = index }
}

/// A line of an experience of a source CV: "experience n, line m", both counted from 0 (ADR 0013). Only a `SourceCV`
/// makes one, and it is meaningful only for the snapshot that made it.
public struct StatementRef: Hashable, Sendable {
    public let experience: ExperienceRef
    public let line: Int

    init(experience: ExperienceRef, line: Int) {
        self.experience = experience
        self.line = line
    }
}
