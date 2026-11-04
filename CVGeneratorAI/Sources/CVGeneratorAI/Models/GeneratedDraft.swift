import Foundation

/// What a generation gives: the grounded draft, and whether its personal items were withdrawn because the claim check gave no
/// answer (ADR 0028). The flag is about how the draft was made, so it stays out of `CVData`, which is the document.
public struct GeneratedDraft: Equatable, Sendable {
    /// The draft, limited to what the description supports and the claim check kept.
    public let cvData: CVData
    /// True when the claim check failed or refused, so the skills, languages, interests, headline title and place were all
    /// withdrawn for the person to add by hand.
    public let personalItemsUnchecked: Bool

    public init(cvData: CVData, personalItemsUnchecked: Bool) {
        self.cvData = cvData
        self.personalItemsUnchecked = personalItemsUnchecked
    }
}
