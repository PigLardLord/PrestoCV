import Testing
import Foundation
@testable import CVGeneratorAI

/// Every fact is the person's (ADR 0023, rule (c)): languages and their levels, skills, interests, certifications and the person's
/// own name, contacts, place and title are kept only as a clause that speaks for the person, or a list with no verb, gives them.
@Suite("Sanitizer: every fact is the person's")
struct SanitizerOwnershipTests {
    private func sanitized(_ draft: CVData, from description: String, in language: String = "en") -> CVData {
        CVDataSanitizer(languageOfText: { _ in language }).sanitize(draft, against: description)
    }

    // MARK: - Languages, skills, interests

    @Test("A language of someone else goes, and the person's stays beside it, without a level when the draft gives none")
    func languageOfSomeoneElse() {
        let draft = CVData(languages: [Language(name: "Italian"), Language(name: "French", proficiency: .c2)])

        #expect(sanitized(draft, from: "I speak Italian; my sister speaks French (C2).").languages == [Language(name: "Italian")])
        #expect(sanitized(draft, from: "I speak Italian and my sister speaks French (C2).").languages == [Language(name: "Italian")])
        #expect(sanitized(draft, from: "I speak Italian, my sister French (C2).").languages == [Language(name: "Italian")])
        #expect(sanitized(draft, from: "My sister speaks French (C2). I speak Italian.").languages == [Language(name: "Italian")])
    }

    @Test("A language of someone else goes whether the draft rates it or not")
    func languageOfSomeoneElseWithOrWithoutALevel() {
        #expect(sanitized(CVData(languages: [Language(name: "French")]), from: "My sister speaks French.").languages.isEmpty)
        #expect(sanitized(CVData(languages: [Language(name: "French", proficiency: .b2)]), from: "My sister speaks French (B2).").languages.isEmpty)
    }

    @Test("The level of someone else is not the person's: the person's own level stays")
    func levelOfSomeoneElse() {
        let description = "I speak German (A2). My colleague speaks German (B2)."

        #expect(sanitized(CVData(languages: [Language(name: "German", proficiency: .b2)]), from: description).languages.isEmpty)
        #expect(sanitized(CVData(languages: [Language(name: "German", proficiency: .a2)]), from: description).languages.count == 1)
    }

    @Test("A verbless list, and a possession of one of the person's own fields, speak for the person", arguments: [
        ("Languages: Italian (native), French (C2).", "en"),
        ("Lingue: italiano (madrelingua), francese (C2).", "it"),
        ("My native language is Italian, and my French is fluent (C2).", "en"),
        ("La mia madrelingua \u{e8} l'italiano, e il mio francese \u{e8} fluente (C2).", "it"),
        ("Meine Muttersprache ist Italienisch, und mein Franz\u{f6}sisch ist flie\u{df}end (C2).", "de"),
    ])
    func languagesOfThePerson(description: String, language: String) {
        let names = ["en": ("Italian", "French"), "it": ("italiano", "francese"), "de": ("Italienisch", "Franz\u{f6}sisch")]
        let (first, second) = names[language]!
        let draft = CVData(languages: [Language(name: first, proficiency: .native), Language(name: second, proficiency: .c2)])

        #expect(sanitized(draft, from: description, in: language).languages.map(\.name) == [first, second])
    }

    @Test("A skill or an interest of someone else goes, and a list of items with a gerund or a participle is the person's", arguments: [
        ("I know Swift; my brother knows Kotlin.", "en"),
        ("Conosco Swift; mio fratello conosce Kotlin.", "it"),
        ("Conozco Swift y mi hermano conoce Kotlin.", "es"),
    ])
    func skillOfSomeoneElse(description: String, language: String) {
        let draft = CVData(skills: [Skill(name: "Swift"), Skill(name: "Kotlin")])

        #expect(sanitized(draft, from: description, in: language).skills == [Skill(name: "Swift")])
    }

