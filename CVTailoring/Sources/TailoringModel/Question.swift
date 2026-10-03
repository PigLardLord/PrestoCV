/// A letter field only the user can fill: what the CV does not say, so a letter never invents it.
public enum LetterField: CaseIterable, Hashable, Sendable {
    case salaryExpectation, startDate
}

/// What a question asks.
public enum QuestionKind: Hashable, Sendable {
    /// The advert asks for a term the source CV does not evidence.
    case unevidencedTerm(String)
    /// A letter field the user has not given.
    case letterField(LetterField)
    /// Something the model needs from the user to go on.
    case modelRequest(String)
}

/// The part of the CV or the letter a question is about.
public enum QuestionScope: Hashable, Sendable {
    case experience(ExperienceRef)
    case skills
    case summary
    case letter(LetterField)
}

/// What the user would need to answer, and where the answer would go (ADR 0013). Whatever the advert asks for that the
/// CV does not evidence becomes a question, never a line of the CV. Answers are not part of this model.
public struct Question: Hashable, Sendable {
    public let kind: QuestionKind
    public let scope: QuestionScope

    /// A term or a request must say something, and is bounded (R8). A question about a letter field has the `.letter`
    /// scope of that same field, and no other question has a `.letter` scope; otherwise `mismatchedScope`.
    public init(kind: QuestionKind, scope: QuestionScope) throws(TailoringModelError) {
        switch (kind, scope) {
        case (.letterField(let field), .letter(let scoped)):
            guard field == scoped else { throw .mismatchedScope }
        case (.letterField, _), (_, .letter):
            throw .mismatchedScope
        case (.unevidencedTerm(let term), _):
            try Bounds.requiredText(term, .term)
        case (.modelRequest(let request), _):
            try Bounds.requiredText(request, .request)
        }
        self.kind = kind
        self.scope = scope
    }
}
