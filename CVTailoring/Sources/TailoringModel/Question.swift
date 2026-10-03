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

    /// A term or a request must say something, and is bounded (R8).
    public init(kind: QuestionKind, scope: QuestionScope) throws(TailoringModelError) {
        switch kind {
        case .unevidencedTerm(let term): try Bounds.requiredText(term, .term)
        case .modelRequest(let request): try Bounds.requiredText(request, .request)
        case .letterField: break
        }
        self.kind = kind
        self.scope = scope
    }
}
