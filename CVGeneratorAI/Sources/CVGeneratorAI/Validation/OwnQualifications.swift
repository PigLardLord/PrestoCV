import Foundation

/// The qualification words that a rich summary may name as the person's own (ADR 0031, #354): the words of the kept
/// degrees, and those of the description's sentences that speak of the person's studies ("I hold a diploma in logistics from Harlow
/// City College"). A qualification word anywhere else is not a claim about the person: "I calibrate certified weights at Chartered
/// Scales" gives no "certified" or "chartered".
enum OwnQualifications {
    /// The words of the kept degrees and schools of `education`, of four letters or more: those that tie a sentence to a study.
    static func studyWords(of education: [Education]) -> Set<String> {
        CVDataSanitizer.words(of: education.map(\.degree)).union(CVDataSanitizer.words(of: education.map(\.institution)))
            .filter { $0.count >= 4 }
    }

    /// The qualification words of the kept degrees of `education`, and of each sentence of `source` that holds a word of a kept degree
    /// or school (`studyWords`).
    static func words(of education: [Education], in source: DescriptionText) -> Set<String> {
        let studies = studyWords(of: education)
        let qualifications = WrittenTextWords.of(source.explainer.language).qualifications
        let ofStudies = source.sentences.flatMap { (sentence: DescriptionText.Sentence) -> [String] in
            let words = Word.words(in: sentence.raw).map(\.folded)
            return words.contains(where: studies.contains) ? words.filter(qualifications.contains) : []
        }
        return CVDataSanitizer.words(of: education.map(\.degree)).union(ofStudies)
    }
}
