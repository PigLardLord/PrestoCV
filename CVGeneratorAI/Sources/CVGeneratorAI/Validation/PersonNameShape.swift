import Foundation

/// Whether what the draft gives as the person's name has the shape of a name (#359). The quote check cannot tell: a pronoun ("Ich",
/// "Io") or a clause of the description ("Trabajo desde hace nueve años en la reparación de bicicletas") is in the description, word
/// for word, so it passes as a name. By rules, with no word list of names:
///
/// - A first-person pronoun of the description's language is no name, alone or as one of its words ("Ich", "I'm Tom Hartley",
///   "Je m'appelle Claire Moreau"). A pronoun of one letter ("I", "J'") is one when it is the whole name or an apostrophe follows it:
///   the initials of "J. Smith" are not.
/// - In the languages that drop the pronoun (Italian, Spanish, Portuguese) a clause starts with its verb ("Lavoro come cuoco", "Soy
///   Pedro Gil"): a name that starts with a verb, or holds a verb in lower case, is none. A capital verb form further in ("Giulia
///   Vivo") is a surname.
/// - A name has no sentence punctuation and no more words than a name has.
///
/// Such a name is left empty: the first words of a clause are no name either.
enum PersonNameShape {
    /// The most words a name has, particles included ("Maria Fernanda de la Cruz y Gómez").
    private static let mostWords = 7

    private static let sentenceMarks: Set<Character> = [";", ":", "!", "?", "…"]
    private static let apostrophes: Set<Character> = ["'", "\u{2019}", "\u{02BC}"]

    /// - Parameters:
    ///   - name: The name the draft gives.
    ///   - language: The language of the description, when it is known: every language's pronouns count otherwise.
    static func isName(_ name: String, in language: Vocabulary.Language?) -> Bool {
        let tokens = name.split(whereSeparator: \.isWhitespace)
        guard !tokens.isEmpty, tokens.count <= mostWords, !holdsSentencePunctuation(name) else { return false }
        let characters = Array(Digits.ascii(name))
        let words = Word.words(in: name)
        return !holdsAPronoun(words, characters, in: language) && !startsAsAClause(words, characters, in: language)
    }

    /// A mark of a sentence, or a comma that goes on in lower case ("serralharia, em obras"): "Rossi, Giulia" is a name.
    private static func holdsSentencePunctuation(_ name: String) -> Bool {
        let characters = Array(name)
        return characters.indices.contains { index in
            if sentenceMarks.contains(characters[index]) { return true }
            guard characters[index] == "," else { return false }
            return characters[(index + 1)...].first { !$0.isWhitespace }?.isLowercase == true
        }
    }

    private static func holdsAPronoun(_ words: [Word], _ characters: [Character], in language: Vocabulary.Language?) -> Bool {
        let pronouns = (language.flatMap { Voice.words[$0] } ?? Voice.everyWord).firstPerson
        return words.contains { word in
            guard pronouns.contains(word.accented) else { return false }
            guard word.accented.count == 1 else { return true }
            return words.count == 1 || word.range.upperBound < characters.count && apostrophes.contains(characters[word.range.upperBound])
        }
    }

    private static func startsAsAClause(_ words: [Word], _ characters: [Character], in language: Vocabulary.Language?) -> Bool {
        guard let language, !language.words.thirdPersons.isEmpty else { return false }
        let beForms = StatedTitle.forms(StatedTitle.presentFirstPersonBe, in: language)
        return words.enumerated().contains { index, word in
            guard index == 0 || characters[word.range.lowerBound].isLowercase else { return false }
            return beForms.contains(word.accented) || Vocabulary.isVerb(word.folded, in: language)
        }
    }
}