    @Test("An item of a list is the person's: a gerund after a noun is no verb a subject goes with, nor is a form that is a noun too", arguments: [
        ("Interests: reading, hiking and cooking.", "en", ["reading", "hiking", "cooking"]),
        ("Skills: problem solving, quality control, customer support.", "en", ["problem solving", "quality control", "customer support"]),
        ("Mi occupo di gestione progetti, direzione lavori e sicurezza nei cantieri.", "it",
         ["gestione progetti", "direzione lavori", "sicurezza nei cantieri"]),
    ])
    func listItems(description: String, language: String, items: [String]) {
        let draft = CVData(skills: items.map { Skill(name: $0) }, interests: items)
        let result = sanitized(draft, from: description, in: language)

        #expect(result.interests == items || result.skills.map(\.name) == items)
    }

    @Test("A possession of the person's own experience or work speaks for them, and a colleague's does not")
    func experience() {
        let draft = CVData(skills: [Skill(name: "triage"), Skill(name: "Kotlin")])

        #expect(sanitized(draft, from: "My experience includes triage. My colleague's experience includes Kotlin.").skills.map(\.name) == ["triage"])
        #expect(sanitized(draft, from: "My skills include triage and my colleague's skills include Kotlin.").skills.map(\.name) == ["triage"])
    }

    @Test("An interest of someone else goes; the person's, with the pronoun dropped, stays", arguments: [
        ("My wife loves chess.", "I love chess.", "en", "chess"),
        ("Mia moglie ama gli scacchi.", "Mi piacciono gli scacchi.", "it", "scacchi"),
        ("Mi esposa ama el ajedrez.", "Me gustan el ajedrez.", "es", "ajedrez"),
    ])
    func interestOfSomeoneElse(theirs: String, mine: String, language: String, interest: String) {
        let draft = CVData(interests: [interest])

        #expect(sanitized(draft, from: theirs, in: language).interests.isEmpty)
        #expect(sanitized(draft, from: mine, in: language).interests == [interest])
        #expect(sanitized(draft, from: "\(theirs) \(mine)", in: language).interests == [interest])
    }

    @Test("The description as the person speaks it is read in the language of the whole description, and holds no name that only a clause of someone else gives")
    func spokenDescription() {
        let source = DescriptionText("Parlo italiano; mia sorella parla francese.", languageOfText: { _ in "it" })
        let spoken = DescriptionText(sentences: ["Parlo italiano; ; "], of: source)

        #expect(spoken.explainer.language == .italian)
        #expect(spoken.named("italiano") == "italiano")
        #expect(spoken.named("francese") == nil)
        #expect(source.named("francese") == "francese")
    }

    // MARK: - The person's own fields

    @Test("A contact of someone else goes, and the person's own stays: a possession of the person's own field speaks for them", arguments: [
        ("My sister's email is anna@example.com.", "anna@example.com", false),
        ("My email is anna@example.com. My sister's email is bea@example.com.", "bea@example.com", false),
        ("My email is anna@example.com. My sister's email is bea@example.com.", "anna@example.com", true),
        ("Email: anna@example.com. Her email: bea@example.com.", "bea@example.com", false),
        ("anna@example.com is my email.", "anna@example.com", true),
        ("You can reach me at anna@example.com or my manager at bea@example.com.", "bea@example.com", false),
        ("You can reach me at anna@example.com or my manager at bea@example.com.", "anna@example.com", true),
    ])
    func email(description: String, email: String, isKept: Bool) {
        let result = sanitized(CVData(personalInfo: PersonalInfo(email: email)), from: description)

        #expect((result.personalInfo.email == email) == isKept, "\(description) -> \(email)")
    }

