import Foundation

/// What one stage of the AI draft changed in the CV, value by value, for the trace of a test build (ADR 0032): each value it
/// removed, changed or added, by the path of its field, and each list whose order it changed. So a trace says "the title of job 2
/// was removed by grounding" rather than "the draft got shorter".
///
/// The entries of a list are matched by their values, not by their place, since a stage that removes the second job moves the
/// third one up: an entry after the stage is the entry before it with the most values in common, and an entry with none in common
/// is a new one. A removed or changed value keeps the index its entry had before the stage; an added one has the index after it.
struct DraftDifference: Equatable, Sendable {
    /// One value that differs, by the path of its field: `experience[1].title`, `skills[0].name`, `person.email`, `summary`.
    struct Change: Equatable, Sendable {
        let path: String
        /// The value before the stage, or nil when the stage added it.
        let before: String?
        /// The value after the stage, or nil when the stage removed it.
        let after: String?
    }

    /// The values the stage removed.
    let removed: [Change]
    /// The values the stage changed.
    let changed: [Change]
    /// The values the stage added.
    let added: [Change]
    /// For each list whose entries came out in another order, the index each entry had before the stage, in their new order:
    /// `experience: 2, 0, 1`, with `+` for a new entry.
    let reordered: [String]

    var isEmpty: Bool { removed.isEmpty && changed.isEmpty && added.isEmpty && reordered.isEmpty }

    init(from before: CVData, to after: CVData) {
        var removed: [Change] = [], changed: [Change] = [], added: [Change] = [], reordered: [String] = []
        for (old, new) in zip(DraftSection.sections(of: before), DraftSection.sections(of: after)) {
            let pairs = old.isList ? DraftSection.match(old.entries, new.entries) : [0: 0]
            for (index, entry) in old.entries.enumerated() {
                let prefix = old.path(index)
                guard let newIndex = pairs.first(where: { $0.value == index })?.key, newIndex < new.entries.count else {
                    removed += entry.values.map { Change(path: prefix + $0.field, before: $0.value, after: nil) }
                    continue
                }
                let difference = entry.difference(to: new.entries[newIndex], beforePrefix: prefix, afterPrefix: new.path(newIndex))
                removed += difference.removed
                changed += difference.changed
                added += difference.added
            }
            for (index, entry) in new.entries.enumerated() where pairs[index] == nil {
                added += entry.values.map { Change(path: new.path(index) + $0.field, before: nil, after: $0.value) }
            }
            let order = new.entries.indices.map { pairs[$0] }
            let matched = order.compactMap { $0 }
            if matched != matched.sorted() {
                reordered.append("\(old.name): " + order.map { $0.map(String.init) ?? "+" }.joined(separator: ", "))
            }
        }
        self.removed = removed
        self.changed = changed
        self.added = added
        self.reordered = reordered
    }
}

/// A part of a CV as entries of named values: one entry for the person or the summary, a list of entries for the jobs, schools,
/// skills, languages, certifications and interests.
private struct DraftSection {
    let name: String
    let isList: Bool
    let entries: [DraftEntry]

    /// The path of an entry, to which a field adds its own name: `experience[1]`, `person`.
    func path(_ index: Int) -> String {
        isList ? "\(name)[\(index)]" : name
    }

    /// Every part of a CV, always in the same order and always all of them, so that two CVs zip part by part.
    static func sections(of cvData: CVData) -> [DraftSection] {
        let info = cvData.personalInfo
        return [
            DraftSection(name: "person", isList: false, entries: [DraftEntry([
                ("name", info.name), ("title", info.title), ("email", info.email), ("phone", info.phone), ("location", info.location),
                ("website", info.website), ("linkedin", info.linkedin), ("github", info.github),
            ])]),
            DraftSection(name: "summary", isList: false, entries: [DraftEntry([("", cvData.summary)])]),
            DraftSection(name: "experience", isList: true, entries: cvData.experience.map { job in
                DraftEntry([
                    ("title", job.title), ("company", job.company), ("location", job.location), ("startDate", job.startDate),
                    ("endDate", job.endDate), ("current", String(job.current)), ("description", job.description),
                ], items: ("achievements", job.achievements), unmatched: ["current"])
            }),
            DraftSection(name: "education", isList: true, entries: cvData.education.map { school in
                DraftEntry([
                    ("degree", school.degree), ("institution", school.institution), ("startDate", school.startDate),
                    ("endDate", school.endDate), ("description", school.description),
                ])
            }),
            DraftSection(name: "skills", isList: true, entries: cvData.skills.map {
                DraftEntry([("name", $0.name), ("level", $0.level?.rawValue)], unmatched: ["level"])
            }),
            DraftSection(name: "languages", isList: true, entries: cvData.languages.map {
                DraftEntry([("name", $0.name), ("proficiency", $0.proficiency?.rawValue)], unmatched: ["proficiency"])
            }),
            DraftSection(name: "certifications", isList: true, entries: cvData.certifications.map {
                DraftEntry([("name", $0.name), ("issuer", $0.issuer), ("date", $0.date), ("url", $0.url)])
            }),
            DraftSection(name: "interests", isList: true, entries: cvData.interests.map { DraftEntry([("", $0)]) }),
        ]
    }

