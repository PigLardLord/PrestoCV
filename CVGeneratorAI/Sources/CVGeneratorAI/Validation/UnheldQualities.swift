import Foundation

/// The qualities a summary names as the way the person works ("… with focus and precision") that are none of the draft's soft skills
/// (#359, N1). The soft-skill rules drop a second quality of one kind and a quality the person never said, and nothing compared the
/// summary with what was left: "focus", dropped from the skills, stayed in the summary. A quality the description states is the
/// person's own, whatever the skills hold.
///
/// Only a phrase that is a list of qualities is read: an introducer ("with"), then qualities that a conjunction or a comma joins, each
/// with its article, its intensifier ("great") and its detail ("attention to detail"), and then the end of the clause. Any other noun
/// after a quality ("with a precision scale", "with attention sensors") makes it no phrase. The words are closed lists per language,
/// like the vocabulary.
enum UnheldQualities {
    enum Outcome: Equatable {
        /// The sentence names no quality that the soft skills lack.
        case unchanged
        /// The sentence without the qualities the soft skills lack: the phrase goes when none of its qualities is held, else only the
        /// qualities that are not.
        case without(String)
        /// The sentence cannot be cut clean: the quality takes a complement, the list joins a word that is no quality, or fewer than
        /// four words are left. The qualities that the soft skills lack.
        case unheld([String])
    }

    /// The words of the soft skills and of the description, folded: a quality is held when one of them shares its beginning.
    static func heldWords(softSkills: [String], stated: Set<String>) -> Set<String> {
        stated.union(softSkills.flatMap { Word.words(in: $0).map(\.folded) })
    }

    /// `summary` with each sentence read by `check`: cut, or gone when it cannot be cut clean. The summary itself when `held` is nil.
    static func applied(to summary: String?, language: Vocabulary.Language?, held: Set<String>?) -> String? {
        guard let summary, let held else { return summary }

        var changed = false
        let sentences = SentenceSplitter.sentences(in: summary).compactMap { sentence -> String? in
            switch check(sentence, language: language, held: held) {
            case .unchanged: return sentence
            case .without(let cut):
                changed = true
                return cut
            case .unheld:
                changed = true
                return nil
            }
        }
        guard changed else { return summary }

        return sentences.isEmpty ? nil : sentences.joined(separator: " ")
    }

    static func check(_ sentence: String, language: Vocabulary.Language?, held: Set<String>) -> Outcome {
        guard let language, let lexicon = lexicons[language] else { return .unchanged }

        var current = sentence
        for round in 0..<3 {
            switch Reading(text: current, lexicon: lexicon, held: held).outcome {
            case .unchanged: return round == 0 ? .unchanged : .without(current)
            case .without(let cut): current = cut
            case .unheld(let names): return .unheld(names)
            }
        }
        return .without(current)
    }

    // MARK: - Reading a sentence

    private struct Reading {
        let characters: [Character]
        let words: [Word]
        let lexicon: Lexicon
        let held: Set<String>

        init(text: String, lexicon: Lexicon, held: Set<String>) {
            characters = Array(text)
            words = Word.words(in: text)
            self.lexicon = lexicon
            self.held = held
        }

        /// A quality of the phrase, with the words it stands on: the indices of its words in the sentence, and the qualities named.
        struct Item {
            let start: Int
            let end: Int
            let qualities: [String]
            /// Whether a preposition and something that is no quality follow it: "focus on safety".
            let hasAComplement: Bool
        }

