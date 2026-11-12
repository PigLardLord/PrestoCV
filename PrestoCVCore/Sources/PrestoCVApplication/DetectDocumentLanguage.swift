import Foundation
import PrestoCVDomain

/// The language a CV's own words are written in (#407): read at the first export of a CV that holds no language, so the
/// PDF's headings take it. Names tell no language (the person's, an employer's, a school's, a place's), so only the
/// words of the work are read: the summary, the professional title, each job's role and description, each study's
/// degree and description.
public struct DetectDocumentLanguage: Sendable {
    /// Fewer words than this tell no language, and the reader is not asked. A word holds a letter.
    public static let minimumWords = 15
    /// How sure the reader must be of the language.
    public static let minimumLikelihood = 0.8
    /// The reader reads only this many characters from the start: enough to tell the language.
    public static let maximumCharacters = 1_000

    let reader: any TextLanguageReading
    public init(reader: any TextLanguageReading) { self.reader = reader }

    /// The language of the CV's words, one of `languages`; nil when the words do not tell it: there are too few of
    /// them, or the reader is not sure enough, or the language it finds on its own is not the likeliest of `languages`.
    public func language(of cv: CV, among languages: [DocumentLanguage]) -> DocumentLanguage? {
        let text = Self.words(of: cv)
        guard Self.wordCount(of: text) >= Self.minimumWords else { return nil }
        let reading = reader.reading(of: String(text.prefix(Self.maximumCharacters)), among: languages)
        guard let found = reading.dominant, languages.contains(found),
              let likelihood = reading.likelihoods[found], likelihood >= Self.minimumLikelihood,
              !reading.likelihoods.contains(where: { $0.key != found && $0.value >= likelihood }) else { return nil }
        return found
    }

    /// The fields that hold words of the work, in order, each trimmed, the empty ones left out, one per line.
    static func words(of cv: CV) -> String {
        let fields = [cv.personal.summary, cv.personal.professionalTitle]
            + cv.sections.experiences.flatMap { [$0.role, $0.description] }
            + cv.sections.education.flatMap { [$0.degree, $0.description] }
        return fields.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    static func wordCount(of text: String) -> Int {
        text.split(whereSeparator: \.isWhitespace).filter { $0.contains(where: \.isLetter) }.count
    }
}
