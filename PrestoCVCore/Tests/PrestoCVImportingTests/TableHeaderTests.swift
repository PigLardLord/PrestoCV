import Testing
@testable import PrestoCVImporting

/// A table whose first row names the columns, as chat assistants write experience and education (ADR 0027): the
/// columns are read by the header's words, and the header row and the separator row are markup, never data.
@Suite("Reading a table by its header row")
struct TableHeaderTests {

    private func importText(_ text: String) throws -> ImportResult {
        try ImportCV(pdfReader: ScriptedPDFReader(), limits: .standard).importText(text)
    }

    private func noLoss(_ result: ImportResult) {
        #expect(Coverage.lost(result).isEmpty, "lost \(Coverage.describe(Coverage.lost(result)))")
    }

    @Test("An English table: the header and the separator are markup, the columns are read by their names")
    func english() throws {
        let result = try importText("""
        Experience
        | Period | Employer | Role | Tasks |
        |---|---|---|---|
        | 2020 – 2022 | Northgate Academy | Teaching Assistant | Supported pupils |
        | 2018 – 2020 | Riverside School | Tutor | Ran workshops |
        """)
        let jobs = result.cv.experience
        #expect(jobs.map { $0.role?.value } == ["Teaching Assistant", "Tutor"])
        #expect(jobs.map { $0.employer?.value } == ["Northgate Academy", "Riverside School"])
        #expect(jobs.map { $0.location?.value } == [nil, nil])
        #expect(jobs.map { $0.details.map(\.value) } == [["Supported pupils"], ["Ran workshops"]])
        #expect(jobs.map { $0.period?.value.start.year } == [2020, 2018])
        #expect(jobs.allSatisfy { $0.check == nil })
        #expect(result.unplaced.isEmpty)
        noLoss(result)
    }

    @Test("A German table")
    func german() throws {
        let result = try importText("""
        Berufserfahrung
        | Zeitraum | Unternehmen | Rolle | Aufgaben |
        |---|---|---|---|
        | 2021 – 2023 | Beispiel Werke | Mechatroniker | Wartung von Anlagen |
        | 2018 – 2021 | Muster Technik | Monteur | Montage von Schaltschränken |
        """)
        let jobs = result.cv.experience
        #expect(jobs.map { $0.role?.value } == ["Mechatroniker", "Monteur"])
        #expect(jobs.map { $0.employer?.value } == ["Beispiel Werke", "Muster Technik"])
        #expect(jobs.map { $0.details.map(\.value) } == [["Wartung von Anlagen"], ["Montage von Schaltschränken"]])
        #expect(jobs.map { $0.period?.value.start.year } == [2021, 2018])
        #expect(result.unplaced.isEmpty)
        noLoss(result)
    }

    @Test("The same table with its columns in another order", arguments: [
        """
        Experience
        | Role | Period | Employer | Tasks |
        |---|---|---|---|
        | Teaching Assistant | 2020 – 2022 | Northgate Academy | Supported pupils |
        | Tutor | 2018 – 2020 | Riverside School | Ran workshops |
        """,
        """
        Experience
        | Tasks | Employer | Role | Period |
        |---|---|---|---|
        | Supported pupils | Northgate Academy | Teaching Assistant | 2020 – 2022 |
        | Ran workshops | Riverside School | Tutor | 2018 – 2020 |
        """,
    ])
    func otherOrder(_ text: String) throws {
        let result = try importText(text)
        let jobs = result.cv.experience
        #expect(jobs.map { $0.role?.value } == ["Teaching Assistant", "Tutor"])
        #expect(jobs.map { $0.employer?.value } == ["Northgate Academy", "Riverside School"])
        #expect(jobs.map { $0.details.map(\.value) } == [["Supported pupils"], ["Ran workshops"]])
        #expect(jobs.map { $0.period?.value.start.year } == [2020, 2018])
        noLoss(result)
    }

    @Test("An education table: school, degree and period")
    func education() throws {
        let result = try importText("""
        Education
        | School | Degree | Period |
        |---|---|---|
        | Example University | BSc Biology | 2014 – 2017 |
        | Sample College | Diploma in Nursing | 2011 – 2014 |
        """)
        let studies = result.cv.education
        #expect(studies.map { $0.school?.value } == ["Example University", "Sample College"])
        #expect(studies.map { $0.degree?.value } == ["BSc Biology", "Diploma in Nursing"])
        #expect(studies.map { $0.period?.value.start.year } == [2014, 2011])
        #expect(result.unplaced.isEmpty)
        noLoss(result)
    }

