import Testing
import Foundation
@testable import CVGeneratorAI

/// The words a kept name of an entry does without (#202): a leading indefinite article, and a degree that only says graduating.
@Suite("EntryWording: the words a kept name does without")
struct EntryWordingTests {
    @Test("A leading indefinite article goes, in the description's language, or in any of the six when it is not known", arguments: [
        ("a nursery", Vocabulary.Language?.some(.english), "nursery"), ("an orphanage", .english, "orphanage"),
        ("un'azienda agricola", .italian, "azienda agricola"), ("un\u{2019}azienda", .italian, "azienda"), ("uno studio", .italian, "studio"),
        ("einer Kinderkrippe", .german, "Kinderkrippe"), ("una guardería", .spanish, "guardería"), ("une crèche", .french, "crèche"),
        ("uma creche", .portuguese, "creche"), ("a nursery", nil, "nursery"), ("una guardería", nil, "guardería"),
    ])
    func leadingArticleGoes(name: String, language: Vocabulary.Language?, kept: String) {
        #expect(EntryWording.withoutLeadingArticle(name, in: language) == kept)
    }

    @Test("A name keeps an article with a capital, an article of another language, and an article that is all it is", arguments: [
        ("UNA Hotels", Vocabulary.Language?.some(.italian)), ("A Plus Consulting", .english), ("Una guardería", .spanish),
        ("an der Schule", .german), ("um hospital", .spanish), ("a", .english), ("Acme", .english), ("una", nil),
    ])
    func nameStays(name: String, language: Vocabulary.Language?) {
        #expect(EntryWording.withoutLeadingArticle(name, in: language) == name)
    }

    @Test("A degree that only says graduating names no degree", arguments: [
        ("diplôme", Vocabulary.Language?.some(.french)), ("mon diplôme", .french), ("my degree", .english), ("graduated", .english),
        ("Abschluss", .german), ("Studium abgeschlossen", .german), ("la laurea", .italian), ("título", .spanish), ("diploma", .portuguese),
        ("degree", nil),
    ])
    func wordForGraduating(degree: String, language: Vocabulary.Language?) {
        #expect(!EntryWording.namesADegree(degree, in: language))
    }

    @Test("A degree with a field of study, or of a kind, names a degree", arguments: [
        ("Laurea in Scienze della Formazione", Vocabulary.Language?.some(.italian)), ("Bachelor", .english), ("Master in Nursing", .english),
        ("Diplôme d'État", .french), ("Erziehungswissenschaften", .german), ("Ciencias de la Educación", .spanish), ("Nursing", nil),
    ])
    func degreeWithAField(degree: String, language: Vocabulary.Language?) {
        #expect(EntryWording.namesADegree(degree, in: language))
    }
}
