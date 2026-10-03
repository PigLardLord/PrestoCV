/// An experience of a source CV, by its position counted from 0. Only a `SourceCV` makes one, so a reference to an
/// experience its snapshot does not have cannot be built. It carries the snapshot that made it: another snapshot
/// refuses it even when its position is in range there, and two equal snapshots share their references.
public struct ExperienceRef: Hashable, Sendable {
    public let index: Int
    let snapshot: Int

    init(index: Int, snapshot: Int) {
        self.index = index
        self.snapshot = snapshot
    }
}

/// A line of an experience of a source CV: "experience n, line m", both counted from 0 (ADR 0013). Only a `SourceCV`
/// makes one. Like an `ExperienceRef`, it carries the snapshot that made it.
public struct StatementRef: Hashable, Sendable {
    public let experience: ExperienceRef
    public let line: Int

    init(experience: ExperienceRef, line: Int) {
        self.experience = experience
        self.line = line
    }
}
