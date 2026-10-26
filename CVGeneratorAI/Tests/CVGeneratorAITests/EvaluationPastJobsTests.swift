import Testing
import Foundation
@testable import CVGeneratorAI

/// ADR 0023: the profession the headline gives is what the person is now, so it is not the title of a job that has ended, and
/// the title that the description states for a job stays. Each case is the draft of a written input of the drafting
/// evaluation: the headline, the job that goes on and the job that ended, with the titles the model wrote on them.
@Suite("Evaluation past jobs: the headline title goes from a job that has ended and stays on the job that goes on")
struct EvaluationPastJobsTests {
    struct Case: Sendable, CustomTestStringConvertible {
        let input: String
        let name: String
        let location: String?
        let headline: String
        let currentTitle: String
        let currentCompany: String
        let pastTitle: String
        let pastCompany: String

        var testDescription: String { input }

        var draft: CVData {
            CVData(
                personalInfo: PersonalInfo(name: name, location: location, title: headline),
                experience: [
                    Experience(title: currentTitle, company: currentCompany, current: true),
                    Experience(title: pastTitle, company: pastCompany),
                ]
            )
        }
    }

    /// The draft the evaluation produced when the description does not state the role of the job that ended: the title is the
    /// headline's, and the clause of the job (employer, years, a verb) does not say it.
    static let copied: [Case] = [
        Case(input: "en-traps", name: "Priya Nolan", location: "Bristol", headline: "registered nurse",
             currentTitle: "nurse", currentCompany: "St Brigid's Hospital", pastTitle: "nurse", pastCompany: "Greenway Care Home"),
        Case(input: "de-traps", name: "Lena Hoffmeister", location: "Kassel", headline: "Physiotherapeutin",
             currentTitle: "Physiotherapeutin", currentCompany: "Praxis Sonnenhof",
             pastTitle: "Physiotherapeutin", pastCompany: "Reha-Klinik Waldblick"),
        Case(input: "es-traps", name: "Diego Salcedo", location: "Zaragoza", headline: "contable",
             currentTitle: "contable", currentCompany: "Transportes Ebro Norte",
             pastTitle: "contable", pastCompany: "gestoría Aranda y Molina"),
        Case(input: "fr-traps", name: "Hugo Lefèvre", location: "Lyon", headline: "technicien informatique",
             currentTitle: "technicien informatique", currentCompany: "Rhône Services Numériques",
             pastTitle: "technicien", pastCompany: "Copilux"),
        Case(input: "pt-plain", name: "Beatriz Moura", location: "Coimbra", headline: "enfermeira",
             currentTitle: "enfermeira", currentCompany: "Hospital da Ribeira",
             pastTitle: "enfermeira", pastCompany: "Centro de Saúde de Vale Verde"),
    ]

    /// The draft of a description that states the role of the job that ended in the clause that names it.
    static let stated: [Case] = [
        Case(input: "en-plain", name: "Daniel Hart", location: nil, headline: "warehouse supervisor",
             currentTitle: "warehouse supervisor", currentCompany: "Northfield Logistics",
             pastTitle: "forklift driver", pastCompany: "Kestrel Foods"),
        Case(input: "it-plain", name: "Luca Ferrandi", location: nil, headline: "cuoco",
             currentTitle: "cuoco", currentCompany: "Il Gabbiano", pastTitle: "aiuto cuoco", pastCompany: "Hotel Belvedere"),
        Case(input: "de-plain", name: "Jonas Albrecht", location: nil, headline: "Elektriker",
             currentTitle: "Elektriker", currentCompany: "Elektro Brandner",
             pastTitle: "Monteur", pastCompany: "Haustechnik Kellner"),
        Case(input: "es-plain", name: "Carmen Ibarra", location: nil, headline: "diseñadora gráfica",
             currentTitle: "diseñadora gráfica", currentCompany: "estudio Lumbre Creativa",
             pastTitle: "maquetadora", pastCompany: "editorial Mar de Letras"),
        Case(input: "fr-plain", name: "Camille Durand", location: nil, headline: "boulangère",
             currentTitle: "boulangère", currentCompany: "Boulangerie des Tilleuls",
             pastTitle: "vendeuse", pastCompany: "Pâtisserie Bellevue"),
    ]

    private func sanitized(_ item: Case) throws -> CVData {
        let written = try #require(DraftingInputs.written.first { $0.id == item.input })
        return try CVDataSanitizer().sanitize(item.draft, against: written.description)
    }

    @Test("The title of the headline goes from the job that ended, whose employer stays", arguments: copied)
    func copiedTitleGoes(item: Case) throws {
        let result = try sanitized(item)

        #expect(result.experience[1].title.isEmpty,
                "\(item.input): \"\(item.pastTitle)\" is what the person is now; the clause of the job does not state it, got \"\(result.experience[1].title)\"")
        #expect(result.experience[1].company == item.pastCompany, "\(item.input): the employer is stated and stays")
    }

    @Test("The title of the headline stays on the job that goes on", arguments: copied)
    func currentTitleStays(item: Case) throws {
        let result = try sanitized(item)

        #expect(result.experience[0].title == item.currentTitle, "\(item.input): got \"\(result.experience[0].title)\"")
        #expect(result.experience[0].company == item.currentCompany, "\(item.input): the employer stays")
    }

    @Test("The title the description states for the job that ended stays", arguments: stated)
    func statedTitleStays(item: Case) throws {
        let result = try sanitized(item)

        #expect(result.experience[1].title == item.pastTitle, "\(item.input): the clause of the job states \"\(item.pastTitle)\", got \"\(result.experience[1].title)\"")
        #expect(result.experience[0].title == item.currentTitle, "\(item.input): the job that goes on keeps its title")
    }
}
