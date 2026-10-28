import Testing
import Foundation
@testable import CVGeneratorAI

/// What an AI draft may rate: a skill level or a language level only where the description states it for that very skill
/// or language, by a CEFR code or a level word in the same sentence. Otherwise a skill is unrated, and a language the description
/// names for the person stays without a level (lead decision, #354); a language it never names goes.
@Suite("Sanitizer: a level must be stated for its own skill or language")
struct SanitizerLevelTests {
    private let sanitizer = CVDataSanitizer()

    private func languages(_ languages: [Language], from description: String) throws -> [Language] {
        try sanitizer.sanitize(CVData(languages: languages), against: description).languages
    }

    private func skills(_ skills: [Skill], from description: String) throws -> [Skill] {
        try sanitizer.sanitize(CVData(skills: skills), against: description).skills
    }

    // MARK: - Languages

    @Test("A language keeps the level the description states for it")
    func statedLanguageLevel() throws {
        let given = [Language(name: "Italian", proficiency: .native), Language(name: "English", proficiency: .b2)]

        let result = try languages(given, from: "I speak Italian (native) and English (B2).")

        #expect(result == given)
    }

    @Test("A language loses a level that is not the stated one, and stays without one (#354)")
    func wrongLanguageLevel() throws {
        let given = [Language(name: "Italian", proficiency: .native), Language(name: "English", proficiency: .c1)]

        let result = try languages(given, from: "I speak Italian (native) and English (B2).")

        #expect(result == [Language(name: "Italian", proficiency: .native), Language(name: "English")], "English was stated as B2, not C1")
    }

    @Test("A language the draft gives no level may stay without one; a level the description does not state for it goes alone (#354)")
    func languageWithoutALevel() throws {
        #expect(try languages([Language(name: "French")], from: "I speak French.") == [Language(name: "French")])
        #expect(try languages([Language(name: "French", proficiency: .b2)], from: "I speak French.") == [Language(name: "French")])
        #expect(try languages([Language(name: "German")], from: "I speak French.").isEmpty, "a language the description never names")
    }

    @Test("A language stays without a level when the description states none for it (#354)")
    func unstatedLanguageLevel() throws {
        let given = [Language(name: "Italian", proficiency: .native), Language(name: "English", proficiency: .b2)]

        #expect(try languages(given, from: "I speak Italian and English.") == [Language(name: "Italian"), Language(name: "English")])
    }

    @Test("A level stated in another sentence, or for a language not named, does not count")
    func levelOfSomethingElse() throws {
        let given = [Language(name: "Italian", proficiency: .native)]

        #expect(try languages(given, from: "I speak Italian. My brother is a native speaker.") == [Language(name: "Italian")])
        #expect(try languages(given, from: "I speak Italian and my sister speaks French (native).") == [Language(name: "Italian")])
    }

    @Test("A language the description never names is left out, whatever level it is given")
    func unnamedLanguage() throws {
        #expect(try languages([Language(name: "French", proficiency: .a1)], from: "I speak Italian (native).").isEmpty)
    }

    @Test("A CEFR code is exact: it wins over a level word")
    func codeBeatsWord() throws {
        let description = "My English is fluent, B2 on paper."

        #expect(try languages([Language(name: "English", proficiency: .b2)], from: description).count == 1)
        #expect(try languages([Language(name: "English", proficiency: .c1)], from: description) == [Language(name: "English")])
    }

    @Test("In a sentence with several languages each level belongs to the nearest one")
    func nearestLanguageWins() throws {
        let description = "I speak native Italian and basic English."
        let right = [Language(name: "Italian", proficiency: .native), Language(name: "English", proficiency: .a1)]
        let swapped = [Language(name: "Italian", proficiency: .a1), Language(name: "English", proficiency: .native)]

        #expect(try languages(right, from: description) == right)
        #expect(try languages(swapped, from: description) == [Language(name: "Italian"), Language(name: "English")])
    }

    @Test("Without an \"and\" between them, each level still belongs to the nearest language")
    func nearestLanguageWithoutConjunction() throws {
        let description = "I speak Italian (native), English (B2), French (A2)."
        let right = [Language(name: "Italian", proficiency: .native), Language(name: "English", proficiency: .b2), Language(name: "French", proficiency: .a2)]
        let shifted = [Language(name: "Italian", proficiency: .b2), Language(name: "English", proficiency: .a2), Language(name: "French", proficiency: .native)]

        #expect(try languages(right, from: description) == right)
        #expect(try languages(shifted, from: description) == [Language(name: "Italian"), Language(name: "English"), Language(name: "French")])
    }

