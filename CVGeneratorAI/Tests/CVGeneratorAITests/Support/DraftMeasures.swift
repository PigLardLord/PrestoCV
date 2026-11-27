import Foundation
import CVGeneratorAI

// Run records and run sets made by hand, for the tests of the harness of the drafting evaluation. No model runs here.

/// What a test changes in a run: the draft the model wrote, and how the use case ended.
struct Tweak {
    /// Edits the draft the model wrote. The final draft is the same unless `finalEdit` edits it again.
    var edit: (inout Draft) -> Void = { _ in }
    var finalEdit: ((inout Draft) -> Void)?
    var unchecked = false
    var error: (any Error)?
    var checks: [CheckEvent] = []
    var seconds = 10.0
    /// Whether the model also wrote around the facts (`WrittenLayer`), as the instructions ask: on by default, so that a set made by
    /// hand meets the thresholds of #354 unless a test spoils them.
    var written = true
}

enum DraftMeasures {
    static let revision = "abc1234"

    /// One run of the input `id`: the draft of its facts and nothing else, as the tweak edits it.
    static func measure(_ id: String, run: Int = 1, revision: String = DraftMeasures.revision, _ tweak: Tweak = Tweak()) throws -> DraftMeasure {
        let input = try InventedFactsTests.input(id)
        var raw = Draft(faithfulTo: input)
        if tweak.written { WrittenLayer.add(to: &raw, for: input) }
        tweak.edit(&raw)
        var shown = raw
        tweak.finalEdit?(&shown)
        let result = tweak.error == nil
            ? GeneratedDraft(cvData: shown.cv, personalItemsUnchecked: tweak.unchecked) : nil
        return DraftMeasure(
            input: input, run: run, revision: revision, seconds: tweak.seconds, load: nil, raw: raw.cv, grounded: raw.cv, result: result,
            error: tweak.error, checks: tweak.checks
        )
    }

    /// `runs` runs of each of `ids`, in the order the evaluation writes them: every input once, then again.
    static func set(
        _ ids: [String], runs: Int = 1, revision: String = DraftMeasures.revision, tweak: (String, Int) -> Tweak = { _, _ in Tweak() }
    ) throws -> [DraftMeasure] {
        var measured: [DraftMeasure] = []
        for run in 1...runs {
            for id in ids {
                measured.append(try measure(id, run: run, revision: revision, tweak(id, run)))
            }
        }
        return measured
    }

    /// `tweak` for the runs of `id` (of its run number `run`, when given) and the plain tweak for every other run.
    static func tweak(_ tweak: Tweak, for id: String, run: Int? = nil) -> (String, Int) -> Tweak {
        { name, number in name == id && (run == nil || run == number) ? tweak : Tweak() }
    }

    static func manifest(_ ids: [String], runs: Int = 1, revision: String = DraftMeasures.revision, all: [String]? = nil) -> RunManifest {
        RunManifest(
            revision: revision, system: "macOS test", xcode: "27.0 (test)", started: Date(timeIntervalSince1970: 1_792_000_000),
            runsPerInput: runs, inputs: ids, allInputs: all ?? ids
        )
    }
}

/// A complete run set with its summary and review items, which a test then spoils one way at a time.
struct Scenario {
    var manifest: RunManifest
    var measured: [DraftMeasure]
    var summary: DraftSummary
    var review: [ReviewItem]
    var adjudication: Adjudication?

    /// A set that is complete, of the whole evaluation (`all` defaults to `ids`), with no adjudication.
    static func make(
        ids: [String] = ["en-plain", "it-plain"], all: [String]? = nil, runs: Int = 1, revision: String = DraftMeasures.revision,
        tweak: (String, Int) -> Tweak = { _, _ in Tweak() }
    ) throws -> Scenario {
        let measured = try DraftMeasures.set(ids, runs: runs, revision: revision, tweak: tweak)
        let started = DraftMeasures.manifest(ids, runs: runs, revision: revision, all: all)
        let manifest = started.completed(runs: started.expectedRuns)
        return Scenario(
            manifest: manifest, measured: measured,
            summary: try DraftSummary(manifest: manifest, detectedLanguages: [:], measured: measured),
            review: ReviewItem.unique(in: measured), adjudication: nil
        )
    }

    /// The same set once a person has decided every item of review.json.
    func adjudicated(by reviewer: String = "G. T.", at revision: String? = nil, as decision: Adjudication.Decision = .accept) -> Scenario {
        var scenario = self
        scenario.adjudication = Adjudication(
            reviewer: reviewer, revision: revision ?? manifest.revision,
            entries: review.map { Adjudication.Entry(key: $0.key, decision: decision, note: nil) }
        )
        return scenario
    }

    var verdict: Readiness {
        Readiness.verdict(manifest: manifest, summary: summary, review: review, adjudication: adjudication)
    }

    /// What makes en-plain write one field the counter sends to review: a hobby of several words, taken from the description.
    static var reviewedOnce: Tweak { Tweak(edit: { $0.interests.append("bake bread") }) }

    /// What makes en-plain or en-traps write two fields the counter sends to review: a language of the description, listed as a skill
    /// too. The skill is a doubt, and so is the language, which the skill now shadows.
    static var reviewed: Tweak { Tweak(edit: { $0.skills.append(Skill(name: "English")) }) }

    /// What makes en-plain write a field the counter proves invented: a hobby the description does not have. A skill it does not name
    /// is a doubt (ADR 0031), as the draft may add the skills of the person's role.
    static var invented: Tweak { Tweak(edit: { $0.interests.append("Origami") }) }
}