        var outcome: Outcome {
            for introducer in words.indices.dropFirst() where lexicon.introducers.contains(words[introducer].folded) {
                guard let first = item(at: introducer + 1) else { continue }

                var items = [first]
                var linker: String?
                var next = first.end
                var cutsClean = true
                var isAPhrase = true
                while true {
                    if items[items.count - 1].hasAComplement {
                        cutsClean = false
                        break
                    }
                    if endsTheClause(at: next) {
                        // A comma may continue the list: "with patience, focus and care".
                        if next < words.count, words[next - 1].endsWithABreak, !words[next - 1].endsWithASemicolon,
                           let more = item(at: next) {
                            items.append(more)
                            next = more.end
                            continue
                        }
                        break
                    }
                    guard lexicon.linkers.contains(words[next].folded) else {
                        isAPhrase = false
                        break
                    }
                    linker = linker ?? words[next].accented
                    if let more = item(at: next + 1) {
                        items.append(more)
                        next = more.end
                        continue
                    }
                    // The conjunction joins something that is no quality: one or two words to the end of the clause cannot be cut
                    // out of the list; a longer rest is another clause of the sentence ("… with focus and manage the stock").
                    var rest = next + 1
                    while rest < words.count, !endsTheClause(at: rest) { rest += 1 }
                    cutsClean = !(1...2).contains(rest - (next + 1))
                    break
                }
                guard isAPhrase else { continue }

                let unheld = items.flatMap { $0.qualities }.filter { !isHeld($0) }
                guard !unheld.isEmpty else { continue }
                guard cutsClean, let cut = withoutTheUnheld(items, introducer: introducer, linker: linker) else { return .unheld(unheld) }

                return .without(cut)
            }
            return .unchanged
        }

        // MARK: Items

        private func item(at start: Int) -> Item? {
            var index = start
            while index < words.count, lexicon.articles.contains(words[index].folded) || lexicon.intensifiers.contains(words[index].folded) {
                index += 1
            }
            guard index < words.count, lexicon.qualities.contains(words[index].folded) else { return nil }

            var qualities = [words[index].folded]
            index += 1
            // "attenzione costante", "atención máxima": the adjective of the Romance languages follows the noun.
            while lexicon.adjectivesFollow, index < words.count, lexicon.intensifiers.contains(words[index].folded) { index += 1 }
            // "attention to detail", "atención al detalle".
            if index + 1 < words.count, !words[index - 1].endsWithABreak, lexicon.detailLinks.contains(words[index].folded) {
                var detail = index + 1
                if detail < words.count, lexicon.articles.contains(words[detail].folded) { detail += 1 }
                if detail < words.count, lexicon.details.contains(words[detail].folded) { index = detail + 1 }
            }
            // "enfoque en la claridad": a quality that follows the preposition is part of the item.
            var hasAComplement = false
            if index < words.count, !words[index - 1].endsWithABreak, lexicon.complements.contains(words[index].folded),
               !isGerund(at: index + 1) {
                var complement = index + 1
                while complement < words.count, lexicon.articles.contains(words[complement].folded) { complement += 1 }
                if complement < words.count, lexicon.qualities.contains(words[complement].folded) {
                    qualities.append(words[complement].folded)
                    index = complement + 1
                } else {
                    hasAComplement = true
                }
            }
            return Item(start: start, end: index, qualities: qualities, hasAComplement: hasAComplement)
        }

        /// Whether the clause ends before the word at `index`: the sentence ends, a comma or a semicolon stands between, or a
        /// subordinator or a gerund opens what follows ("…, supporting the count", "avec précision en utilisant …").
        private func endsTheClause(at index: Int) -> Bool {
            guard index < words.count else { return true }

            let word = words[index].folded
            return words[index - 1].endsWithABreak || lexicon.subordinators.contains(word) || isGerund(at: index)
                || (lexicon.gerundBridges.contains(word) && isGerund(at: index + 1))
        }

        private func isGerund(at index: Int) -> Bool {
            guard index < words.count else { return false }

            let word = words[index].folded
            return word.count >= 6 && lexicon.gerundEndings.contains(where: word.hasSuffix)
        }

        private func isHeld(_ quality: String) -> Bool {
            held.contains { UnheldQualities.shares($0, quality) }
        }

        // MARK: Cutting

