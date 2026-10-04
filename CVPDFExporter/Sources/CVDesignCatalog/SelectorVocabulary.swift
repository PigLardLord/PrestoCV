/// The selectors a stylesheet may name, which is all the CSS policy needs to know about a structure (ADR 0011, ADR 0019).
/// A design's stylesheet is checked against the CV's, which are the markup contract's. The cover letter's built-in
/// stylesheet is checked against the letter structure's own. The property allow-list is the same for both.
public struct SelectorVocabulary: Sendable, Equatable {
    public let elements: Set<String>, classes: Set<String>
    /// The values of `[data-section=…]` and of `[data-rating=…]`. A vocabulary with none has no attribute selectors.
    public let sectionKinds: Set<String>, ratings: Set<String>
    public let pseudoClasses: Set<String>

    public init(elements: Set<String>, classes: Set<String>, sectionKinds: Set<String>, ratings: Set<String>, pseudoClasses: Set<String>) {
        self.elements = elements; self.classes = classes; self.sectionKinds = sectionKinds; self.ratings = ratings; self.pseudoClasses = pseudoClasses
    }

    /// What a design may select: the markup contract.
    public static let cv = SelectorVocabulary(elements: MarkupContract.elements, classes: MarkupContract.classes, sectionKinds: MarkupContract.sectionKinds,
                                              ratings: MarkupContract.ratings, pseudoClasses: MarkupContract.pseudoClasses)
}

extension ValidatedStylesheet {
    /// A stylesheet that is not a design's, such as the cover letter's built-in one (ADR 0019). It passes the same
    /// tokenizer and property allow-list as a design's, and its selectors are checked against `vocabulary`.
    /// A design package is never validated this way: `DesignPackageValidator` uses the CV's vocabulary.
    public static func validating(_ css: String, against vocabulary: SelectorVocabulary) throws(CSSRejection) -> ValidatedStylesheet {
        ValidatedStylesheet(css: try CSSPolicy.canonical(css, vocabulary: vocabulary))
    }
}