    @Test("A table whose header has no known word keeps today's reading, flags its entries and loses nothing")
    func unknownHeader() throws {
        let result = try importText("""
        Experience
        | Alpha | Beta | Gamma |
        |---|---|---|
        | Teaching Assistant | Northgate Academy | 2020 – 2022 |
        | Tutor | Riverside School | 2018 – 2020 |
        """)
        #expect(!result.cv.experience.isEmpty)
        #expect(result.cv.experience.allSatisfy { $0.check != nil })
        noLoss(result)
    }

    // MARK: Each table on its own

    @Test("Two tables with different column orders in one section are each read by their own header")
    func twoTables() throws {
        let result = try importText("""
        Experience
        | Role | Employer | Period |
        |---|---|---|
        | Teaching Assistant | Northgate Academy | 2020 – 2022 |
        | Tutor | Riverside School | 2018 – 2020 |

        | Employer | Role | Period |
        |---|---|---|
        | Harbor Systems | Planner | 2015 – 2017 |
        | Kestrel Cloud | Analyst | 2012 – 2015 |
        """)
        let jobs = result.cv.experience
        #expect(jobs.map { $0.role?.value } == ["Teaching Assistant", "Tutor", "Planner", "Analyst"])
        #expect(jobs.map { $0.employer?.value } == ["Northgate Academy", "Riverside School", "Harbor Systems", "Kestrel Cloud"])
        #expect(jobs.map { $0.period?.value.start.year } == [2020, 2018, 2015, 2012])
        #expect(jobs.allSatisfy { $0.check == nil })
        #expect(result.unplaced.isEmpty)
        noLoss(result)
    }

    @Test("Two tables with no blank line between them: the second header is markup, not an entry")
    func adjacentTables() throws {
        let result = try importText("""
        Experience
        | Role | Employer | Period |
        |---|---|---|
        | Teaching Assistant | Northgate Academy | 2020 – 2022 |
        | Employer | Role | Period |
        |---|---|---|
        | Harbor Systems | Planner | 2015 – 2017 |
        """)
        let jobs = result.cv.experience
        #expect(jobs.map { $0.role?.value } == ["Teaching Assistant", "Planner"])
        #expect(jobs.map { $0.employer?.value } == ["Northgate Academy", "Harbor Systems"])
        noLoss(result)
    }

    @Test("A row with fewer cells than the header is read by its dates, opens its own job and is flagged")
    func shortRow() throws {
        let result = try importText("""
        Experience
        | Period | Employer | Role | Tasks |
        |---|---|---|---|
        | 2020 – 2022 | Northgate Academy | Teaching Assistant | Supported pupils |
        | Tutor | Riverside School | 2018 – 2020 |
        | 2015 – 2017 | Harbor Systems | Planner | Drew up plans |
        """)
        let jobs = result.cv.experience
        #expect(jobs.count == 3)
        #expect(jobs.map { $0.period?.value.start.year } == [2020, 2018, 2015])
        #expect(jobs.map { $0.role?.value } == ["Teaching Assistant", "Tutor", "Planner"])
        #expect(jobs.map { $0.employer?.value } == ["Northgate Academy", "Riverside School", "Harbor Systems"])
        #expect(jobs.map { $0.details.map(\.value) } == [["Supported pupils"], [], ["Drew up plans"]])
        #expect(jobs.map { $0.check == nil } == [true, false, true])
        noLoss(result)
    }

    @Test("A row with more cells than the header keeps every cell and is flagged")
    func longRow() throws {
        let result = try importText("""
        Experience
        | Period | Employer | Role |
        |---|---|---|
        | 2020 – 2022 | Northgate Academy | Teaching Assistant |
        | 2018 – 2020 | Riverside School | Tutor | Part time |
        """)
        let jobs = result.cv.experience
        #expect(jobs.count == 2)
        #expect(jobs.map { $0.period?.value.start.year } == [2020, 2018])
        #expect(jobs.first?.check == nil)
        #expect(jobs.last?.check != nil)
        let last = jobs.last
        let kept = (last?.details.map(\.value) ?? []) + result.unplaced.map(\.text) + [last?.role?.value, last?.employer?.value, last?.location?.value].compactMap { $0 }
        #expect(kept.contains { $0.contains("Part time") })
        noLoss(result)
    }