        /// The sentence without the qualities that are not held, nil when fewer than four words are left.
        private func withoutTheUnheld(_ items: [Item], introducer: Int, linker: String?) -> String? {
            let kept = items.filter { $0.qualities.allSatisfy(isHeld) }
            let phraseEnd = words[items[items.count - 1].end - 1].range.upperBound
            let result: String
            if kept.isEmpty {
                var left = String(characters[..<words[introducer].range.lowerBound]).trimmingCharacters(in: .whitespaces)
                let right = String(characters[phraseEnd...]).trimmingCharacters(in: .whitespaces)
                let opensWithPunctuation = right.isEmpty || ",.;:!?".contains(right[right.startIndex])
                if opensWithPunctuation, left.hasSuffix(",") { left = String(left.dropLast()) }
                result = left + (opensWithPunctuation ? "" : " ") + right
            } else {
                let texts = kept.map { String(characters[words[$0.start].range.lowerBound..<words[$0.end - 1].range.upperBound]) }
                let list = texts.count == 1
                    ? texts[0]
                    : texts.dropLast().joined(separator: ", ") + " " + (linker ?? lexicon.defaultLinker) + " " + texts[texts.count - 1]
                result = String(characters[..<words[items[0].start].range.lowerBound]) + list + String(characters[phraseEnd...])
            }
            return Word.words(in: result).filter { !$0.isNumber }.count >= 4 ? result : nil
        }
    }

    /// Whether two folded words share a beginning: the same word, or four letters of a shorter one, or five of any ("reliable",
    /// "reliability"; "care", "careful").
    static func shares(_ first: String, _ second: String) -> Bool {
        let common = zip(first, second).prefix { $0 == $1 }.count
        return common >= 5 || (common >= 4 && common == min(first.count, second.count))
    }

    // MARK: - Lexicons

    /// The words of one language, folded (lower case, no accents).
    private struct Lexicon: Sendable {
        /// The prepositions that open a manner phrase.
        let introducers: Set<String>
        let articles: Set<String>
        let intensifiers: Set<String>
        /// The nouns of the person's qualities, as a manner.
        let qualities: Set<String>
        let linkers: Set<String>
        let defaultLinker: String
        /// "attention to detail": the words that link a quality to a detail, and the details.
        let detailLinks: Set<String>
        let details: Set<String>
        /// The prepositions after which a quality may follow another ("focus on clarity").
        let complements: Set<String>
        /// The words that open another clause after the phrase.
        let subordinators: Set<String>
        /// The prepositions that may precede a gerund ("en utilisant").
        let gerundBridges: Set<String>
        let gerundEndings: [String]
        /// Whether an adjective may follow the noun of a quality ("attenzione costante").
        let adjectivesFollow: Bool

        init(
            introducers: String, articles: String, intensifiers: String, qualities: String, linkers: String, details: String,
            detailLinks: String, complements: String, subordinators: String, gerundBridges: String = "", gerundEndings: [String] = [],
            adjectivesFollow: Bool = false
        ) {
            let set = { (words: String) in Set(words.split(separator: " ").map(String.init)) }
            self.introducers = set(introducers)
            self.articles = set(articles)
            self.intensifiers = set(intensifiers)
            self.qualities = set(qualities)
            self.linkers = set(linkers)
            self.defaultLinker = linkers.split(separator: " ").first.map(String.init) ?? ""
            self.details = set(details)
            self.detailLinks = set(detailLinks)
            self.complements = set(complements)
            self.subordinators = set(subordinators)
            self.gerundBridges = set(gerundBridges)
            self.gerundEndings = gerundEndings
            self.adjectivesFollow = adjectivesFollow
        }
    }

