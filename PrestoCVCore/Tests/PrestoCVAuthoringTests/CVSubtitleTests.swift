import Testing
import PrestoCVDomain

/// The line under the title of a CV in a row of the list, with the names and roles people write in the six languages
/// of the app.
@Suite("The line under the title of a CV")
struct CVSubtitleTests {
    @Test("a CV titled by its own name shows the name of its person and the role under it", arguments: [
        ("iOS roles", "John Smith", "Software Engineer", "John Smith · Software Engineer"),                  // en
        ("Candidatura ospedale", "Giulia Rossi", "Infermiera", "Giulia Rossi · Infermiera"),                  // it
        ("Pflege – Berlin", "Lena Hartmann", "Pflegefachkraft", "Lena Hartmann · Pflegefachkraft"),           // de
        ("Candidature Lyon", "Marie-Claire Dupont", "Développeuse", "Marie-Claire Dupont · Développeuse"),     // fr
        ("Hospital La Paz", " José García Pérez ", "Enfermero\n", "José García Pérez · Enfermero"),           // es
        ("Vaga Lisboa", "João da Silva", "Engenheiro de software", "João da Silva · Engenheiro de software"), // pt
    ])
    func namedCV(name: String, person: String, role: String, line: String) {
        #expect(CVSubtitle.text(name: name, person: person, role: role) == line)
    }

    @Test("an empty part leaves no separator behind", arguments: [
        ("Pflege – Berlin", "Lena Hartmann", "", "Lena Hartmann"),
        ("Candidatura ospedale", " ", "Infermiera", "Infermiera"),
    ])
    func emptyPart(name: String, person: String, role: String, line: String) {
        #expect(CVSubtitle.text(name: name, person: person, role: role) == line)
    }

    @Test("a CV titled by the name of its person shows only the role under it", arguments: [
        ("John Smith", "Software Engineer"), ("Giulia Rossi", "Infermiera"), ("Lena Hartmann", "Pflegefachkraft"),
        ("Marie-Claire Dupont", "Développeuse"), ("José García Pérez", "Enfermero"), ("João da Silva", "Engenheiro de software"),
    ])
    func titledByPerson(person: String, role: String) {
        #expect(CVSubtitle.text(name: "", person: person, role: role) == role)
        #expect(CVSubtitle.text(name: " ", person: person, role: "") == nil)
    }

    @Test("a CV titled by its role has no person to show under it, so the line is empty",
          arguments: ["Software Engineer", "Infermiera", "Pflegefachkraft", "Développeuse", "Enfermero", "Engenheiro de software"])
    func titledByRole(role: String) {
        #expect(CVSubtitle.text(name: "", person: "\t", role: role) == nil)
    }

    @Test("a CV with none of a name, a person and a role has no line under its title")
    func untitled() {
        #expect(CVSubtitle.text(name: "", person: "", role: "") == nil)
        #expect(CVSubtitle.text(name: " \n", person: "\t", role: "  ") == nil)
        #expect(CVSubtitle.text(name: "Pflege – Berlin", person: "", role: " ") == nil)
    }
}