    /// For each entry after a stage, the index of the entry before it that it comes from: the one with the most values in common,
    /// the first of them on a tie, and none when no entry shares a value with it. Each entry before the stage matches once.
    static func match(_ before: [DraftEntry], _ after: [DraftEntry]) -> [Int: Int] {
        var pairs: [Int: Int] = [:]
        var taken = Set<Int>()
        for (index, entry) in after.enumerated() {
            var best: (index: Int, common: Int)?
            for candidate in before.indices where !taken.contains(candidate) {
                let common = entry.common(with: before[candidate])
                if common > (best?.common ?? 0) {
                    best = (candidate, common)
                }
            }
            if let best {
                pairs[index] = best.index
                taken.insert(best.index)
            }
        }
        return pairs
    }
}

/// One entry of a part of a CV: its values by field, in a fixed order, then the items of its list, such as a job's achievements.
private struct DraftEntry {
    struct Value: Equatable {
        /// `.title`, or `.achievements[2]`; empty for an entry that is one value, such as an interest.
        let field: String
        let value: String
    }

    let values: [Value]
    private let fields: [(name: String, value: String?)]
    private let items: (name: String, values: [String])?
    /// The fields that many entries share, such as a level or whether a job goes on now: they say nothing of which entry is which.
    private let unmatched: Set<String>

    init(_ fields: [(String, String?)], items: (String, [String])? = nil, unmatched: Set<String> = []) {
        self.fields = fields.map { (name: $0.0, value: $0.1) }
        self.items = items.map { (name: $0.0, values: $0.1) }
        self.unmatched = unmatched
        let scalars = fields.compactMap { name, value in value.map { Value(field: name.isEmpty ? "" : ".\(name)", value: $0) } }
        let listed = items.map { name, values in values.enumerated().map { Value(field: ".\(name)[\($0.offset)]", value: $0.element) } }
        values = scalars + (listed ?? [])
    }

    /// How many values two entries share: equal fields that are not empty, but those many entries share, and equal items of their
    /// lists.
    func common(with other: DraftEntry) -> Int {
        let fields = zip(self.fields, other.fields).count { mine, theirs in
            !unmatched.contains(mine.name) && mine.value?.isEmpty == false && mine.value == theirs.value
        }
        guard let mine = items?.values, let theirs = other.items?.values else { return fields }
        var left = theirs
        let items = mine.count { item in
            guard let index = left.firstIndex(of: item) else { return false }
            left.remove(at: index)
            return true
        }
        return fields + items
    }

    /// What changed from this entry to the one a stage made of it. Fields compare by name; the items of a list compare by value,
    /// so that a removed achievement is one removal, not a change of every achievement after it.
    func difference(to new: DraftEntry, beforePrefix: String, afterPrefix: String) -> (removed: [DraftDifference.Change],
                                                                                     changed: [DraftDifference.Change],
                                                                                     added: [DraftDifference.Change]) {
        var removed: [DraftDifference.Change] = [], changed: [DraftDifference.Change] = [], added: [DraftDifference.Change] = []
        for (old, current) in zip(fields, new.fields) where old.value != current.value {
            let field = old.name.isEmpty ? "" : ".\(old.name)"
            switch (old.value, current.value) {
            case let (before?, nil):
                removed.append(.init(path: beforePrefix + field, before: before, after: nil))
            case let (nil, after?):
                added.append(.init(path: afterPrefix + field, before: nil, after: after))
            case let (before?, after?):
                changed.append(.init(path: beforePrefix + field, before: before, after: after))
            case (nil, nil):
                break
            }
        }
        if let items, let newItems = new.items?.values {
            var left = newItems.enumerated().map { $0 }
            for (index, item) in items.values.enumerated() {
                if let found = left.firstIndex(where: { $0.element == item }) {
                    left.remove(at: found)
                } else {
                    removed.append(.init(path: beforePrefix + ".\(items.name)[\(index)]", before: item, after: nil))
                }
            }
            added += left.map { .init(path: afterPrefix + ".\(items.name)[\($0.offset)]", before: nil, after: $0.element) }
        }
        return (removed, changed, added)
    }
}
