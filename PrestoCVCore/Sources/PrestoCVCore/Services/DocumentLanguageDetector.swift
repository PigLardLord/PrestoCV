import Foundation

/// Tells what "Automatic" stands for with a CV: the language the CV is written in, read from its own words, and the
/// language of the app when the words do not tell it clearly.
///
/// It reads the summary, the titles and the descriptions, and none of the names: a company, a school or a city says
/// nothing about the language of the CV. It answers only for enough words that read clearly as one of the document
/// languages. A few job titles, which are often in English in a CV that is not, a mixed text, or a CV in another
/// language get the app's language instead.
public struct DocumentLanguageDetector: Sendable {

    /// What a language recognizer reads in a text
    public struct Reading: Equatable, Sendable {
        /// The language the text is most likely written in, among all the languages the recognizer knows, as a
        /// BCP 47 tag; nil when it cannot tell
        public let dominantLanguage: String?
        /// How likely each document language is, from 0 to 1, when the text is read as one of them
        public let likelihoods: [DocumentLanguage: Double]

        public init(dominantLanguage: String?, likelihoods: [DocumentLanguage: Double]) {
            self.dominantLanguage = dominantLanguage
            self.likelihoods = likelihoods
        }
    }

    /// Fewer words than this, and the language would be a guess
    public static let minimumWords = 15
    /// A document language less likely than this leaves the text unclear
    public static let minimumLikelihood = 0.8
    /// The recognizer reads this many characters at most: enough to tell the language, and quick enough to run on
    /// every change of the CV
    public static let maximumCharacters = 1_000

    private let preferredLanguages: [String]
    private let read: @Sendable (String) -> Reading

    /// - Parameters:
    ///   - preferredLanguages: The languages of the user, most wanted first, which the app follows.
    ///   - read: The recognizer.
    public init(preferredLanguages: [String], read: @escaping @Sendable (String) -> Reading) {
        self.preferredLanguages = preferredLanguages
        self.read = read
    }

    /// The language a CV that has no language of its own chosen is printed in
    public func automaticLanguage(for cv: CVModel) -> DocumentLanguage {
        language(of: cv) ?? DocumentLanguage.resolve(nil, preferredLanguages: preferredLanguages)
    }

    /// The document language the CV's own words are written in; nil when they do not tell it clearly
    func language(of cv: CVModel) -> DocumentLanguage? {
        let text = Self.words(of: cv)
        guard Self.wordCount(of: text) >= Self.minimumWords else { return nil }

        let reading = read(String(text.prefix(Self.maximumCharacters)))
        guard let (language, likelihood) = reading.likelihoods.max(by: { $0.value < $1.value }),
              likelihood >= Self.minimumLikelihood,
              reading.dominantLanguage.flatMap(DocumentLanguage.init(languageTag:)) == language else { return nil }
        return language
    }

    /// The summary, then the titles and the descriptions, one per line
    private static func words(of cv: CVModel) -> String {
        let info = cv.personalInfo
        let texts = [info.profile, info.title]
            + cv.relevant_experience.flatMap { [$0.title, $0.description] }
            + cv.education.flatMap { [$0.degree, $0.description] }
        return texts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    /// The words of a text: what is between spaces, with a letter in it
    private static func wordCount(of text: String) -> Int {
        text.split(whereSeparator: \.isWhitespace).filter { $0.contains(where: \.isLetter) }.count
    }
}
