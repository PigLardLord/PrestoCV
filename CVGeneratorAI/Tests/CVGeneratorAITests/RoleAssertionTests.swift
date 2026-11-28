import Foundation
import Testing
@testable import CVGeneratorAI

/// A sentence of the draft may say the person is, or works as, only what a kept title names (#354, the final gate; ADR 0031, O1).
/// The draft infers the skills and duties typical of a stated role, never a role the person did not state.
@Suite("A role the draft puts forward is one the person stated")
struct RoleAssertionTests {
    // MARK: - Roles

    @Test("A role no kept title names is caught, in every language and construction", arguments: RoleCase.flagged)
    func flagged(_ item: RoleCase) {
        let role = RoleAssertion.unkeptRole(in: item.sentence, titles: item.titles, name: item.name, language: item.language)

        #expect(role != nil, "\(item)")
    }

    @Test("A kept title, a part of a team, a quality or a phrase that only starts like a role is no unkept role", arguments: RoleCase.kept)
    func kept(_ item: RoleCase) {
        let role = RoleAssertion.unkeptRole(in: item.sentence, titles: item.titles, name: item.name, language: item.language)

        #expect(role == nil, "\(item): \(role ?? "")")
    }

    @Test("The role caught is the noun phrase after the lead, with its qualities left out")
    func caughtPhrase() {
        let titles = ["nursing assistant"]

        #expect(RoleAssertion.unkeptRole(
            in: "As a nurse, I coordinate patient care and support the clinical team.", titles: titles, name: nil, language: .english
        ) == "nurse")
        #expect(RoleAssertion.unkeptRole(
            in: "As an experienced head nurse, I plan the shifts.", titles: titles, name: nil, language: .english
        ) == "head nurse")
        #expect(RoleAssertion.unkeptRole(
            in: "Lavoro come infermiera presso l'ospedale.", titles: ["operatrice socio-sanitaria"], name: nil, language: .italian
        ) == "infermiera")
        #expect(RoleAssertion.unkeptRole(
            in: "As a nursing assistant and nurse, I coordinate patient care.", titles: titles, name: nil, language: .english
        ) == "nurse")
        #expect(RoleAssertion.unkeptRole(
            in: "Lavoro come cameriere e un cuoco attento.", titles: ["cameriere"], name: nil, language: .italian
        ) == "cuoco attento")
        #expect(RoleAssertion.unkeptRole(
            in: "Sono un cuoco e capo reparto vendite.", titles: ["cuoco"], name: nil, language: .italian
        ) == "capo reparto vendite")
        #expect(RoleAssertion.unkeptRole(
            in: "Soy una cajera y jefa de sección.", titles: ["cajera"], name: nil, language: .spanish
        ) == "jefa")
    }

    @Test("A text in no language of the six puts no role forward")
    func noLanguage() {
        #expect(RoleAssertion.unkeptRole(in: "As a nurse, I coordinate patient care.", titles: [], name: nil, language: nil) == nil)
    }
}

// MARK: - Cases

struct RoleCase: Sendable, CustomTestStringConvertible {
    let language: Vocabulary.Language
    let titles: [String]
    var name: String?
    let sentence: String

    var testDescription: String { "\(language.rawValue) \(titles): \(sentence)" }

    init(_ language: Vocabulary.Language, _ titles: [String], _ sentence: String, name: String? = nil) {
        self.language = language
        self.titles = titles
        self.name = name
        self.sentence = sentence
    }