    @Test("The phone, the links, the place, the name and the title follow the same rule")
    func otherFields() {
        func kept(_ info: PersonalInfo, from description: String) -> PersonalInfo {
            sanitized(CVData(personalInfo: info), from: description).personalInfo
        }

        #expect(kept(PersonalInfo(phone: "+39 333 123 4567"), from: "My brother's phone number is +39 333 123 4567.").phone == nil)
        #expect(kept(PersonalInfo(phone: "+39 333 123 4567"), from: "My phone number is +39 333 123 4567.").phone == "+39 333 123 4567")
        #expect(kept(PersonalInfo(website: "example.com/her"), from: "My page is example.com/me. My sister's page is example.com/her.").website == nil)
        #expect(kept(PersonalInfo(website: "example.com/me"), from: "My page is example.com/me. My sister's page is example.com/her.").website == "example.com/me")
        #expect(kept(PersonalInfo(location: "Milan"), from: "I live in Rome. My manager lives in Milan.").location == nil)
        #expect(kept(PersonalInfo(location: "Rome"), from: "I live in Rome. My manager lives in Milan.").location == "Rome")
        #expect(kept(PersonalInfo(name: "Anna Verdi"), from: "My manager is Anna Verdi.").name == nil)
        #expect(kept(PersonalInfo(name: "Anna Verdi"), from: "My name is Anna Verdi.").name == "Anna Verdi")
        #expect(kept(PersonalInfo(name: "Anna Verdi"), from: "I'm Anna Verdi, a nurse from Turin.").name == "Anna Verdi")
        #expect(kept(PersonalInfo(title: "nurse"), from: "My sister is a nurse.").title == nil)
        #expect(kept(PersonalInfo(title: "nurse"), from: "I'm a nurse. My sister is a doctor.").title == "nurse")
    }

    @Test("The e of e-mail is no conjunction: the email of the person stays in Italian and Portuguese")
    func eMailInRomanceLanguages() {
        let draft = CVData(personalInfo: PersonalInfo(email: "anna@example.com"))

        #expect(sanitized(draft, from: "La mia e-mail \u{e8} anna@example.com.", in: "it").personalInfo.email == "anna@example.com")
        #expect(sanitized(draft, from: "Meu e-mail \u{e9} anna@example.com.", in: "pt").personalInfo.email == "anna@example.com")
        #expect(sanitized(draft, from: "A e-mail da minha irm\u{e3} \u{e9} anna@example.com.", in: "pt").personalInfo.email == nil)
    }

    @Test("An address on its own, or at the start of a sentence, speaks for the person as a list does")
    func addressOnItsOwn() {
        let draft = CVData(personalInfo: PersonalInfo(email: "anna@example.com"))

        #expect(sanitized(draft, from: "anna@example.com").personalInfo.email == "anna@example.com")
        #expect(sanitized(draft, from: "anna@example.com is my email.").personalInfo.email == "anna@example.com")
        #expect(sanitized(draft, from: "anna@example.com is my sister's email.").personalInfo.email == nil)
    }

    // MARK: - Titles

    @Test("A title that a clause about someone else gives for the entry is not the entry's")
    func titleOfSomeoneElse() {
        let job = Experience(title: "nurse", company: "Acme")

        #expect(sanitized(CVData(experience: [job]), from: "I worked at Acme. My sister is a nurse at Acme.").experience.map(\.title) == [""])
        #expect(sanitized(CVData(experience: [job]), from: "I worked at Acme as a nurse. My sister is a doctor.").experience.map(\.title) == ["nurse"])
    }

    @Test("What the person's own clauses give is kept when a clause about someone else comes between them")
    func someoneElseBetween() {
        let draft = CVData(
            personalInfo: PersonalInfo(location: "Rome"),
            experience: [Experience(title: "", company: "Acme", startDate: "2016")],
            skills: [Skill(name: "Swift")],
            interests: ["chess"]
        )
        let description = "I live in Rome. My sister lives in Milan. I worked at Acme since 2016. My brother knows Kotlin. I know Swift and I like chess."

        #expect(sanitized(draft, from: description) == draft)
    }
}