    @Test("Plain dated entries before and after a table keep their own boundaries")
    func plainEntriesAround() throws {
        let result = try importText("""
        Experience
        Analyst at Kestrel Cloud, 2012 – 2015
        - Built reports

        | Period | Employer | Role |
        |---|---|---|
        | 2020 – 2022 | Northgate Academy | Teaching Assistant |

        Planner at Harbor Systems, 2015 – 2017
        - Drew up plans
        Tutor at Riverside School, 2018 – 2020
        - Ran workshops
        """)
        let jobs = result.cv.experience
        #expect(jobs.map { $0.role?.value } == ["Analyst", "Teaching Assistant", "Planner", "Tutor"])
        #expect(jobs.map { $0.employer?.value } == ["Kestrel Cloud", "Northgate Academy", "Harbor Systems", "Riverside School"])
        #expect(jobs.map { $0.period?.value.start.year } == [2012, 2020, 2015, 2018])
        #expect(jobs.map { $0.details.map(\.value) } == [["Built reports"], [], ["Drew up plans"], ["Ran workshops"]])
        #expect(jobs.allSatisfy { $0.check == nil })
        noLoss(result)
    }

    @Test("A plain dated entry right under a table, with no blank line, is not a row of it")
    func plainEntryUnderTable() throws {
        let result = try importText("""
        Experience
        | Period | Employer | Role |
        |---|---|---|
        | 2020 – 2022 | Northgate Academy | Teaching Assistant |
        Planner at Harbor Systems, 2015 – 2017
        - Drew up plans
        Tutor at Riverside School, 2018 – 2020
        - Ran workshops
        """)
        let jobs = result.cv.experience
        #expect(jobs.map { $0.role?.value } == ["Teaching Assistant", "Planner", "Tutor"])
        #expect(jobs.map { $0.details.map(\.value) } == [[], ["Drew up plans"], ["Ran workshops"]])
        noLoss(result)
    }

    @Test("A section with no table reads its entries by their dates")
    func noTable() throws {
        let result = try importText("""
        Experience
        Planner at Harbor Systems, 2015 – 2017
        - Drew up plans
        Tutor at Riverside School, 2018 – 2020
        - Ran workshops
        """)
        let jobs = result.cv.experience
        #expect(jobs.map { $0.role?.value } == ["Planner", "Tutor"])
        #expect(jobs.map { $0.details.map(\.value) } == [["Drew up plans"], ["Ran workshops"]])
        #expect(jobs.allSatisfy { $0.check == nil })
        noLoss(result)
    }

    @Test("A table whose header has no known word flags only its own rows, not the entries around it")
    func unknownHeaderAmongPlainEntries() throws {
        let result = try importText("""
        Experience
        Analyst at Kestrel Cloud, 2012 – 2015
        - Built reports

        | Alpha | Beta | Gamma |
        |---|---|---|
        | Teaching Assistant | Northgate Academy | 2020 – 2022 |
        """)
        let jobs = result.cv.experience
        #expect(jobs.count == 2)
        #expect(jobs.first?.check == nil)
        #expect(jobs.last?.check != nil)
        noLoss(result)
    }

    // MARK: Gaps and continuations (round 2)

    @Test("Blank lines between the data rows of one table keep the header's columns", arguments: [
        ("Experience", "| Employer | Role | Period |", "Chief Wizard", "Quillon Brae", "Growth Hacker", "Fennick Mere"),
        ("Berufserfahrung", "| Unternehmen | Rolle | Zeitraum |", "Hofnarr", "Quillon Brae", "Wolkenflüsterer", "Fennick Mere"),
        ("Esperienza", "| Datore di lavoro | Ruolo | Periodo |", "Stregone", "Quillon Brae", "Domatore di nuvole", "Fennick Mere"),
    ])
    func blankLinesBetweenRows(_ heading: String, _ header: String, _ roleA: String, _ employerA: String,
                               _ roleB: String, _ employerB: String) throws {
        let result = try importText("""
        \(heading)
        \(header)
        |---|---|---|
        | \(employerA) | \(roleA) | 2020 – 2022 |

        | \(employerB) | \(roleB) | 2018 – 2020 |

        | Ostrel Vane | Zorn | 2016 – 2018 |

        Planner at Harbor Systems, 2015 – 2017
        - Drew up plans

        | Role | Employer | Period |
        |---|---|---|
        | Dock Hand | Mirelle Bay | 2012 – 2015 |
        """)
        let jobs = result.cv.experience
        #expect(jobs.map { $0.role?.value } == [roleA, roleB, "Zorn", "Planner", "Dock Hand"])
        #expect(jobs.map { $0.employer?.value } == [employerA, employerB, "Ostrel Vane", "Harbor Systems", "Mirelle Bay"])
        #expect(jobs.map { $0.period?.value.start.year } == [2020, 2018, 2016, 2015, 2012])
        #expect(jobs.map { $0.details.map(\.value) } == [[], [], [], ["Drew up plans"], []])
        #expect(jobs.allSatisfy { $0.check == nil })
        #expect(result.unplaced.isEmpty)
        noLoss(result)
    }