    @Test("A level nearer to another language is not taken for this one")
    func levelNearerToTheOtherLanguage() throws {
        let given = [Language(name: "Italian", proficiency: .b2), Language(name: "English", proficiency: .b2)]

        let result = try languages(given, from: "I speak Italian and English (B2).")

        #expect(result == [Language(name: "Italian"), Language(name: "English", proficiency: .b2)])
    }

    @Test("Level words are read in the app's six languages",
          arguments: [
            ("I am a fluent Spanish speaker", "Spanish", LanguageProficiency.c1),
            ("Parlo inglese (fluente)", "inglese", .c2),
            ("Ich spreche Englisch (fließend)", "Englisch", .c1),
            ("Hablo inglés (nativo)", "inglés", .native),
            ("Je parle anglais (courant)", "anglais", .c1),
            ("Falo inglês (fluente)", "inglês", .c1),
            ("Parlo italiano, madrelingua", "italiano", .native),
            ("Meine Muttersprache ist Italienisch", "Italienisch", .native),
            ("Français, langue maternelle", "Français", .native),
            ("Falo português (nativo)", "português", .native),
            ("I speak intermediate German", "German", .b1),
            ("Parlo tedesco a livello elementare", "tedesco", .a2),
            ("Hablo alemán (nivel básico)", "alemán", .a1),
          ] as [(String, String, LanguageProficiency)])
    func levelWordsInEachLanguage(description: String, name: String, level: LanguageProficiency) throws {
        #expect(try languages([Language(name: name, proficiency: level)], from: description).map(\.proficiency) == [level])
    }

    /// `stays`: the clause denies the level only, so the language stays without one (#354); otherwise the clause denies or
    /// hedges the speaking itself ("no more", "barely"), and the language goes.
    @Test("A level said with a negation or a hedge is not the level",
          arguments: [
            ("My English is not fluent", "English", true),
            ("My English isn't fluent", "English", true),
            ("I speak English (B2) no more", "English", false),
            ("I barely speak English (B2)", "English", false),
            ("I speak English (B2) only a bit", "English", true),
            ("Il mio inglese non è fluente", "inglese", true),
            ("Parlo poco inglese (B2)", "inglese", false),
            ("Mein Englisch ist nicht fließend", "Englisch", true),
            ("Ich spreche kaum Englisch (B2)", "Englisch", false),
            ("Mi inglés no es fluido", "inglés", true),
            ("Hablo apenas inglés (B2)", "inglés", false),
            ("Mon anglais n'est pas courant", "anglais", true),
            ("Je parle peu anglais (B2)", "anglais", true),
            ("Meu inglês não é fluente", "inglês", true),
            ("Falo pouco inglês (B2)", "inglês", true),
          ] as [(String, String, Bool)])
    func negatedOrHedgedLanguageLevel(description: String, name: String, stays: Bool) throws {
        let claims = [LanguageProficiency.c1, .b2, .c2]

        for level in claims {
            let result = try languages([Language(name: name, proficiency: level)], from: description)
            #expect(result == (stays ? [Language(name: name)] : []), "\(level) in: \(description)")
        }
    }

    @Test("A hedge belongs to its own clause: \"a bit of German\" does not spoil the levels of the other languages",
          arguments: [
            "I speak Italian (native), English (B2) and a bit of German (A2).",
            "Parlo italiano (madrelingua), inglese (B2) e un po' di tedesco (A2).",
            "Ich spreche Italienisch (Muttersprache), Englisch (B2) und ein bisschen Deutsch (A2).",
          ])
    func hedgeStaysInItsClause(description: String) throws {
        let names = description.contains("Parlo") ? ["italiano", "inglese", "tedesco"] : description.contains("Ich") ? ["Italienisch", "Englisch", "Deutsch"] : ["Italian", "English", "German"]
        let claimed = [
            Language(name: names[0], proficiency: .native),
            Language(name: names[1], proficiency: .b2),
            Language(name: names[2], proficiency: .a2),
        ]

        let result = try languages(claimed, from: description)

        #expect(result == [claimed[0], claimed[1], Language(name: names[2])], "Only the hedged language loses its level, and keeps its place (#354)")
    }

