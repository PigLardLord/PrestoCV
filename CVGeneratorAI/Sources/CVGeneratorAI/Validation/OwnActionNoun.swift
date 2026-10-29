import Foundation

/// A verb followed by the noun of its own action and that action's object ("Gestisco la gestione delle fatture", "I schedule the
/// scheduling of the shifts") says the work twice (#354, round 12). The noun, its article and the "of" go, and the object stays
/// with its own article: "Gestisco le fatture", "I schedule the shifts". Nothing else of the sentence changes.
enum OwnActionNoun {
    /// The words that may stand before the verb: the person.
    private static let persons: Set<String> = ["i", "je", "j", "ich", "io", "yo", "eu"]
    /// The definite articles of the noun.
    private static let articles: Set<String> = ["il", "lo", "la", "l", "i", "gli", "le", "el", "los", "las", "o", "a", "os", "as", "les", "the"]
    /// The articles of Portuguese, the only language whose "of" ("do", "da") is a word of another one ("da" is Italian "from").
    private static let portugueseArticles: Set<String> = ["o", "a", "os", "as"]
    /// The endings of a noun of an action, folded.
    private static let actionEndings = ["ione", "ion", "mento", "ment", "ung", "ao", "age", "ing"]
    /// Each "of" joined to an article, folded, and the article it leaves before the object; "del" is Italian's "il" or Spanish's "el".
    private static let joined: [String: String] = [
        "dello": "lo", "della": "la", "dell": "l'", "dei": "i", "degli": "gli", "delle": "le", "du": "le", "des": "les",
    ]
    private static let portugueseJoined: [String: String] = ["do": "o", "da": "a", "dos": "os", "das": "as"]

    /// `text` with each sentence's own action noun gone.
    static func dropped(in text: String) -> String {
        SentenceSplitter.sentences(in: text).reduce(text) { mended, sentence in
            let kept = droppedInSentence(sentence)
            return kept == sentence ? mended : mended.replacingOccurrences(of: sentence, with: kept)
        }
    }

    private static func droppedInSentence(_ sentence: String) -> String {
        let words = Word.words(in: sentence)
        let verb = words.first.map { persons.contains($0.folded) } == true ? 1 : 0
        guard words.count > verb + 4 else { return sentence }
        let (article, noun, of) = (words[verb + 1], words[verb + 2], words[verb + 3])
        guard words[verb].folded.count >= 5, articles.contains(article.folded), isOwnAction(noun.folded, of: words[verb].folded) else {
            return sentence
        }
        let characters = Array(sentence)
        let objectArticle: String
        let objectStart: Int
        if let mapped = joined[of.folded] {
            (objectArticle, objectStart) = (mapped, of.range.upperBound)
        } else if of.folded == "del" {
            (objectArticle, objectStart) = (noun.folded.hasSuffix("ione") || noun.folded.hasSuffix("mento") ? "il" : "el", of.range.upperBound)
        } else if portugueseArticles.contains(article.folded), let mapped = portugueseJoined[of.folded] {
            (objectArticle, objectStart) = (mapped, of.range.upperBound)
        } else if ["de", "of"].contains(of.folded) {
            (objectArticle, objectStart) = ("", words[verb + 4].range.lowerBound)
        } else {
            return sentence
        }
        var rest = String(characters[objectStart...])
        if objectArticle.hasSuffix("'") {
            rest = String(rest.drop { $0 == "'" || $0 == "’" })
        } else if !objectArticle.isEmpty {
            rest = String(rest.drop { $0 == " " })
            rest = objectArticle + " " + rest
        }
        return String(characters[..<article.range.lowerBound]) + (objectArticle.hasSuffix("'") ? objectArticle : "") + rest
    }

    /// Whether `noun` is the noun of the action `verb` names: the same word, or a noun of an action longer than six letters
    /// that opens with the verb's first five letters.
    private static func isOwnAction(_ noun: String, of verb: String) -> Bool {
        noun == verb || noun.count > 6 && noun.prefix(5) == verb.prefix(5) && actionEndings.contains(where: noun.hasSuffix)
    }
}