/// What a model writes around the facts (ADR 0031), in each language of the app: a summary of two sentences and 120 characters or
/// more, a description of each job with a sentence of 40 characters or more, 4 tools of the trade and 3 soft skills. None of it
/// holds a figure, a length, a rank, a name or a tool of another trade, so the counter calls all of it inferred and the thresholds
/// are met. An input with a list of the tools of its trade (`DraftingInputs.vocabularies`) takes 4 of them (`tools`).
enum WrittenLayer {
    struct Text {
        let summary: String
        let job: String
        let technologies: [String]
        let softSkills: [String]
    }

    /// Adds the layer to `draft`, unless the input has no role, study or field to write for.
    static func add(to draft: inout Draft, for input: DraftingInput) {
        guard input.kind != .noRole, let text = texts[input.language] else { return }
        draft.summary = text.summary
        draft.experience = draft.experience.map {
            Experience(
                title: $0.title, company: $0.company, location: $0.location, startDate: $0.startDate, endDate: $0.endDate,
                current: $0.current, description: text.job, achievements: $0.achievements
            )
        }
        draft.skills += technologies(for: input).map { Skill(name: $0, kind: .technology) }
            + text.softSkills.map { Skill(name: $0, kind: .softSkill) }
    }

    /// The technologies of the layer for `input`: 4 tools of its trade's list, or the language's.
    static func technologies(for input: DraftingInput) -> [String] {
        tools[input.id] ?? texts[input.language]?.technologies ?? []
    }

    /// 4 tools of the list of each input's trade, with no name or acronym (#354).
    static let tools: [String: [String]] = [
        "jobs-en": ["mixing desks", "line arrays", "stage monitors", "wireless microphones"],
        "jobs-it": ["multimetro", "termocamera", "oscilloscopio", "trapano"],
        "en-plain": ["reach truck", "pallet jack", "order picker", "label printer"],
        "it-traps": ["stampante", "fotocopiatrice", "calcolatrice", "foglio di calcolo"],
        "de-plain": ["Multimeter", "Spannungsprüfer", "Abisolierzange", "Akkuschrauber"],
        "es-traps": ["hoja de cálculo", "base de datos", "calculadora", "banca electrónica"],
        "pt-traps": ["terminal", "editor de código", "plataforma de teste", "IDE"],
        "example-fr": ["vidéoprojecteur", "ordinateur", "tablette", "imprimante"],
    ]

    static let texts: [String: Text] = [
        "en": Text(
            summary: "Reliable and careful worker who plans each task and keeps the place safe, tidy and well organised. "
                + "Friendly with colleagues and calm when the day gets busy.",
            job: "Planned the daily work, kept everything safe and tidy, and helped colleagues whenever they needed a hand.",
            technologies: ["computer", "telephone", "calculator", "tablet"],
            softSkills: ["Teamwork", "Reliability", "Communication"]
        ),
        "it": Text(
            summary: "Persona affidabile e precisa che organizza ogni attività con cura e mantiene l'ambiente sicuro e ordinato. "
                + "Collabora volentieri con i colleghi e resta calma nei momenti più intensi.",
            job: "Organizzava il lavoro di ogni giorno, curava la sicurezza e aiutava i colleghi quando serviva una mano.",
            technologies: ["computer", "telefono", "calcolatrice", "tablet"],
            softSkills: ["Lavoro di squadra", "Affidabilità", "Comunicazione"]
        ),
        "de": Text(
            summary: "Arbeitet zuverlässig, sorgfältig und genau und plant alles gut voraus. "
                + "Bleibt freundlich, hilfsbereit und gelassen, auch wenn es einmal hektisch wird.",
            job: "Plante alles sorgfältig voraus, arbeitete sicher und sauber und half immer gern aus.",
            technologies: ["Computer", "Telefon", "Taschenrechner", "Tablet"],
            softSkills: ["Teamfähigkeit", "Zuverlässigkeit", "Kommunikation"]
        ),
        "es": Text(
            summary: "Persona fiable y cuidadosa que organiza cada tarea con calma y mantiene el lugar de trabajo seguro y ordenado. "
                + "Colabora con gusto con sus compañeros y mantiene la calma en los días más intensos.",
            job: "Organizaba el trabajo diario, cuidaba la seguridad y ayudaba a los compañeros cuando hacía falta.",
            technologies: ["ordenador", "teléfono", "calculadora", "tableta"],
            softSkills: ["Trabajo en equipo", "Fiabilidad", "Comunicación"]
        ),
        "fr": Text(
            summary: "Personne fiable et soigneuse qui organise chaque tâche avec méthode et garde son poste de travail sûr et bien rangé. "
                + "Travaille volontiers en équipe et reste calme dans les moments les plus chargés.",
            job: "Organisait le travail de chaque jour, veillait à la sécurité et aidait les collègues quand il le fallait.",
            technologies: ["ordinateur", "téléphone", "calculatrice", "tablette"],
            softSkills: ["Travail en équipe", "Fiabilité", "Communication"]
        ),
        "pt": Text(
            summary: "Pessoa confiável e cuidadosa que organiza cada tarefa com calma e mantém o local de trabalho seguro e arrumado. "
                + "Colabora de bom grado com os colegas e mantém a calma nos dias mais intensos.",
            job: "Organizava o trabalho do dia a dia, cuidava da segurança e ajudava os colegas sempre que era preciso.",
            technologies: ["computador", "telefone", "calculadora", "tablet"],
            softSkills: ["Trabalho em equipe", "Confiabilidade", "Comunicação"]
        ),
    ]
}
