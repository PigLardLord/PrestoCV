import Foundation

/// The names of exams and certifications, which are no skill: "TOEFL", "Cambridge CELTA", "Green Belt". Such a name has no digit,
/// no word of a qualification and no language, so only a list tells it from a technology. The list is not complete, and cannot be:
/// a skill the person never named is a plain name of a technology or a soft skill, and a qualification that is not on the list
/// reaches the draft as a skill, where the person's review can remove it (ADR 0031, Consequences).
enum QualificationNames {
    /// Words of one name, as `Word.folded` writes them: the exams of languages, school and university, and the certifications of the
    /// trades a CV names most.
    private static let words: Set<String> = {
        let exams = """
        toefl ielts toeic celta tefl tesol tkt cambridge dele delf dalf testdaf telc goethe hsk jlpt cils plida
        gmat lsat mcat usmle nclex gcse abitur baccalaureat maturita
        """
        let certifications = """
        pmp pmi cissp cisa cism ccna ccnp ccie comptia itil acca cfa cma frm mcse mcsa mcsd ceh oscp rhce rhcsa togaf cbap
        csm psm cspo ecdl icdl bls acls pals atls cpr
        """
        return Set([exams, certifications, examWordList].flatMap { $0.split(whereSeparator: \.isWhitespace).map(String.init) })
    }()
    private static let examWordList = """
        exam exams examination examinations esame esami examen examens exame exames pruefung prufung prufungen staatsexamen
        concorso concorsi concours oposicion oposiciones
        """
    private static let examWords = Set(examWordList.split(whereSeparator: \.isWhitespace).map(String.init))

    /// Names of an exam or a certification that are also words or technologies: "Delta Lake", "SAT solving", "Praxis", "GRE tunnel",
    /// "CPA" (cost per acquisition), "OCP" (OpenShift). A word certifications are written with ("PSM I", "PMI-ACP", "CSM")
    /// stays in the word list. Such a word is a qualification only as the whole name or with a word of
    /// `qualifiers`, wherever it stands ("SAT exam", "GRE General Test"), never with another word alone ("SAT solving").
    private static let ambiguousWords: Set<String> = [
        "delta", "sat", "gre", "praxis", "onset", "cpa", "ocp",
    ]
    /// The words that make an ambiguous word the name of an exam or a certification.
    private static let qualifiers: Set<String> = {
        let others = "test tests certification certifications certificate certificates certified diploma level prep preparation"
        return Set(others.split(separator: " ").map(String.init)).union(examWords)
    }()

    /// Names of more words, or with a mark, that no single word tells: as `DescriptionText.normalized` writes them.
    private static let phrases = ["six sigma", "green belt", "black belt", "a+", "network+", "security+", "server+", "linux+", "cloud+"]

    /// Whether `name` is the name of an exam or a certification.
    static func isOne(_ name: String) -> Bool {
        let folded = Word.words(in: name).map(\.folded)
        if folded.contains(where: { words.contains($0) }) { return true }
        if folded.contains(where: { ambiguousWords.contains($0) }),
           folded.allSatisfy({ ambiguousWords.contains($0) }) || folded.contains(where: { qualifiers.contains($0) }) {
            return true
        }
        let normalized = DescriptionText.normalized(name)
        return phrases.contains { normalized == $0 || normalized.hasPrefix($0 + " ") || normalized.hasSuffix(" " + $0) }
    }
}