    @Test("Bullets and an undated line under a table row stay that job's details", arguments: [
        ("Experience", "| Period | Employer | Role | Tasks |", "Teaching Assistant", "Northgate Academy",
         "Helped with reading", "Covered two classes"),
        ("Berufserfahrung", "| Zeitraum | Unternehmen | Rolle | Aufgaben |", "Mechatroniker", "Beispiel Werke",
         "Wartung der Pumpen", "Schichtleitung am Wochenende"),
        ("Esperienza", "| Periodo | Datore di lavoro | Ruolo | Mansioni |", "Tecnico", "Esempio Impianti",
         "Controllo delle pompe", "Turni nel fine settimana"),
    ])
    func continuation(_ heading: String, _ header: String, _ role: String, _ employer: String,
                      _ bullet: String, _ line: String) throws {
        let result = try importText("""
        \(heading)
        \(header)
        |---|---|---|---|
        | 2020 – 2022 | \(employer) | \(role) | Supported pupils |
        - \(bullet)
        - Ran a club
        \(line)
        | 2018 – 2020 | Riverside School | Tutor | Ran workshops |
        - Kept the registers
        Planner at Harbor Systems, 2015 – 2017
        - Drew up plans
        """)
        let jobs = result.cv.experience
        #expect(jobs.count == 3)
        #expect(jobs.map { $0.role?.value } == [role, "Tutor", "Planner"])
        #expect(jobs.map { $0.employer?.value } == [employer, "Riverside School", "Harbor Systems"])
        #expect(jobs.map { $0.details.map(\.value) } == [
            ["Supported pupils", bullet, "Ran a club", line],
            ["Ran workshops", "Kept the registers"],
            ["Drew up plans"],
        ])
        #expect(jobs.allSatisfy { $0.check == nil })
        #expect(result.unplaced.isEmpty)
        noLoss(result)
    }

    @Test("A single-cell row inside a table continues the job above and the table goes on")
    func singleCellRow() throws {
        let result = try importText("""
        Experience
        | Period | Employer | Role |
        |---|---|---|
        | 2020 – 2022 | Northgate Academy | Teaching Assistant |
        | Supported more pupils |
        | 2018 – 2020 | Riverside School | Tutor |
        """)
        let jobs = result.cv.experience
        #expect(jobs.count == 2)
        #expect(jobs.map { $0.role?.value } == ["Teaching Assistant", "Tutor"])
        #expect(jobs.map { $0.employer?.value } == ["Northgate Academy", "Riverside School"])
        #expect(jobs.map { $0.details.map(\.value) } == [["Supported more pupils"], []])
        #expect(jobs.allSatisfy { $0.check == nil })
        #expect(result.unplaced.isEmpty)
        noLoss(result)
    }

    @Test("A row the header does not explain keeps the bullets under it, flagged with it")
    func bulletUnderUnexplainedRow() throws {
        let result = try importText("""
        Experience
        | Alpha | Beta | Gamma |
        |---|---|---|
        | Teaching Assistant | Northgate Academy | 2020 – 2022 |
        - Supported pupils
        """)
        let jobs = result.cv.experience
        #expect(jobs.count == 1)
        #expect(jobs.first?.details.map(\.value) == ["Supported pupils"])
        #expect(jobs.first?.check != nil)
        #expect(result.unplaced.isEmpty)
        noLoss(result)
    }

    // MARK: Header words in each language

    @Test("The header words of each language", arguments: [
        ("Esperienza", "| Periodo | Datore di lavoro | Ruolo |", "Tecnico", "Esempio Impianti"),
        ("Experiencia", "| Fechas | Empleador | Puesto |", "Técnico", "Ejemplo Industrias"),
        ("Expérience", "| Dates | Employeur | Poste |", "Technicien", "Exemple Industrie"),
        ("Experiência", "| Datas | Empregador | Cargo |", "Técnico", "Exemplo Indústria"),
        ("Berufserfahrung", "| Zeitraum | Arbeitgeber | Rolle |", "Monteur", "Muster Technik"),
        ("Experience", "| Dates | Employer | Role |", "Technician", "Sample Works"),
    ])
    func languages(_ heading: String, _ header: String, _ role: String, _ employer: String) throws {
        let result = try importText("""
        \(heading)
        \(header)
        |---|---|---|
        | 2020 – 2022 | \(employer) | \(role) |
        """)
        let jobs = result.cv.experience
        #expect(jobs.map { $0.role?.value } == [role])
        #expect(jobs.map { $0.employer?.value } == [employer])
        #expect(jobs.map { $0.period?.value.start.year } == [2020])
        #expect(jobs.allSatisfy { $0.check == nil })
        noLoss(result)
    }
}
