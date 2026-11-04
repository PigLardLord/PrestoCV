import Testing
@testable import CVGeneratorAI

/// The qualification words a rich summary may name as the person's own: those of the kept degrees, and those of the sentences that
/// speak of the person's studies (ADR 0031). All names are invented.
@Suite("The qualifications a summary may name as its own")
struct OwnQualificationsTests {
    private static let education = [Education(degree: "master in logistics", institution: "Harlow City College")]

    private static let description = """
        I calibrate certified weights at Chartered Scales in Leeds. I hold a diploma in logistics from Harlow City College. \
        One day I would like to get a licence.
        """

    private func source(_ text: String) -> DescriptionText {
        DescriptionText(text, languageOfText: { _ in "en" })
    }

    @Test("The words of the kept degrees and of the sentences that hold a word of a degree or a school are the person's own")
    func ownWords() {
        let words = OwnQualifications.words(of: Self.education, in: source(Self.description))

        #expect(words.contains("master"), "\(words)")
        #expect(words.contains("diploma"), "\(words)")
    }

    @Test(
        "A qualification word of a sentence with no word of a degree or a school is not the person's own: an object, an employer, a wish",
        arguments: ["certified", "chartered", "licence"]
    )
    func foreignWords(word: String) {
        let words = OwnQualifications.words(of: Self.education, in: source(Self.description))

        #expect(!words.contains(word), "\(words)")
    }

    @Test("A school or a degree anchors a sentence by a word of four letters or more")
    func studyWords() {
        let words = OwnQualifications.studyWords(of: Self.education)

        #expect(words == ["master", "logistics", "harlow", "city", "college"], "\(words)")
    }

    @Test("A person with no studies has no qualification of their own beyond the degrees")
    func noStudies() {
        let words = OwnQualifications.words(of: [], in: source(Self.description))

        #expect(words.isEmpty, "\(words)")
    }
}