    static let flagged: [RoleCase] = [
        RoleCase(.english, ["nursing assistant"], "As a nurse, I coordinate patient care and support the clinical team."),
        RoleCase(.english, ["nursing assistant"], "I am a nurse at Riverside."),
        RoleCase(.english, ["nursing assistant"], "I have been a nurse for ten years."),
        RoleCase(.english, ["nursing assistant"], "I worked as a nurse in a hospital."),
        RoleCase(.english, ["teacher"], "As a head teacher, I plan lessons."),
        RoleCase(.italian, ["operatrice socio-sanitaria"], "Come infermiera, coordino l'assistenza ai pazienti."),
        RoleCase(.italian, ["operatrice socio-sanitaria"], "Lavoro come infermiera presso l'ospedale."),
        RoleCase(.italian, ["operatrice socio-sanitaria"], "Sono un'infermiera attenta."),
        RoleCase(.italian, ["geometra"], "In passato ho lavorato come tecnico."),
        RoleCase(.german, ["Pflegehelferin"], "Als Krankenpflegerin koordiniere ich die Pflege."),
        RoleCase(.german, ["Pflegehelferin"], "Ich arbeite als Krankenpflegerin im Klinikum."),
        RoleCase(.german, ["Pflegehelferin"], "Ich bin Krankenpflegerin."),
        RoleCase(.french, ["aide-soignante"], "Comme infirmière, je coordonne les soins."),
        RoleCase(.french, ["aide-soignante"], "Je travaille comme infirmière à l'hôpital."),
        RoleCase(.french, ["aide-soignante"], "En tant qu'infirmière, je coordonne les soins."),
        RoleCase(.french, ["aide-soignante"], "Je suis une infirmière attentive."),
        RoleCase(.spanish, ["auxiliar de enfermería"], "Como enfermera, coordino la atención."),
        RoleCase(.spanish, ["auxiliar de enfermería"], "Trabajo como enfermera en el hospital."),
        RoleCase(.spanish, ["auxiliar de enfermería"], "Soy una enfermera atenta."),
        RoleCase(.portuguese, ["auxiliar de enfermagem"], "Como enfermeira, coordeno os cuidados."),
        RoleCase(.portuguese, ["auxiliar de enfermagem"], "Trabalho como enfermeira no hospital."),
        RoleCase(.portuguese, ["auxiliar de enfermagem"], "Sou uma enfermeira atenta."),
        RoleCase(.english, ["nursing assistant"], "As a nursing assistant and nurse, I coordinate patient care."),
        RoleCase(.english, ["nursing assistant"], "I work as a nursing assistant and caregiver in a care home."),
        RoleCase(.italian, ["cameriere"], "Lavoro come cameriere e cuoco."),
        RoleCase(.italian, ["cameriere"], "Lavoro come cameriere e un cuoco attento."),
        RoleCase(.german, ["Pflegehelferin"], "Ich arbeite als Pflegehelferin und Krankenpflegerin."),
        RoleCase(.spanish, ["camarero"], "Trabajo como camarero y cocinero."),
        RoleCase(.french, ["serveur"], "Je travaille comme serveur et un cuisinier attentif."),
        // A joined role of more words, or one that a function word follows, with no article before it (#359 P6).
        RoleCase(.italian, ["cuoco"], "Sono un cuoco e capo reparto vendite."),
        RoleCase(.italian, ["commessa"], "Lavoro come commessa e capo reparto vendite."),
        RoleCase(.italian, ["cameriere"], "Lavoro come cameriere e capo sala."),
        RoleCase(.spanish, ["cajera"], "Soy una cajera y jefa de sección."),
        RoleCase(.spanish, ["camarero"], "Trabajo como camarero y gerente del local."),
        RoleCase(.french, ["vendeuse"], "Je suis une vendeuse et chef de rayon."),
        RoleCase(.french, ["serveur"], "Je travaille comme serveur et directeur de salle."),
        RoleCase(.portuguese, ["caixa"], "Sou uma caixa e chefe de seção."),
        RoleCase(.portuguese, ["caixa"], "Trabalho como caixa e coordenadora de equipe."),
    ]

