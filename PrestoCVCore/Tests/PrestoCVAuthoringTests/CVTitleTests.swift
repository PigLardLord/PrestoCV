import Testing
import PrestoCVDomain

@Suite("What a CV is called")
struct CVTitleTests {
    @Test("a CV is called by its own name first, then by the role it is for, and is untitled without either",
          arguments: [("iOS roles", "Engineer", CVTitle.name("iOS roles")), ("  ", "Infermiera ", .role("Infermiera")),
                      ("", "", .untitled), (" \n", "\t", .untitled), ("Pflege – Berlin", "", .name("Pflege – Berlin"))])
    func title(name: String, role: String, title: CVTitle) {
        #expect(CVTitle(name: name, role: role) == title)
    }

    @Test("CVs whose titles read alike are numbered from the second, in the order of their identities")
    func numbers() {
        let titles: [(id: String, title: CVTitle)] = [
            ("c", .untitled), ("a", .untitled), ("b", .name("Backend")), ("e", .role("backend")), ("d", .untitled), ("f", .name("Frontend")),
        ]
        #expect(CVTitle.numbers(for: titles) == ["c": 2, "d": 3, "e": 2])
    }

    @Test("titles that differ only in case, accents or spaces around them read alike",
          arguments: [(CVTitle.name("Enfermera"), CVTitle.role("enfermera")), (.name("Développeur"), .name("developpeur")),
                      (.role("Pflegefachkraft"), .name(" PFLEGEFACHKRAFT"))])
    func alike(first: CVTitle, second: CVTitle) {
        #expect(CVTitle.numbers(for: [("1", first), ("2", second)]) == ["2": 2])
    }

    @Test("a single CV, and CVs with different titles, have no number")
    func noNumbers() {
        #expect(CVTitle.numbers(for: [("1", .untitled)]).isEmpty)
        #expect(CVTitle.numbers(for: [("1", .name("Analyst")), ("2", .role("Analista")), ("3", .untitled)]).isEmpty)
    }
}
