import Foundation

/// One personal item of a grounded draft that the claim check judges (ADR 0028): a skill, a language, an interest, the headline
/// title or the place, by its value. Jobs, schools, dates and prose stay with the rules of ADR 0023.
public struct ClaimCandidate: Hashable, Sendable {
    public enum Kind: String, CaseIterable, Sendable {
        case skill, language, interest, title, place
    }

    public let kind: Kind
    public let value: String

    public init(kind: Kind, value: String) {
        self.kind = kind
        self.value = value
    }
}

/// How the description states a candidate, as the claim check reads it. Only `fact` keeps the item.
public enum ClaimStance: String, Sendable {
    case fact, wish, denied, otherPerson, notMentioned
}

/// What the claim check says of one candidate: its stance, and the words of the description it read it from.
public struct ClaimJudgement: Equatable, Sendable {
    public let stance: ClaimStance
    public let quote: String

    public init(stance: ClaimStance, quote: String) {
        self.stance = stance
        self.quote = quote
    }
}

/// A second, independent check of a grounded draft (ADR 0028): whether the person's description states each personal item as a
/// fact about the writer. It can only withdraw: an item stays when both the rules (ADR 0023) and this check keep it.
public protocol ClaimChecking: Sendable {
    /// What the check says of each candidate, in the order given. An answer that leaves a candidate out withdraws it.
    func judgements(of candidates: [ClaimCandidate], in description: String) async throws -> [ClaimJudgement]
}