    private static let lexicons: [Vocabulary.Language: Lexicon] = [
        .english: Lexicon(
            introducers: "with through",
            articles: "a an the some",
            intensifiers: """
                great greatest utmost high highest full total extreme strong keen constant maximum particular special close careful \
                meticulous much good real genuine deep steady unwavering absolute
                """,
            qualities: """
                focus attention care precision accuracy rigor rigour patience dedication diligence passion enthusiasm commitment \
                creativity reliability empathy discipline professionalism determination flexibility curiosity concentration \
                thoroughness clarity calm energy initiative responsibility organization organisation teamwork autonomy honesty \
                motivation perseverance punctuality consistency
                """,
            linkers: "and", details: "detail details", detailLinks: "to for", complements: "on in about",
            subordinators: "while whilst to so when because which that as where", gerundBridges: "in by", gerundEndings: ["ing"]
        ),
        .italian: Lexicon(
            introducers: "con",
            articles: "la il lo le un una uno l",
            intensifiers: """
                massima massimo grande totale piena pieno costante particolare estrema estremo molta tanta alta elevata vera \
                assoluta scrupolosa
                """,
            qualities: """
                attenzione cura precisione rigore pazienza dedizione passione entusiasmo impegno creativita affidabilita empatia \
                disciplina professionalita determinazione flessibilita curiosita concentrazione chiarezza calma energia iniziativa \
                responsabilita organizzazione autonomia puntualita costanza diligenza serieta meticolosita accuratezza
                """,
            linkers: "e ed", details: "dettaglio dettagli", detailLinks: "ai al agli per", complements: "su in",
            subordinators: "per mentre quando che come affinche", gerundEndings: ["ando", "endo"], adjectivesFollow: true
        ),
        .spanish: Lexicon(
            introducers: "con",
            articles: "la el un una lo los las",
            intensifiers: """
                gran maxima maximo mucha mucho total mayor extrema extremo especial alta alto constante absoluta
                """,
            qualities: """
                atencion cuidado precision rigor paciencia dedicacion pasion entusiasmo compromiso creatividad fiabilidad empatia \
                disciplina profesionalidad profesionalismo determinacion flexibilidad curiosidad concentracion claridad calma energia \
                iniciativa responsabilidad organizacion autonomia puntualidad constancia diligencia enfoque esmero exactitud \
                meticulosidad equilibrio
                """,
            linkers: "y e", details: "detalle detalles", detailLinks: "al a de para", complements: "en sobre",
            subordinators: "para mientras cuando que como donde", gerundEndings: ["ando", "iendo", "yendo"], adjectivesFollow: true
        ),
        .french: Lexicon(
            introducers: "avec",
            articles: "la le l un une de d du des les",
            intensifiers: "grande grand beaucoup extreme haute totale toute constante particuliere",
            qualities: """
                attention soin precision rigueur patience devouement passion enthousiasme engagement creativite fiabilite empathie \
                discipline professionnalisme determination flexibilite curiosite concentration clarte calme energie initiative \
                responsabilite organisation autonomie ponctualite constance minutie exactitude serieux souci
                """,
            linkers: "et", details: "detail details", detailLinks: "aux au du des", complements: "sur",
            subordinators: "pour afin tout quand qui que lorsque alors comme", gerundBridges: "en", gerundEndings: ["ant"], adjectivesFollow: true
        ),
        .german: Lexicon(
            introducers: "mit",
            articles: "der die das dem den einer einem ein eine",
            intensifiers: """
                grosser grosse grossem grossen großer große großem großen hoher hohe hohem hochster hochstem grosster grosstem \
                großter großtem besonderer besonderem ausserster außerster viel voller maximaler stetiger standiger
                """,
            qualities: """
                sorgfalt genauigkeit prazision aufmerksamkeit geduld hingabe leidenschaft begeisterung engagement kreativitat \
                zuverlassigkeit empathie disziplin professionalitat entschlossenheit flexibilitat neugier konzentration klarheit \
                ruhe energie initiative verantwortung organisation selbststandigkeit punktlichkeit grundlichkeit fokus motivation \
                ausdauer gewissenhaftigkeit
                """,
            linkers: "und sowie", details: "detail details", detailLinks: "zum fur zu im", complements: "auf bei",
            subordinators: "um indem wahrend damit sodass wobei was"
        ),
        .portuguese: Lexicon(
            introducers: "com",
            articles: "a o as os uma um",
            intensifiers: "grande maxima maximo muita muito total extrema especial alta constante absoluta",
            qualities: """
                atencao cuidado precisao rigor paciencia dedicacao paixao entusiasmo compromisso criatividade confiabilidade \
                empatia disciplina profissionalismo determinacao flexibilidade curiosidade concentracao clareza calma energia \
                iniciativa responsabilidade organizacao autonomia pontualidade constancia diligencia foco esmero exatidao \
                meticulosidade equilibrio
                """,
            linkers: "e", details: "detalhe detalhes", detailLinks: "aos ao a para", complements: "em sobre",
            subordinators: "para enquanto quando que como onde", gerundEndings: ["ando", "endo", "indo"], adjectivesFollow: true
        ),
    ]
}