    @Test("The same sentences without the negation keep their level")
    func affirmativeControls() throws {
        #expect(try languages([Language(name: "English", proficiency: .c1)], from: "My English is fluent").count == 1)
        #expect(try languages([Language(name: "inglese", proficiency: .c1)], from: "Il mio inglese è fluente").count == 1)
        #expect(try languages([Language(name: "Englisch", proficiency: .c1)], from: "Mein Englisch ist fließend").count == 1)
        #expect(try languages([Language(name: "inglés", proficiency: .c1)], from: "Mi inglés es fluido").count == 1)
        #expect(try languages([Language(name: "anglais", proficiency: .c1)], from: "Mon anglais est courant").count == 1)
        #expect(try languages([Language(name: "inglês", proficiency: .c1)], from: "Meu inglês é fluente").count == 1)
    }

    @Test("A negation in another sentence does not spoil a stated level")
    func negationElsewhere() throws {
        let description = "I do not like exams. My English is fluent."

        #expect(try languages([Language(name: "English", proficiency: .c1)], from: description).count == 1)
    }

    // MARK: - Skills

    @Test("A skill keeps the level the description states for it, and is unrated otherwise")
    func skillLevels() throws {
        let given = [Skill(name: "Swift", level: .expert), Skill(name: "Python", level: .advanced), Skill(name: "Java", level: .beginner)]

        let result = try skills(given, from: "I'm an expert in Swift and I know Python. I once used Java (beginner).")

        #expect(result == [Skill(name: "Swift", level: .expert), Skill(name: "Python"), Skill(name: "Java", level: .beginner)])
    }

    @Test("A skill is unrated when the draft's level is not the stated one")
    func wrongSkillLevel() throws {
        #expect(try skills([Skill(name: "Swift", level: .beginner)], from: "I'm an expert in Swift.") == [Skill(name: "Swift")])
    }

    @Test("A skill's level is the nearest one in the sentence")
    func skillLevelNearestWins() throws {
        let given = [Skill(name: "Swift", level: .expert), Skill(name: "Python", level: .expert)]

        #expect(try skills(given, from: "I'm an expert in Swift and a beginner in Python.") == [Skill(name: "Swift", level: .expert), Skill(name: "Python")])
    }

    @Test("A skill level said with a negation or a hedge is not the level",
          arguments: [
            "I am not an expert in Swift",
            "I'm hardly an expert in Swift",
            "I'm a bit of an expert in Swift",
            "Non sono esperto di Swift",
            "Ich bin kein Experte für Swift",
            "No soy experto en Swift",
            "Je ne suis pas expert en Swift",
            "Não sou especialista em Swift",
          ])
    func negatedSkillLevel(description: String) throws {
        #expect(try skills([Skill(name: "Swift", level: .expert)], from: description) == [Skill(name: "Swift")])
    }

    @Test("The same sentences without the negation keep their level")
    func affirmativeSkillControls() throws {
        #expect(try skills([Skill(name: "Swift", level: .expert)], from: "I am an expert in Swift") == [Skill(name: "Swift", level: .expert)])
        #expect(try skills([Skill(name: "Swift", level: .expert)], from: "Sono esperto di Swift") == [Skill(name: "Swift", level: .expert)])
    }

    @Test("Level words for skills are read in the app's six languages",
          arguments: [
            ("Sono esperto di Swift", SkillLevel.expert),
            ("Ich bin Experte für Swift", .expert),
            ("Soy experto en Swift", .expert),
            ("Je suis expert en Swift", .expert),
            ("Sou especialista em Swift", .expert),
            ("Swift (principiante)", .beginner),
            ("Swift (Anfänger)", .beginner),
            ("Swift (intermedio)", .intermediate),
            ("Swift, niveau intermédiaire", .intermediate),
            ("Swift (avanzato)", .advanced),
            ("Swift (fortgeschritten)", .advanced),
            ("Swift (avançado)", .advanced),
          ] as [(String, SkillLevel)])
    func skillLevelWordsInEachLanguage(description: String, level: SkillLevel) throws {
        #expect(try skills([Skill(name: "Swift", level: level)], from: description).first?.level == level)
    }
}
