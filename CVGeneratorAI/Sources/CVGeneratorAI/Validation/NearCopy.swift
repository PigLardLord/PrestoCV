import Foundation

// MARK: A summary sentence that says a duty again

extension CVDataSanitizer {
    /// Whether `sentence` says one of the `duties` again (#354): past the words of the job's `title`, it shares more
    /// content words with a single duty sentence than it adds, and adds fewer than two. Words compare by their first five letters,
    /// so "installiere" and "Installation" are one, and a content word has four letters or more and is no function word
    /// (`functionWords`). A sentence that joins two duties, or says one with how or what for, adds to it and stays: the summary is
    /// a draft, which the person edits (O1). "Ich installiere elektrische Anlagen in Neubauten" as an electrician, after "Ich
    /// installiere Anlagen in Neubauten", still goes. A sentence that names one of `skills`, the kept tools and qualities, that the
    /// duty does not name adds to it too: "Preparo i piatti principali … con la padella e il coltello".
    static func copiesADuty(_ sentence: String, duties: [String], title: String?, skills: [String]) -> Bool {
        let titled = contentStems(of: title ?? "")
        let own = contentStems(of: sentence).subtracting(titled)
        guard own.count >= 2 else { return false }
        let words = Word.words(in: sentence).map(\.folded)
        let named = skills.map { Word.words(in: $0).map(\.folded) }.filter { !$0.isEmpty && holds($0, in: words) }
        return duties.flatMap { SentenceSplitter.sentences(in: $0) }.contains { duty in
            let said = Word.words(in: duty).map(\.folded)
            let shared = own.intersection(contentStems(of: duty)).count
            let added = own.count - shared
            return named.allSatisfy { holds($0, in: said) } && added < 2 && shared > added
        }
    }

    private static func holds(_ run: [String], in words: [String]) -> Bool {
        words.indices.contains { words[$0...].prefix(run.count).elementsEqual(run) }
    }

    /// Whether `sentence` says one of the `earlier` sentences of its summary again (#354): it has 60% or more of the
    /// content words of one of two content words or more, as `copiesADuty` compares them, or four of them, and adds fewer than
    /// two to it past the words of the kept `qualities`. "Agisco come capoturno della manutenzione" after
    /// "Lavoro come capoturno della manutenzione" says the opening again; "Genero los informes mensuales y mantengo los registros
    /// de inventario con Balance y Cuentas." after a sentence on the inventory with the same tools adds four words and stays.
    static func repeats(_ sentence: String, earlier: [String], besides qualities: [String]) -> Bool {
        let own = contentStems(of: sentence)
        return earlier.contains { other in
            let said = contentStems(of: other)
            let shared = said.intersection(own).count
            let says = shared >= 4 || (said.count >= 2 && Double(shared) >= 0.6 * Double(said.count))
            return says && addedStems(sentence, to: other, besides: qualities) < 2
        }
    }

    /// How many content words `sentence` adds to `other`, as `copiesADuty` compares them, past the words of `besides` (#354):
    /// the kept qualities, which a sentence on work said before joins to it.
    static func addedStems(_ sentence: String, to other: String, besides: [String]) -> Int {
        let skipped = contentStems(of: besides.joined(separator: " "))
        return contentStems(of: sentence).subtracting(contentStems(of: other)).subtracting(skipped).count
    }

    static func contentStems(of text: String) -> Set<String> {
        Set(Word.words(in: text).map(\.folded).filter { $0.count >= 4 && !functionWords.contains($0) }.map { String($0.prefix(5)) })
    }

    /// The function words of four letters or more of the six languages, without accents.
    private static let functionWords: Set<String> = [
        "with", "from", "into", "that", "this", "these", "those", "their", "them", "they", "have", "been", "each", "every", "also",
        "dass", "dafur", "darauf", "damit", "eine", "einen", "einem", "einer", "eines", "mein", "meine", "meinen", "unsere", "habe",
        "haben", "wird", "werden", "sind", "auch", "oder", "sowie", "durch", "nach", "uber", "della", "delle", "dello", "degli",
        "nella", "nelle", "nello", "sono", "anche", "molto", "come", "dove", "questo", "questa", "pour", "avec", "dans", "sont",
        "mais", "plus", "tous", "toutes", "cette", "leurs", "comme", "para", "como", "este", "esta", "estos", "estas", "todos",
        "todas", "desde", "entre", "muito", "tambem", "pelo", "pela", "pelos", "pelas", "minha", "meus", "minhas", "sobre",
    ]
}
