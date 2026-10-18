import Testing
import Foundation
@testable import CVGeneratorAI

/// The words a kept name of an entry does without (#202): a leading indefinite article.
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
}
