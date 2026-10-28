import Foundation

/// What the second pass had written of its answer when its stream ended (ADR 0031, #354): each part the model has started, in the
/// order of the answer's schema (the technologies, the soft skills, the summary, the roles), nil for a part it has not reached.
///
/// An answer cut by its token limit stops in the middle of its last part: the last skill of a list may be a piece of a word, and the
/// last sentence of a text a piece of a sentence. What a cut answer keeps is every part before its last, whole, and of its last part
/// the whole skills and the whole sentences.
struct WritingSnapshot: Equatable, Sendable {
    struct Role: Equatable, Sendable {
        let number: Int?
        let text: String?
    }

    var technologies: [String]?
    var softSkills: [String]?
    var summary: String?
    var roles: [Role]?

    /// The writing of the snapshot, for the roles of `brief`.
    ///
    /// - Parameter isComplete: Whether the answer ended on its own. When it did not, the part the model was writing is cut as above.
    func writing(for brief: DraftBrief, isComplete: Bool) -> DraftWriting {
        let whole = isComplete ? self : withoutItsCut()
        let answers = (whole.roles ?? []).compactMap { role in
            role.number.flatMap { number in role.text.map { (number: number, text: $0) } }
        }
        return DraftWriting(
            summary: whole.summary,
            roleDescriptions: DraftWritingPrompt.descriptions(answers, of: brief),
            technologies: whole.technologies ?? [], softSkills: whole.softSkills ?? []
        )
    }

    /// The snapshot without the end of the part the model was writing when the answer was cut: the last part it reached.
    private func withoutItsCut() -> WritingSnapshot {
        var whole = self
        if var roles, let last = roles.popLast() {
            if let text = Self.wholeSentences(of: last.text) { roles.append(Role(number: last.number, text: text)) }
            whole.roles = roles
        } else if roles == nil, let summary {
            whole.summary = Self.wholeSentences(of: summary)
        } else if roles == nil, summary == nil, softSkills != nil {
            whole.softSkills = softSkills.map { Array($0.dropLast()) }
        } else if roles == nil, summary == nil, softSkills == nil {
            whole.technologies = technologies.map { Array($0.dropLast()) }
        }
        return whole
    }

    /// The text up to the end of its last whole sentence (a full stop, a question or an exclamation mark, an ellipsis), or nil when
    /// it has none.
    private static func wholeSentences(of text: String?) -> String? {
        guard let text, let end = text.lastIndex(where: { ".!?…".contains($0) }) else { return nil }
        return String(text[...end]).trimmingCharacters(in: .whitespacesAndNewlines).presentValue
    }
}
