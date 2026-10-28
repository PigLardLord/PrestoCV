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
        toefl ielts toeic celta delta tefl tesol tkt cambridge dele delf dalf testdaf telc goethe onset hsk jlpt cils plida
        sat gre gmat lsat mcat usmle nclex praxis gcse abitur baccalaureat maturita
        """
        let certifications = """
        pmp pmi cissp cisa cism ccna ccnp ccie comptia itil acca cfa cpa cma frm mcse mcsa mcsd ocp ceh oscp rhce rhcsa togaf cbap
        csm psm cspo ecdl icdl bls acls pals atls cpr
        """
        return Set([exams, certifications, examWordList].flatMap { $0.split(whereSeparator: \.isWhitespace).map(String.init) })
    }()
    private static let examWordList = """
        exam exams examination examinations esame esami examen examens exame exames pruefung prufung prufungen staatsexamen
        concorso concorsi concours oposicion oposiciones
        """

    /// Whole names, as `DescriptionText.normalized` writes them, of technologies that hold a word of the list: "Delta Lake",
    /// "SAT solving". Only the whole name is exempt: any other name with the word ("US CPA", "Digital SAT", "SAT exam") is a
    /// qualification, the safe way to fail. A technology joins by its whole name, with a test that the word alone is still one.
    private static let technologyNames: Set<String> = [
        "delta lake", "sat solving", "sat solver", "sat solvers", "gre tunnel", "gre tunneling", "gre tunnelling", "cpa tracking",
        "cpa optimization", "cpa optimisation",
    ]

    /// Names of more words, or with a mark, that no single word tells: as `DescriptionText.normalized` writes them.
    private static let phrases = ["six sigma", "green belt", "black belt", "a+", "network+", "security+", "server+", "linux+", "cloud+"]

    /// Whether `name` is the name of an exam or a certification.
    static func isOne(_ name: String) -> Bool {
        let normalized = DescriptionText.normalized(name)
        guard !technologyNames.contains(normalized) else { return false }
        if Word.words(in: name).contains(where: { words.contains($0.folded) }) { return true }
        return phrases.contains { normalized == $0 || normalized.hasPrefix($0 + " ") || normalized.hasSuffix(" " + $0) }
    }
}
