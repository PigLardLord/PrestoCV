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

    /// The text up to the end of its last whole sentence, or nil when it has none.
    private static func wholeSentences(of text: String?) -> String? {
        guard let text else { return nil }
        let characters = Array(text)
        for index in characters.indices.reversed() {
            if let end = sentenceEnd(at: index, in: characters) {
                return String(characters[...end]).trimmingCharacters(in: .whitespacesAndNewlines).presentValue
            }
        }
        return nil
    }

    private static let terminators: Set<Character> = [".", "!", "?", "…"]
    private static let closers: Set<Character> = ["\"", "'", "”", "’", "»", ")", "]"]

    /// Where the sentence that the character at `index` ends stops, its closing quotes and brackets included, or nil when it ends none.
    /// A full stop, a question or an exclamation mark, or an ellipsis ends a sentence when it is the last of its run, and a space or the
    /// end of the cut text follows it (with its closing quotes): "3.5" and the stop inside "e.g" end none. A word in lower case after
    /// it continues the sentence ("e.g. wounds", "esp. legs"). A full stop alone after an abbreviation ends none either: one with a stop
    /// inside ("e.g.", "z.B."), a single letter ("U.S" up to its cut), or one of `abbreviations`.
    private static func sentenceEnd(at index: Int, in characters: [Character]) -> Int? {
        guard terminators.contains(characters[index]),
              index + 1 == characters.count || !terminators.contains(characters[index + 1]) else { return nil }
        var end = index
        while end + 1 < characters.count, closers.contains(characters[end + 1]) { end += 1 }
        if end + 1 < characters.count {
            guard characters[end + 1].isWhitespace else { return nil }
            if let following = characters[(end + 1)...].first(where: { !$0.isWhitespace }), following.isLowercase { return nil }
        }
        var start = index
        while start > 0, terminators.contains(characters[start - 1]) { start -= 1 }
        guard start == index, characters[index] == "." else { return end }
        let word = String(characters[..<start].reversed().prefix { !$0.isWhitespace }.reversed())
            .drop { !$0.isLetter && !$0.isNumber }
        let isAbbreviation = word.contains(".") || (word.count == 1 && word.allSatisfy(\.isLetter))
            || abbreviations.contains(word.lowercased())
        return isAbbreviation ? nil : end
    }

    /// Short forms written with a full stop that never end a sentence, in the six languages: titles of a person and the abbreviations
    /// of "about", "compare", "including", "number". "etc." and "usw." often end one, and are on no list.
    private static let abbreviations: Set<String> = [
        "dr", "dra", "dott", "dssa", "prof", "ing", "avv", "sig", "sr", "sra", "srta", "mr", "mrs", "ms", "mme", "mlle", "st",
        "approx", "aprox", "ca", "vs", "cf", "cfr", "vgl", "bzw", "ggf", "inkl", "incl", "evtl", "sog", "nr", "bspw", "resp",
    ]
}