    static let kept: [RoleCase] = [
        RoleCase(.english, ["nursing assistant"], "As a nursing assistant, I help patients with personal care."),
        RoleCase(.english, ["nursing assistant"], "As an experienced nursing assistant, I help patients."),
        RoleCase(.english, ["nursing assistant"], "As part of the team, I help patients."),
        RoleCase(.english, ["nursing assistant"], "As well as personal care, I help with meals."),
        RoleCase(.english, ["nursing assistant"], "I work as part of a small team."),
        RoleCase(.english, ["nursing assistant"], "I am a reliable team player."),
        RoleCase(.english, ["nursing assistant"], "As a result, patients feel safe."),
        RoleCase(.english, ["primary school teacher"], "As a teacher, I plan lessons."),
        RoleCase(.italian, ["operatrice socio-sanitaria"], "Come operatrice socio-sanitaria, aiuto i pazienti."),
        RoleCase(.italian, ["operatrice socio-sanitaria"], "Lavoro come parte di una squadra."),
        RoleCase(.italian, ["manutentore elettromeccanico", "operaio manutentore"],
                 "In passato ho lavorato come manutentore elettromeccanico e operaio manutentore."),
        RoleCase(.german, ["Pflegehelferin"], "Als Pflegehelferin unterstütze ich die Pflegekräfte."),
        RoleCase(.german, ["Pflegehelferin"], "Ich bin Maria Rossi und helfe Patienten.", name: "Maria Rossi"),
        RoleCase(.german, ["Pflegehelferin"], "Als Teil des Teams helfe ich Patienten."),
        RoleCase(.german, ["Landschaftsgärtnerin"], "Als Gärtnerin pflege ich Beete."),
        RoleCase(.french, ["aide-soignante"], "En tant qu'aide-soignante, j'aide les patients."),
        RoleCase(.spanish, ["auxiliar de enfermería"], "Como auxiliar de enfermería, ayudo a los pacientes."),
        RoleCase(.portuguese, ["auxiliar de enfermagem"], "As forças da equipe são a atenção e o cuidado."),
        RoleCase(.portuguese, ["programador"], "Trabalho como programador utilizando ferramentas modernas."),
        RoleCase(.english, ["nursing assistant"], "As a nursing assistant and team player, I help patients."),
        RoleCase(.english, ["nursing assistant"], "I work as a nursing assistant and help patients with personal care."),
        RoleCase(.english, ["sound technician", "stagehand"], "I work as a sound technician and stagehand."),
        RoleCase(.italian, ["operatrice socio-sanitaria"], "Lavoro come operatrice socio-sanitaria e aiuto i pazienti."),
        RoleCase(.italian, ["operatrice socio-sanitaria"], "Lavoro come operatrice socio-sanitaria e mi occupo di igiene."),
        RoleCase(.italian, ["Sviluppatore iOS"], "Lavoro come sviluppatore iOS e scrivo applicazioni per iPhone."),
        RoleCase(.italian, ["cameriere"], "Lavoro come cameriere e assisto i clienti."),
        RoleCase(.italian, ["cameriere"], "Lavoro come cameriere e collaboro con la cucina."),
        RoleCase(.german, ["Pflegehelferin"], "Ich arbeite als Pflegehelferin und helfe Patienten."),
        RoleCase(.spanish, ["camarero"], "Trabajo como camarero y atiendo a los clientes."),
        // The joined role is one the person stated, so a kept title holds it (#359 P6).
        RoleCase(.italian, ["cuoco e capo reparto vendite"], "Sono un cuoco e capo reparto vendite."),
        RoleCase(.italian, ["commessa", "capo reparto vendite"], "Lavoro come commessa e capo reparto vendite."),
        RoleCase(.spanish, ["cajera y jefa de sección"], "Soy una cajera y jefa de sección."),
        RoleCase(.french, ["vendeuse", "chef de rayon"], "Je suis une vendeuse et chef de rayon."),
        RoleCase(.portuguese, ["caixa", "chefe de seção"], "Sou uma caixa e chefe de seção."),
        // A verb after the joining word is no role, listed or not, with an object or a place after it (#359 P6).
        RoleCase(.italian, ["commessa"], "Sono una commessa e lavoro a Roma."),
        RoleCase(.italian, ["commessa"], "Sono una commessa e vivo a Roma."),
        RoleCase(.italian, ["commessa"], "Sono una commessa e vendo scarpe."),
        RoleCase(.italian, ["commessa"], "Sono una commessa e consiglio i clienti con cura."),
        RoleCase(.spanish, ["cajera"], "Soy una cajera y atiendo a los clientes."),
        RoleCase(.spanish, ["cajera"], "Soy una cajera y vivo en Madrid."),
        RoleCase(.french, ["vendeuse"], "Je suis une vendeuse et je conseille les clients."),
        RoleCase(.french, ["vendeuse"], "Je suis une vendeuse et j'habite à Lyon."),
        RoleCase(.portuguese, ["caixa"], "Sou uma caixa e trabalho em Lisboa."),
        RoleCase(.portuguese, ["caixa"], "Sou uma caixa e atendo os clientes."),
        // A quality said after a role is no joined role (#359 P6).
        RoleCase(.italian, ["cuoco"], "Sono un cuoco preciso e responsabile nel lavoro."),
        RoleCase(.spanish, ["cajera"], "Soy una cajera atenta y responsable en mi trabajo."),
    ]
}
