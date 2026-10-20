import Foundation

/// The words that a kept name of an entry does without (#202). Each rule only takes words out of a quote, so what is left is a
/// quote too, and none changes what the description backs.
enum EntryWording {
    /// The indefinite articles of each language, as `DescriptionText.normalized` writes them.
    private static let articlesByLanguage: [Vocabulary.Language: Set<String>] = [
        .english: ["a", "an"],
        .italian: ["un", "una", "uno"],
        .german: ["ein", "eine", "einer", "einem", "einen", "eines"],
        .spanish: ["un", "una"],
        .french: ["un", "une"],
        .portuguese: ["um", "uma"],
    ]

    private static let everyArticle: Set<String> = articlesByLanguage.values.reduce(into: []) { $0.formUnion($1) }

    /// The indefinite articles that a language elides before a vowel, with their apostrophe: Italian "un'azienda".
    private static let elidedArticlesByLanguage: [Vocabulary.Language: [String]] = [.italian: ["un'", "un\u{2019}"]]

    private static let everyElidedArticle: [String] = elidedArticlesByLanguage.values.flatMap { $0 }

    /// The words that only name a qualification, with no field of study: "degree", "laurea", "Abschluss", "diplôme".
    private static let degreeWordsByLanguage: [Vocabulary.Language: Set<String>] = [
        .english: ["degree", "degrees", "diploma", "diplomas", "graduation"],
        .italian: ["laurea", "lauree", "diploma", "diplomi"],
        .german: ["abschluss", "abschluesse", "abschlusse", "diplom"],
        .spanish: ["titulo", "titulos", "diploma", "diplomas", "graduacion"],
        .french: ["diplome", "diplomes"],
        .portuguese: ["diploma", "diplomas", "graduacao", "formatura"],
    ]

    private static let everyDegreeWord: Set<String> = degreeWordsByLanguage.values.reduce(into: []) { $0.formUnion($1) }

    /// Whether `word` (as `DescriptionText.normalized` writes it) is an indefinite article, in the language of the description, or
    /// in any of the six when it is not known.
    static func isIndefiniteArticle(_ word: String, in language: Vocabulary.Language?) -> Bool {
        (language.map { articlesByLanguage[$0] ?? [] } ?? everyArticle).contains(word)
    }

    /// The name of an employer or a school without its leading indefinite article ("a nursery", "una guardería", "un'azienda", "einer
    /// Kinderkrippe"), in the language of the description, or in any of the six when it is not known: a CV names the place. An article
    /// written with a capital stays, as part of a name ("UNA Hotels", "A Plus Consulting"), and so does a name that is nothing else.
    static func withoutLeadingArticle(_ name: String, in language: Vocabulary.Language?) -> String {
        let articles = language.map { articlesByLanguage[$0] ?? [] } ?? everyArticle
        let elided = language.map { elidedArticlesByLanguage[$0] ?? [] } ?? everyElidedArticle
        if let rest = name.droppingPrefix(elided), rest.first?.isLetter == true {
            return rest
        }
        guard let space = name.firstIndex(where: \.isWhitespace), articles.contains(String(name[..<space])) else { return name }
        return String(name[space...]).trimmedNonEmpty ?? name
    }

    /// Whether a degree names more than graduating: "diplôme", "Abschluss", "laurea" or "my degree" alone say that the person
    /// graduated, not in what, while "Laurea in Scienze della Formazione" and "Bachelor" name a degree. A word for a degree, a word of
    /// graduating, and the function words and pronouns that go with them ("mon", "il", "meinen") name none.
    static func namesADegree(_ degree: String, in language: Vocabulary.Language?) -> Bool {
        let degreeWords = language.map { degreeWordsByLanguage[$0] ?? [] } ?? everyDegreeWord
        let words = EntryEvidence.foldedWords(of: degree)
        let saysGraduating: (String) -> Bool = { degreeWords.contains($0) || Vocabulary.isGraduating($0, in: language) }

        return !words.contains(where: saysGraduating) || !words.allSatisfy { word in
            saysGraduating(word) || Vocabulary.isGraduationFrame(word, in: language) || Vocabulary.isNeutral(word, in: language)
        }
    }
}

private extension String {
    /// The text after the first of `prefixes` it starts with, in the same case; nil when it starts with none.
    func droppingPrefix(_ prefixes: [String]) -> String? {
        prefixes.lazy.compactMap { prefix in self.hasPrefix(prefix) ? String(self.dropFirst(prefix.count)) : nil }.first
    }
}
