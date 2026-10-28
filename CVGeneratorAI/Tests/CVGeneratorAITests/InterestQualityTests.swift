import Testing
@testable import CVGeneratorAI

/// An interest is a pastime (#354): a clause in which the person tells a quality at work ("I keep calm with the guests", "mi piace
/// lavorare in gruppo") is no interest, and goes; a hobby stays, with the person's own things in it ("walks with my dog"). Every
/// name and sentence is invented.
@Suite("An interest is a pastime, never a quality at work (#354)")
struct InterestQualityTests {
    private let sanitizer = CVDataSanitizer(lexicalClasses: ForcedLexicalTagger([:]), wordList: TableWordList())

    static let english = """
        I have been a waiter at the Lantern Bistro in Exeter since 2019. I keep calm with the guests and I like working \
        side by side with the chefs. In my free time I like chess, long walks with my dog and hiking in the Alps.
        """

    static let italian = """
        Dal 2018 faccio il magazziniere alla Logistica Varesi di Pavia. Sono paziente e mi piace lavorare in gruppo. \
        Nel tempo libero mi piace la fotografia.
        """

    @Test("A quality at work written as an interest goes, in English")
    func englishQualitiesGo() throws {
        let draft = CVData(interests: ["keep calm with the guests", "like working side by side with the chefs", "chess"])

        let result = try sanitizer.sanitize(draft, against: Self.english)

        #expect(result.interests == ["chess"])
    }

    @Test("A clause in which the person tells a quality goes, in Italian, and the hobby stays")
    func italianClauseGoes() throws {
        let draft = CVData(interests: ["sono paziente e mi piace lavorare in gruppo", "fotografia"])

        let result = try sanitizer.sanitize(draft, against: Self.italian)

        #expect(result.interests == ["fotografia"])
    }

    @Test("A hobby with the person's own things in it stays")
    func hobbiesStay() throws {
        let draft = CVData(interests: ["chess", "long walks with my dog", "hiking in the Alps"])

        let result = try sanitizer.sanitize(draft, against: Self.english)

        #expect(result.interests == ["chess", "long walks with my dog", "hiking in the Alps"])
    }
}
