import Testing
@testable import CVGeneratorAI

/// ADR 0031: a duty the person said with a gerund is written in the first person of the job's other duties, so a job's text keeps
/// one form. The dictionary is `TableWordList`, which knows every word but the invented names.
@Suite("A duty said with a gerund, in the job's first person (ADR 0031)")
struct FirstPersonDutyTests {
    private let words = TableWordList()

    @Test("An English gerund duty of a past job is written after I was")
    func englishPastGerund() {
        let duty = FirstPersonDuty.written(
            "setting up the PA systems and mixing the support acts.", current: false, language: .english, wordList: words
        )
        #expect(duty == "I was setting up the PA systems and mixing the support acts.")
    }

    @Test("An English gerund duty of the current job is written after I am")
    func englishCurrentGerund() {
        let duty = FirstPersonDuty.written("training the junior technicians.", current: true, language: .english, wordList: words)
        #expect(duty == "I am training the junior technicians.")
    }

    @Test("An English word in -ing that is no gerund keeps the duty as it is")
    func englishNotGerund() {
        #expect(FirstPersonDuty.written("bring the cables to the stage.", current: false, language: .english, wordList: words)
            == "Bring the cables to the stage.")
    }

    @Test("Each Italian gerund that opens a part is written in the imperfect for a past job")
    func italianPastGerunds() {
        let duty = FirstPersonDuty.written(
            "controllando i quadri elettrici e programmando la manutenzione preventiva.", current: false, language: .italian, wordList: words
        )
        #expect(duty == "Controllavo i quadri elettrici e programmavo la manutenzione preventiva.")
    }

    @Test("Each Italian gerund is written in the present for the current job")
    func italianPresentGerunds() {
        let duty = FirstPersonDuty.written("controllando i quadri, programmando i turni.", current: true, language: .italian, wordList: words)
        #expect(duty == "Controllo i quadri, programmo i turni.")
    }

    @Test("A word that ends as a gerund after an article keeps its form")
    func italianNounKept() {
        let duty = FirstPersonDuty.written("usando il comando del quadro.", current: false, language: .italian, wordList: words)
        #expect(duty == "Usavo il comando del quadro.")
    }

    @Test("A duty in the first person only gets its capital letter")
    func firstPersonKept() {
        #expect(FirstPersonDuty.written("gestisco le fatture dei fornitori.", current: true, language: .italian, wordList: words)
            == "Gestisco le fatture dei fornitori.")
        #expect(FirstPersonDuty.written("I rigged the lights.", current: false, language: .english, wordList: words) == "I rigged the lights.")
    }

    @Test("A gerund whose first person the word list does not know keeps the duty as the person said it")
    func unknownFormKept() {
        let list = TableWordList(names: ["controllavo"])
        let duty = FirstPersonDuty.written("controllando i quadri elettrici.", current: false, language: .italian, wordList: list)
        #expect(duty == "Controllando i quadri elettrici.")
    }
}
