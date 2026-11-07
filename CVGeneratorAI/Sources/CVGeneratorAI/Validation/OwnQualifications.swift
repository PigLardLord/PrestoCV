import Foundation

/// The qualification words that a rich summary may name as the person's own (ADR 0031, #354, probe round 21): the words of the kept
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

    /// Whether `sentence` says a school or a course taught the person's languages (#359, P3): it holds a word of a kept degree or school
    /// and a word of a kept language, and it is not the person's own words. The model joined "I studied at the school" and "I speak
    /// French and English" into "I studied the CAP at the school in French and English". A word of the studies that is a language's
    /// name ("English literature") or a word of the person's work (`apart`: the titles and the employers) is none of the studies.
    static func tiesAStudyToALanguage(
        _ sentence: String, education: [Education], languages: [Language], apart: Set<String>, source: DescriptionText
    ) -> Bool {
        let languageWords = CVDataSanitizer.words(of: languages.map(\.name))
        let studyWords = studyWords(of: education).subtracting(languageWords).subtracting(apart)
        guard !languageWords.isEmpty, !studyWords.isEmpty else { return false }
        let said = Word.words(in: sentence).map(\.folded)
        let words = Set(said)
        let study = studyWords.intersection(words)
        let spoken = languageWords.intersection(words)
        guard !study.isEmpty, !spoken.isEmpty else { return false }
        // Only the person's own words back it, in their order: a run of one sentence of the description. Sharing its words is not
        // enough, since "I studied nursing at Harlow City College and I speak German" holds every word of "I studied nursing in
        // German at Harlow City College" (review round 1, final gate). A true sentence said otherwise goes: losing it is safe.
        return !source.sentences.contains { sourceSentence in
            holdsRun(said, in: Word.words(in: sourceSentence.raw).map(\.folded))
        }
    }

    /// Whether `words` follow one another, in this order, somewhere in `text`.
    private static func holdsRun(_ words: [String], in text: [String]) -> Bool {
        guard !words.isEmpty, words.count <= text.count else { return false }
        return (0...(text.count - words.count)).contains { start in text[start..<(start + words.count)].elementsEqual(words) }
    }
}
