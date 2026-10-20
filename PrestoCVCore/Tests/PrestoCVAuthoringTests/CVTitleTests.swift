import Testing
import PrestoCVDomain

/// What a CV is called, with the names and roles people write in the six languages of the app.
@Suite("What a CV is called")
struct CVTitleTests {
    @Test("a CV with only the name of its person is called by that name", arguments: [
        "John Smith",           // en
        "Giulia Rossi",         // it
        "Lena Hartmann",        // de
        "Marie-Claire Dupont",  // fr
        "José García Pérez",    // es
        "João da Silva",        // pt
    ])
    func personAlone(person: String) {
        #expect(CVTitle(name: "", person: " \(person)\n", role: "") == .person(person))
    }

    @Test("the CV's own name wins over the name of its person and its role", arguments: [
        ("iOS roles", "John Smith", "Software Engineer"),
        ("Candidatura ospedale", "Giulia Rossi", "Infermiera"),
        ("Pflege – Berlin", "Lena Hartmann", "Pflegefachkraft"),
        ("Candidature Lyon", "Marie-Claire Dupont", "Développeuse"),
        ("Hospital La Paz", "José García Pérez", "Enfermero"),
        ("Vaga Lisboa", "João da Silva", "Engenheiro de software"),
    ])
    func nameFirst(name: String, person: String, role: String) {
        #expect(CVTitle(name: name, person: person, role: role) == .name(name))
    }

    @Test("the name of the person comes before the role", arguments: [
        ("John Smith", "Software Engineer"),
        ("Giulia Rossi", "Infermiera"),
        ("Lena Hartmann", "Pflegefachkraft"),
        ("Marie-Claire Dupont", "Développeuse"),
        ("José García Pérez", "Enfermero"),
        ("João da Silva", "Engenheiro de software"),
    ])
    func personBeforeRole(person: String, role: String) {
        #expect(CVTitle(name: " ", person: person, role: role) == .person(person))
    }

    @Test("without a name of its own or of its person, a CV is called by the role it is for", arguments: [
        "Senior Software Engineer",  // en
        "Infermiera",                // it
        "Pflegefachkraft",           // de
        "Développeuse",              // fr
        "Enfermero",                 // es
        "Engenheiro de software",    // pt
    ])
    func roleWithoutNames(role: String) {
        #expect(CVTitle(name: " \n", person: "\t", role: " \(role) ") == .role(role))
    }

    @Test("a CV with none of the three is untitled, and white space is none",
          arguments: [("", "", ""), (" \n", "\t", "  ")])
    func untitled(name: String, person: String, role: String) {
        #expect(CVTitle(name: name, person: person, role: role) == .untitled)
    }

    @Test("a copy is called by the title its CV is shown with, marked as a copy in the words of the app", arguments: [
        (CVTitle.person("John Smith"), "Untitled CV", "(Copy)", "John Smith (Copy)"),                // en
        (.role("Infermiera"), "CV senza titolo", "(Copia)", "Infermiera (Copia)"),                   // it
        (.person("Lena Hartmann"), "Ohne Titel", "(Kopie)", "Lena Hartmann (Kopie)"),               // de
        (.name("Candidature Lyon"), "CV sans titre", "(Copie)", "Candidature Lyon (Copie)"),         // fr
        (.untitled, "CV sin título", "(Copia)", "CV sin título (Copia)"),                           // es
        (.person("João da Silva"), "Currículo sem título", " (Cópia) ", "João da Silva (Cópia)"),    // pt
    ])
    func copyName(title: CVTitle, untitled: String, copySuffix: String, copy: String) {
        #expect(title.copyName(untitled: untitled, copySuffix: copySuffix) == copy)
    }

    @Test("two copies of one CV are numbered, as any titles that read alike")
    func copiesAreNumbered() {
        let copy = CVTitle.person("Lena Hartmann").copyName(untitled: "Ohne Titel", copySuffix: "(Kopie)")
        #expect(labels([("1", .name(copy)), ("2", .name(copy)), ("3", .person("Lena Hartmann"))], untitled: "Ohne Titel")
                == ["1": copy, "2": "\(copy) (2)", "3": "Lena Hartmann"])
    }

    // MARK: - The labels of a list

    /// How the app numbers a title, in each of its languages: "%1$@ (%2$lld)"
    private static let numbered: @Sendable (String, Int) -> String = { "\($0) (\($1))" }

    private func labels(_ titles: [(id: String, title: CVTitle)], untitled: String = "Untitled CV") -> [String: String] {
        CVTitle.labels(for: titles, untitled: untitled, numbered: Self.numbered)
    }

    @Test("CVs whose titles read alike are numbered from the second, in the order of their identities")
    func numbers() {
        let titles: [(id: String, title: CVTitle)] = [
            ("c", .untitled), ("a", .untitled), ("b", .name("Backend")), ("e", .role("backend")), ("d", .untitled),
            ("f", .name("Frontend")), ("h", .person("Lena Hartmann")), ("g", .person("Lena Hartmann")),
        ]
        #expect(labels(titles) == [
            "a": "Untitled CV", "c": "Untitled CV (2)", "d": "Untitled CV (3)", "b": "Backend", "e": "backend (2)",
            "f": "Frontend", "g": "Lena Hartmann", "h": "Lena Hartmann (2)",
        ])
    }

    @Test("a number never gives a label the list already shows: it skips to the next free one", arguments: [
        "Backend", "Infermiera", "Pflegefachkraft", "Développeuse", "Enfermero", "Engenheiro de software",
    ])
    func numberSkipsTakenLabels(title: String) {
        #expect(labels([("a", .name(title)), ("b", .role(title)), ("c", .name("\(title) (2)"))])
                == ["a": title, "b": "\(title) (3)", "c": "\(title) (2)"])
        #expect(labels([("a", .name(title)), ("b", .name(title)), ("c", .person(title)), ("d", .name("\(title.uppercased()) (3)"))])
                == ["a": title, "b": "\(title) (2)", "c": "\(title) (4)", "d": "\(title.uppercased()) (3)"])
    }

    @Test("an untitled CV and one named with the app's words for an untitled CV are told apart", arguments: [
        "Untitled CV", "CV senza titolo", "Ohne Titel", "CV sans titre", "CV sin título", "Currículo sem título",
    ])
    func untitledAndNamedLikeIt(untitled: String) {
        let titles: [(id: String, title: CVTitle)] = [("a", .untitled), ("b", .name(untitled)), ("c", .name(untitled.uppercased()))]
        #expect(labels(titles, untitled: untitled) == ["a": untitled, "b": "\(untitled) (2)", "c": "\(untitled.uppercased()) (3)"])
    }

    @Test("titles that differ only in case, accents or spaces around them read alike",
          arguments: [(CVTitle.name("Enfermera"), CVTitle.role("enfermera")), (.name("Développeur"), .name("developpeur")),
                      (.role("Pflegefachkraft"), .name(" PFLEGEFACHKRAFT")), (.person("José García"), .name("jose garcia"))])
    func alike(first: CVTitle, second: CVTitle) {
        #expect(labels([("1", first), ("2", second)])["2"] == "\(second.text(untitled: "Untitled CV")) (2)")
    }

    @Test("a single CV, and CVs with different titles, keep their titles")
    func noNumbers() {
        #expect(labels([("1", .untitled)]) == ["1": "Untitled CV"])
        #expect(labels([("1", .name("Analyst")), ("2", .role("Analista")), ("3", .person("Ana Sousa")), ("4", .untitled)])
                == ["1": "Analyst", "2": "Analista", "3": "Ana Sousa", "4": "Untitled CV"])
    }
}
