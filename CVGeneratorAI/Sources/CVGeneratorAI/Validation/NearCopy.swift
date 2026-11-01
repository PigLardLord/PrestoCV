import Foundation

// MARK: A summary sentence that says a duty again

extension CVDataSanitizer {
    /// Whether `sentence` says one of the `duties` again in other words (#354, round 15): 60% or more of the content words of a
    /// duty of two content words or more are in it, past the words of the job's `title`. Words compare by their first five letters,
    /// so "installiere" and "Installation" are one, and a content word has four letters or more and is no function word
    /// (`functionWords`). The summary check drops a duty copied word for word; "Ich installiere elektrische Anlagen in Neubauten"
    /// after "Ich installiere Anlagen in Neubauten" is no copy to it, and said the job's work twice.
    static func nearlyCopies(_ sentence: String, duties: [String], title: String?) -> Bool {
        let titled = contentStems(of: title ?? "")
        let own = contentStems(of: sentence).subtracting(titled)
        return duties.flatMap { SentenceSplitter.sentences(in: $0) }.contains { duty in
            let said = contentStems(of: duty).subtracting(titled)
            return said.count >= 2 && Double(said.intersection(own).count) >= 0.6 * Double(said.count)
        }
    }

    /// Whether `sentence` says mostly one of the `duties` again (#354, probe round 4): 75% or more of its own content words, past
    /// the words of the job's `title`, are of a single duty sentence, as `nearlyCopies` compares them. A sentence that joins two
    /// duties, or says one with what it is for, stays: the summary's slots are the topics of the duties, and a sentence on two of
    /// them read as a copy of each (`nearlyCopies`). "Ich installiere elektrische Anlagen in Neubauten" after "Ich installiere
    /// Anlagen in Neubauten" still goes.
    static func mostlyCopies(_ sentence: String, duties: [String], title: String?) -> Bool {
        let titled = contentStems(of: title ?? "")
        let own = contentStems(of: sentence).subtracting(titled)
        guard own.count >= 2 else { return false }
        return duties.flatMap { SentenceSplitter.sentences(in: $0) }.contains { duty in
            Double(contentStems(of: duty).intersection(own).count) >= 0.75 * Double(own.count)
        }
    }

    /// Whether `sentence` says one of the `earlier` sentences of its summary again (#354, round 17): it has 60% or more of the
    /// content words of one of two content words or more, as `nearlyCopies` compares them, or four of them. "Agisco come
    /// capoturno della manutenzione" after "Lavoro come capoturno della manutenzione" says the opening again.
    static func repeats(_ sentence: String, earlier: [String]) -> Bool {
        let own = contentStems(of: sentence)
        return earlier.contains { other in
            let said = contentStems(of: other)
            let shared = said.intersection(own).count
            return shared >= 4 || (said.count >= 2 && Double(shared) >= 0.6 * Double(said.count))
        }
    }

    private static func contentStems(of text: String) -> Set<String> {
        Set(Word.words(in: text).map(\.folded).filter { $0.count >= 4 && !functionWords.contains($0) }.map { String($0.prefix(5)) })
    }

    /// The function words of four letters or more of the six languages, without accents.
    private static let functionWords: Set<String> = [
        "with", "from", "into", "that", "this", "these", "those", "their", "them", "they", "have", "been", "each", "every", "also",
        "dass", "dafur", "darauf", "damit", "eine", "einen", "einem", "einer", "eines", "mein", "meine", "meinen", "unsere", "habe",
        "haben", "wird", "werden", "sind", "auch", "oder", "sowie", "durch", "nach", "uber", "della", "delle", "dello", "degli",
        "nella", "nelle", "nello", "sono", "anche", "molto", "come", "dove", "questo", "questa", "pour", "avec", "dans", "sont",
        "mais", "plus", "tous", "toutes", "cette", "leurs", "para", "como", "este", "esta", "estos", "estas", "todos", "todas",
        "desde", "entre", "muito", "tambem", "pelo", "pela", "pelos", "pelas", "minha", "meus", "minhas", "sobre",
    ]
}
