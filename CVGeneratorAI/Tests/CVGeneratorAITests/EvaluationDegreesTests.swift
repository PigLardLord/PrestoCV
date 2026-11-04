import Testing
import Foundation
@testable import CVGeneratorAI

/// ADR 0023: a degree must name a qualification, and the degrees that the drafting evaluation accepted stay. Each case is the
/// degree the model wrote for a written input of the evaluation, with the school it wrote beside it. The evaluation adjudicated
/// them as harmless (a subject, a training, a profession noun, a letter code), and the rule that drops a verb must not take one
/// of them: "nurse" is a verb in English as well, "curso" is listed as a verb form in Portuguese.
@Suite("Evaluation degrees: the degrees the evaluation accepted stay after the grounding")
struct EvaluationDegreesTests {
    private static let accepted: [(input: String, degree: String, school: String)] = [
        ("en-plain", "logistics", "Leeds City College"),
        ("en-traps", "nurse", "University of the West Country"),
        ("de-plain", "Ausbildung", "Berufsschule Lechfeld"),
        ("de-traps", "Ausbildung", "Fachschule für Physiotherapie Kassel"),
        ("fr-plain", "CAP", "lycée professionnel Les Mauves"),
        ("pt-plain", "curso", "Escola Superior de Saúde do Mondego"),
    ]

    @Test("The degree of the written input stays, with its school", arguments: accepted)
    func degreeStays(input: String, degree: String, school: String) throws {
        let written = try #require(DraftingInputs.written.first { $0.id == input })
        let draft = CVData(education: [Education(degree: degree, institution: school)])

        let result = try CVDataSanitizer().sanitize(draft, against: written.description)

        #expect(result.education.first?.degree == degree,
                "\(input): \"\(degree)\" is a qualification of the description and stays, got \(String(describing: result.education.first?.degree))")
        #expect(result.education.first?.institution == school, "\(input): the school stays")
    }

    @Test("The degree the evaluation rejected goes: terminé is a verb, and the school stays")
    func verbGoes() throws {
        let input = try #require(DraftingInputs.written.first { $0.id == "es-plain" })
        let draft = CVData(education: [Education(degree: "terminé", institution: "Escuela de Arte Turia")])

        let result = try CVDataSanitizer().sanitize(draft, against: input.description)

        #expect(result.education.first?.degree == nil, "terminé is the verb of the sentence, not a degree")
        #expect(result.education.first?.institution == "Escuela de Arte Turia", "the school is stated and stays")
    }
}
