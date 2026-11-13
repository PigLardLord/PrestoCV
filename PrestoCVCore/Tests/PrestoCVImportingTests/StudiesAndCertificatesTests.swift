import Foundation
import Testing
import PrestoCVDomain
@testable import PrestoCVImporting

/// A heading that joins the studies and the certifications (#453): a short CV keeps both in one section, and each entry
/// is read by its own shape. Every value here is invented (the corpus README).
@Suite("Studies and certifications under one heading")
struct StudiesAndCertificatesTests {

    private func importText(_ text: String) throws -> ImportResult {
        try ImportCV(pdfReader: ScriptedPDFReader(), limits: .standard).importText(text)
    }

    private func ym(_ year: Int) -> YearMonth { YearMonth(year: year, month: nil) }

    private func cv(heading: String, body: String) -> String {
        """
        Tobias Renn
        tobias.renn@example.com

        \(heading)
        \(body)
        """
    }

    private let studyAndCertification = """
        BSc Computer Science — University of Leipzig
        2010 – 2014
        Certified Scrum Developer — Scrum Alliance, 2019
        """

    // MARK: A heading that joins the two kinds

    @Test("A heading that joins the studies and the certifications reads one study and one certification", arguments: [
        "STUDIES AND CERTIFICATES", "CERTIFICATES AND STUDIES", "Education & Certifications", "Education / Certifications",
    ])
    func joinedHeading(heading: String) throws {
        let found = try importText(cv(heading: heading, body: studyAndCertification))

        let study = try #require(found.cv.education.first, "\(found.unplaced.map(\.text))")
        #expect(found.cv.education.count == 1)
        #expect(study.degree?.value == "BSc Computer Science")
        #expect(study.school?.value == "University of Leipzig")
        #expect(study.period?.value == ImportedPeriod(start: ym(2010), end: .date(ym(2014))))
        let certification = try #require(found.cv.certifications.first)
        #expect(found.cv.certifications.count == 1)
        #expect(certification.name.value == "Certified Scrum Developer")
        #expect(certification.issuer?.value == "Scrum Alliance")
        #expect(certification.year?.value == 2019)
        #expect(found.unplaced.isEmpty, "\(found.unplaced.map(\.text))")
        #expect(Coverage.lost(found).isEmpty, "\(Coverage.describe(Coverage.lost(found)))")
    }

    @Test("The certification may come first: each entry keeps its own kind, in the order of the CV")
    func certificationFirst() throws {
        let body = """
            Certified Scrum Developer — Scrum Alliance, 2019
            BSc Computer Science — University of Leipzig
            2010 – 2014
            """
        let found = try importText(cv(heading: "CERTIFICATES AND STUDIES", body: body))

        #expect(found.cv.certifications.map(\.name.value) == ["Certified Scrum Developer"])
        #expect(found.cv.education.map { $0.degree?.value } == ["BSc Computer Science"])
        #expect(found.cv.education.map { $0.school?.value } == ["University of Leipzig"])
        #expect(found.unplaced.isEmpty, "\(found.unplaced.map(\.text))")
        #expect(Coverage.lost(found).isEmpty)
    }

    @Test("Under a joined heading, an issuer after a dash with a single year is a certification even without the word")
    func certificationByItsIssuerAndYear() throws {
        let body = """
            BSc Computer Science — University of Leipzig
            2010 – 2014
            Professional Scrum Master I — Scrum.org, 2020
            """
        let found = try importText(cv(heading: "STUDIES AND CERTIFICATES", body: body))

        #expect(found.cv.education.map { $0.degree?.value } == ["BSc Computer Science"])
        #expect(found.cv.certifications.map(\.name.value) == ["Professional Scrum Master I"])
        #expect(found.cv.certifications.map { $0.issuer?.value } == ["Scrum.org"])
        #expect(found.cv.certifications.map { $0.year?.value } == [2020])
        #expect(found.unplaced.isEmpty, "\(found.unplaced.map(\.text))")
    }

    @Test("The same in Italian: a degree and a certification under «Istruzione e certificazioni»")
    func italian() throws {
        let text = """
            Marta Rinaldi
            marta.rinaldi@example.com

            Istruzione e certificazioni
            Laurea in Informatica — Università di Padova
            2008 – 2011
            Certificazione ITIL Foundation — Axelos, 2018
            """
        let found = try importText(text)

        #expect(found.cv.education.map { $0.degree?.value } == ["Laurea in Informatica"])
        #expect(found.cv.education.map { $0.school?.value } == ["Università di Padova"])
        #expect(found.cv.certifications.map(\.name.value) == ["Certificazione ITIL Foundation"])
        #expect(found.cv.certifications.map { $0.issuer?.value } == ["Axelos"])
        #expect(found.cv.certifications.map { $0.year?.value } == [2018])
        #expect(found.unplaced.isEmpty, "\(found.unplaced.map(\.text))")
        #expect(Coverage.lost(found).isEmpty)
    }

    @Test("A study with a single year and a school stays a study under a joined heading")
    func studyWithASingleYear() throws {
        let body = """
            Diploma di maturità scientifica — Liceo Scientifico Galilei, 2006
            Certificazione ITIL Foundation — Axelos, 2018
            """
        let found = try importText(cv(heading: "Istruzione e certificazioni", body: body))

        #expect(found.cv.education.map { $0.degree?.value } == ["Diploma di maturità scientifica"])
        #expect(found.cv.certifications.map(\.name.value) == ["Certificazione ITIL Foundation"])
        #expect(found.unplaced.isEmpty, "\(found.unplaced.map(\.text))")
    }

    @Test("A name line over a line of a school and a year is a study at that school, whatever the name says", arguments: [
        """
        Certified Food Safety Handler
        Hamburg Hospitality Institute, 2022
        Customer Service Training
        Leipzig Vocational Institute, 2021
        """,
        """
        Certification en Hygiène Alimentaire
        Institut Hôtelier de Lucca, 2022
        Formation en Accueil Client
        École Hôtelière de Hamburg, 2021
        """,
    ])
    func nameOverASchoolLine(body: String) throws {
        let lines = body.split(separator: "\n").map(String.init)
        let found = try importText(cv(heading: "Education & Certifications", body: body))

        #expect(found.cv.education.map { $0.degree?.value } == [lines[0], lines[2]])
        #expect(found.cv.education.map { $0.school?.value } == [lines[1], lines[3]].map { String($0.prefix { $0 != "," }) })
        #expect(found.cv.education.map { $0.period?.value } == [
            ImportedPeriod(start: ym(2022), end: nil), ImportedPeriod(start: ym(2021), end: nil),
        ])
        #expect(found.cv.certifications.isEmpty)
        #expect(found.unplaced.isEmpty, "\(found.unplaced.map(\.text))")
        #expect(Coverage.lost(found).isEmpty, "\(Coverage.describe(Coverage.lost(found)))")
    }

    @Test("Under a joined heading, lines that show neither kind stay in the text not imported, as before")
    func noEvidenceStaysVisible() throws {
        let body = """
            Advanced Negotiation
            Public Speaking
            """
        let found = try importText(cv(heading: "Education & Certifications", body: body))

        #expect(found.cv.education.isEmpty)
        #expect(found.cv.certifications.isEmpty)
        #expect(found.unplaced.map(\.text).joined(separator: "\n").contains("Advanced Negotiation"))
        #expect(found.unplaced.map(\.text).joined(separator: "\n").contains("Public Speaking"))
        #expect(Coverage.lost(found).isEmpty, "\(Coverage.describe(Coverage.lost(found)))")
    }

    @Test("A line of neither kind after a certification is a certification of its own, not a part of the study below it", arguments: [
        "BSc Computer Science — University of Leipzig", "MSc Computer Science — University of Leipzig",
        "LLB Law — University of Leipzig", "BEng Mechanical Engineering — University of Leipzig",
    ])
    func neitherAfterACertification(study: String) throws {
        let body = """
            Certified Scrum Developer — Scrum Alliance, 2019
            Advanced Negotiation
            \(study)
            2010 – 2014
            """
        let found = try importText(cv(heading: "Education & Certifications", body: body))

        let degree = String(study.prefix { $0 != "—" }).trimmingCharacters(in: .whitespaces)
        #expect(found.cv.education.map { $0.degree?.value } == [degree])
        #expect(found.cv.education.map { $0.school?.value } == ["University of Leipzig"])
        #expect(found.cv.education.map { $0.location?.value } == [nil])
        #expect(found.cv.certifications.map(\.name.value) == ["Certified Scrum Developer", "Advanced Negotiation"])
        #expect(found.unplaced.isEmpty, "\(found.unplaced.map(\.text))")
        #expect(Coverage.lost(found).isEmpty, "\(Coverage.describe(Coverage.lost(found)))")
    }

    // MARK: A first word that is not always a degree

    @Test("A licence to practise is a certification under a joined heading, not a second study")
    func licenceToPractise() throws {
        let body = """
            MBBS Medicine — University of Leipzig
            2009 – 2015
            Licence to Practise — General Medical Council, 2015
            """
        let found = try importText(cv(heading: "Education & Certifications", body: body))

        #expect(found.cv.education.map { $0.degree?.value } == ["MBBS Medicine"])
        #expect(found.cv.certifications.map(\.name.value) == ["Licence to Practise"])
        #expect(found.cv.certifications.map { $0.issuer?.value } == ["General Medical Council"])
        #expect(found.cv.certifications.map { $0.year?.value } == [2015])
        #expect(found.unplaced.isEmpty, "\(found.unplaced.map(\.text))")
        #expect(Coverage.lost(found).isEmpty, "\(Coverage.describe(Coverage.lost(found)))")
    }

    @Test("A French licence stays a study after a certification, by the word that follows it", arguments: [
        "Licence en Droit", "Licence professionnelle Logistique", "Licence d'Économie", "Licence ès Lettres",
    ])
    func frenchLicence(degree: String) throws {
        let body = """
            Certified Scrum Developer — Scrum Alliance, 2019
            \(degree), 2011
            """
        let found = try importText(cv(heading: "Education & Certifications", body: body))

        #expect(found.cv.education.map { $0.degree?.value } == [degree])
        #expect(found.cv.certifications.map(\.name.value) == ["Certified Scrum Developer"])
        #expect(found.unplaced.isEmpty, "\(found.unplaced.map(\.text))")
        #expect(Coverage.lost(found).isEmpty, "\(Coverage.describe(Coverage.lost(found)))")
    }

    @Test("A course on large language models is a certification by its issuer and year, not a master of laws")
    func languageModelCourse() throws {
        let body = """
            BSc Computer Science — University of Leipzig
            2010 – 2014
            LLM Fine-Tuning — Northwind Labs, 2024
            """
        let found = try importText(cv(heading: "Education & Certifications", body: body))

        #expect(found.cv.education.map { $0.degree?.value } == ["BSc Computer Science"])
        #expect(found.cv.certifications.map(\.name.value) == ["LLM Fine-Tuning"])
        #expect(found.cv.certifications.map { $0.issuer?.value } == ["Northwind Labs"])
        #expect(found.cv.certifications.map { $0.year?.value } == [2024])
        #expect(found.unplaced.isEmpty, "\(found.unplaced.map(\.text))")
    }

    @Test("A certification whose first word is also a degree's is a certification by its word, with no school", arguments: [
        "LLM Applications Certification — Northwind Labs, 2024", "Master Certified Coach — Kestrel Coaching Federation, 2020",
    ], ["Education & Certifications", "EDUCATION & TRAINING"])
    func certificationOpeningLikeADegree(line: String, heading: String) throws {
        let body = """
            BSc Computer Science — University of Leipzig
            2010 – 2014
            \(line)
            """
        let found = try importText(cv(heading: heading, body: body))

        let name = String(line.prefix { $0 != "—" }).trimmingCharacters(in: .whitespaces)
        #expect(found.cv.education.map { $0.degree?.value } == ["BSc Computer Science"])
        #expect(found.cv.certifications.map(\.name.value) == [name])
        #expect(found.cv.certifications.count == 1)
        #expect(found.unplaced.isEmpty, "\(found.unplaced.map(\.text))")
        #expect(Coverage.lost(found).isEmpty, "\(Coverage.describe(Coverage.lost(found)))")
    }

    // MARK: The name decides the kind

    /// A line of a certification, with the name, issuer and year the certification reader must find in it.
    struct CertificationLine: Sendable, CustomTestStringConvertible {
        let line: String
        let name: String
        let issuer: String
        let year: Int
        var testDescription: String { line }
    }

    static let certificationsAtASchoolOrOverAPeriod = [
        CertificationLine(
            line: "Certified Cloud Practitioner — University of Northbridge, 2022", name: "Certified Cloud Practitioner",
            issuer: "University of Northbridge", year: 2022
        ),
        CertificationLine(
            line: "Certified Cloud Practitioner - University of Northbridge - 2022", name: "Certified Cloud Practitioner",
            issuer: "University of Northbridge", year: 2022
        ),
        CertificationLine(
            line: "Certified Cloud Practitioner, University of Northbridge, 2022", name: "Certified Cloud Practitioner",
            issuer: "University of Northbridge", year: 2022
        ),
        CertificationLine(
            line: "Certified Safety Inspector — Meridian Board, 2021–2024", name: "Certified Safety Inspector", issuer: "Meridian Board",
            year: 2024
        ),
        CertificationLine(
            line: "Certified Safety Inspector, Meridian Board, 2021 - 2024", name: "Certified Safety Inspector", issuer: "Meridian Board",
            year: 2024
        ),
    ]

    @Test(
        "A certification word in the name decides the kind: a school as the issuer or a period of validity does not make a study",
        arguments: StudiesAndCertificatesTests.certificationsAtASchoolOrOverAPeriod, ["Education & Certifications", "EDUCATION & TRAINING"]
    )
    func certificationNameDecidesTheKind(certification: CertificationLine, heading: String) throws {
        let body = """
            BSc Computer Science — University of Leipzig
            2010 – 2014
            \(certification.line)
            """
        let found = try importText(cv(heading: heading, body: body))

        #expect(found.cv.education.map { $0.degree?.value } == ["BSc Computer Science"])
        #expect(found.cv.certifications.map(\.name.value) == [certification.name])
        #expect(found.cv.certifications.map { $0.issuer?.value } == [certification.issuer])
        #expect(found.cv.certifications.map { $0.year?.value } == [certification.year])
        #expect(found.unplaced.isEmpty, "\(found.unplaced.map(\.text))")
        #expect(Coverage.lost(found).isEmpty, "\(Coverage.describe(Coverage.lost(found)))")
    }

    @Test("A certificate degree at a school over two years stays a study on one line under a joined heading")
    func certificateDegreeOnOneLine() throws {
        let body = "Graduate Certificate in Data Science — University of Leipzig, 2015 – 2016"
        let found = try importText(cv(heading: "Education & Certifications", body: body))

        #expect(found.cv.education.map { $0.degree?.value } == ["Graduate Certificate in Data Science"])
        #expect(found.cv.education.map { $0.school?.value } == ["University of Leipzig"])
        #expect(found.cv.certifications.isEmpty)
        #expect(found.unplaced.isEmpty, "\(found.unplaced.map(\.text))")
        #expect(Coverage.lost(found).isEmpty, "\(Coverage.describe(Coverage.lost(found)))")
    }

    /// Read as a certification, the school's line would be a certification of its own, named after the school: the name,
    /// the school and the year stay one entry instead, flagged for the person to check.
    @Test("A certification's name alone over a line of a school and a year is a study at that school under a joined heading")
    func certificationNameOverASchoolLine() throws {
        let body = """
            BSc Computer Science — University of Leipzig
            2010 – 2014
            Certified Cloud Practitioner
            University of Northbridge, 2022
            """
        let found = try importText(cv(heading: "Education & Certifications", body: body))

        #expect(found.cv.education.map { $0.degree?.value } == ["BSc Computer Science", "Certified Cloud Practitioner"])
        #expect(found.cv.education.map { $0.school?.value } == ["University of Leipzig", "University of Northbridge"])
        #expect(found.cv.education.last?.period?.value == ImportedPeriod(start: ym(2022), end: nil))
        #expect(found.cv.certifications.isEmpty)
        #expect(found.reviewList.map(\.field) == [.education(1)], "the person checks the name and the school")
        #expect(found.unplaced.isEmpty, "\(found.unplaced.map(\.text))")
        #expect(Coverage.lost(found).isEmpty, "\(Coverage.describe(Coverage.lost(found)))")
    }

    // MARK: Conflicting evidence

    /// A line whose name has a certification word, with the certification it must give, or nil when the line holds two or
    /// more pieces of evidence of a study (a degree in its name, a school, a period with an end) and stays in the text not
    /// imported.
    struct ConflictLine: Sendable, CustomTestStringConvertible {
        let line: String
        let certification: CertificationLine?
        var testDescription: String { line }

        static func unplaced(_ line: String) -> ConflictLine { ConflictLine(line: line, certification: nil) }

        static func certification(_ line: String, name: String, issuer: String, year: Int) -> ConflictLine {
            ConflictLine(line: line, certification: CertificationLine(line: line, name: name, issuer: issuer, year: year))
        }
    }

    static let conflictingEvidence = [
        ConflictLine.unplaced("Certified Nursing Assistant Diploma — University of Northbridge, 2020–2022"),
        ConflictLine.unplaced("Certified Nursing Assistant Diploma - University of Northbridge - 2020 - 2022"),
        ConflictLine.unplaced("Certified Nursing Assistant Diploma, University of Northbridge, 2020–2022"),
        ConflictLine.unplaced("Certified Cloud Practitioner — University of Northbridge, 2022–2025"),
        ConflictLine.unplaced("Certified Diploma in Nursing — Meridian Board, 2018–2020"),
        ConflictLine.unplaced("Master Certified Coach — Kestrel Coaching Federation, 2020–2023"),
        ConflictLine.unplaced("Master Certified Coach — University of Northbridge, 2020"),
        ConflictLine.unplaced("Certification Programme in Data Analysis — University of Leipzig, 2015 – 2017"),
        ConflictLine.unplaced("Laurea in Certificazione dei Bilanci — Università di Lucca, 2010–2014"),
        ConflictLine.certification(
            "Certified Diploma in Nursing — Meridian Board, 2019", name: "Certified Diploma in Nursing", issuer: "Meridian Board", year: 2019
        ),
        ConflictLine.certification(
            "Certified Scrum Master — Scrum Alliance, 2019", name: "Certified Scrum Master", issuer: "Scrum Alliance", year: 2019
        ),
        ConflictLine.certification(
            "Master Certified Coach — Kestrel Coaching Federation, 2020", name: "Master Certified Coach",
            issuer: "Kestrel Coaching Federation", year: 2020
        ),
    ]

    @Test(
        "A certification word in the name against two pieces of evidence of a study leaves the line in the text not imported",
        arguments: StudiesAndCertificatesTests.conflictingEvidence, ["Education & Certifications", "EDUCATION & TRAINING"]
    )
    func conflictingEvidenceStaysVisible(conflict: ConflictLine, heading: String) throws {
        let body = """
            BSc Computer Science — University of Leipzig
            2010 – 2014
            \(conflict.line)
            """
        let found = try importText(cv(heading: heading, body: body))

        #expect(found.cv.education.map { $0.degree?.value } == ["BSc Computer Science"])
        if let certification = conflict.certification {
            #expect(found.cv.certifications.map(\.name.value) == [certification.name])
            #expect(found.cv.certifications.map { $0.issuer?.value } == [certification.issuer])
            #expect(found.cv.certifications.map { $0.year?.value } == [certification.year])
            #expect(found.unplaced.isEmpty, "\(found.unplaced.map(\.text))")
        } else {
            #expect(found.cv.certifications.isEmpty, "\(found.cv.certifications.map(\.name.value))")
            #expect(found.unplaced.map(\.text) == [conflict.line])
            let section: SectionKind = heading == "EDUCATION & TRAINING" ? .education : .additional
            #expect(found.unplaced.map(\.section) == [section], "the text not imported stays under the section it was in")
            #expect(found.unplaced.map(\.heading) == [heading])
        }
        #expect(Coverage.lost(found).isEmpty, "\(Coverage.describe(Coverage.lost(found)))")
    }

    /// The line above a school's line is the name of a study there only when it shows nothing else: a line left in doubt
    /// keeps its doubt, and the school's line is a study of its own.
    @Test("A line left in doubt over a line of a school and a year stays in the text not imported")
    func lineInDoubtOverASchoolLine() throws {
        let body = """
            BSc Computer Science — University of Leipzig
            2010 – 2014
            Master Certified Coach, University of Northbridge
            Hamburg Hospitality Institute, 2022
            """
        let found = try importText(cv(heading: "Education & Certifications", body: body))

        #expect(found.unplaced.map(\.text) == ["Master Certified Coach, University of Northbridge"])
        #expect(found.cv.education.map { $0.degree?.value } == ["BSc Computer Science", nil])
        #expect(found.cv.education.map { $0.school?.value } == ["University of Leipzig", "Hamburg Hospitality Institute"])
        #expect(found.cv.certifications.isEmpty)
        #expect(Coverage.lost(found).isEmpty, "\(Coverage.describe(Coverage.lost(found)))")
    }

    // MARK: A heading of one kind

    @Test("Under an education heading, an entry with a certification word is a certification, not a second study")
    func certificationUnderAnEducationHeading() throws {
        let found = try importText(cv(heading: "EDUCATION & TRAINING", body: studyAndCertification))

        #expect(found.cv.education.map { $0.degree?.value } == ["BSc Computer Science"])
        #expect(found.cv.education.map { $0.school?.value } == ["University of Leipzig"])
        #expect(found.cv.certifications.map(\.name.value) == ["Certified Scrum Developer"])
        #expect(found.cv.certifications.map { $0.issuer?.value } == ["Scrum Alliance"])
        #expect(found.cv.certifications.map { $0.year?.value } == [2019])
        #expect(found.unplaced.isEmpty, "\(found.unplaced.map(\.text))")
        #expect(Coverage.lost(found).isEmpty)
    }

    @Test("A study whose degree is a certificate, at a school and over two years, stays a study under an education heading")
    func certificateDegreeStaysAStudy() throws {
        let body = """
            Graduate Certificate in Data Science — University of Leipzig
            2015 – 2016
            BSc Computer Science — University of Leipzig
            2010 – 2014
            """
        let found = try importText(cv(heading: "Education", body: body))

        #expect(found.cv.education.map { $0.degree?.value } == ["Graduate Certificate in Data Science", "BSc Computer Science"])
        #expect(found.cv.certifications.isEmpty)
        #expect(found.unplaced.isEmpty, "\(found.unplaced.map(\.text))")
    }

    @Test("Under a heading of one kind only a certification word moves an entry: an issuer and a year alone stay a study")
    func oneKindHeadingNeedsTheWord() throws {
        let body = """
            BSc Computer Science — University of Leipzig
            2010 – 2014
            Fachinformatiker Anwendungsentwicklung — IHK Leipzig, 2009
            """
        let found = try importText(cv(heading: "Education", body: body))

        #expect(found.cv.education.map { $0.degree?.value } == ["BSc Computer Science", "Fachinformatiker Anwendungsentwicklung"])
        #expect(found.cv.certifications.isEmpty)
    }

    // MARK: A degree named in the line

    /// A line with no word of a certification whose name holds a degree away from its first word, with the degree it must
    /// give.
    struct DegreeLine: Sendable, CustomTestStringConvertible {
        let line: String
        let degree: String
        var testDescription: String { line }
    }

    static let degreesNamedInTheLine = [
        DegreeLine(line: "Postgraduate Diploma in Robotics — NIT, 2020", degree: "Postgraduate Diploma in Robotics"),
        DegreeLine(line: "Postgraduate Diploma in Robotics - NIT - 2020", degree: "Postgraduate Diploma in Robotics"),
        DegreeLine(line: "Postgraduate Diploma in Robotics, NIT, 2020", degree: "Postgraduate Diploma in Robotics"),
        DegreeLine(line: "Executive Master of Business Administration — NIT, 2020", degree: "Executive Master of Business Administration"),
        DegreeLine(line: "Associate Degree in Nursing — NIT, 2016", degree: "Associate Degree in Nursing"),
        DegreeLine(line: "Second Degree in Nursing — NIT, 2018", degree: "Second Degree in Nursing"),
        DegreeLine(line: "Honours Degree — NIT, 2015", degree: "Honours Degree"),
    ]

    /// An issuer and a single year are what a study shows too: the degree in the name says what the line is, alone under
    /// the heading, after a study and after a certification.
    @Test(
        "A degree named in a line with an issuer and a single year is a study, not a certification",
        arguments: StudiesAndCertificatesTests.degreesNamedInTheLine, ["Education & Certifications", "EDUCATION & TRAINING"]
    )
    func degreeNamedInTheLine(degree: DegreeLine, heading: String) throws {
        let study = """
            BSc Computer Science — University of Leipzig
            2010 – 2014
            """
        let certification = "Certified Scrum Developer — Scrum Alliance, 2019"
        let bodies: [(before: [String], studies: [String], certifications: [String])] = [
            ([], [], []),
            ([study], ["BSc Computer Science"], []),
            ([study, certification], ["BSc Computer Science"], ["Certified Scrum Developer"]),
        ]
        for body in bodies {
            let found = try importText(cv(heading: heading, body: (body.before + [degree.line]).joined(separator: "\n")))
            let studies: [String?] = body.studies + [degree.degree]

            #expect(found.cv.education.map { $0.degree?.value } == studies)
            #expect(found.cv.certifications.map(\.name.value) == body.certifications)
            #expect(found.unplaced.isEmpty, "\(found.unplaced.map(\.text))")
            #expect(Coverage.lost(found).isEmpty, "\(Coverage.describe(Coverage.lost(found)))")
        }
    }

    /// A line under a heading that joins the two kinds, with "Degree" as a grade or an angle, and the name it must give as a
    /// certification.
    static let gradesNamedDegree = [
        DegreeLine(
            line: "360 Degree Feedback Practitioner — Kestrel Coaching Federation, 2021", degree: "360 Degree Feedback Practitioner"
        ),
        DegreeLine(line: "2nd Degree Black Belt — Hamburg Rowing Club, 2019", degree: "2nd Degree Black Belt"),
        DegreeLine(
            line: "First Degree Reiki Practitioner — Kestrel Coaching Federation, 2018", degree: "First Degree Reiki Practitioner"
        ),
        DegreeLine(
            line: "Certified 2nd Degree Reiki Practitioner — University of Northbridge, 2020",
            degree: "Certified 2nd Degree Reiki Practitioner"
        ),
    ]

    /// "Degree" after a number or an ordinal names no study: under a heading that joins the two kinds, the issuer and the
    /// year make the line a certification, alone, after a study and after a certification. With a word of a certification
    /// and a school as its issuer, the grade is no second piece of evidence of a study (rule 0).
    @Test(
        "Degree after a number or an ordinal is a grade, and the line stays a certification",
        arguments: StudiesAndCertificatesTests.gradesNamedDegree
    )
    func gradeNamedDegree(grade: DegreeLine) throws {
        let study = """
            BSc Computer Science — University of Leipzig
            2010 – 2014
            """
        let certification = "Certified Scrum Developer — Scrum Alliance, 2019"
        let bodies: [(before: [String], studies: [String?], certifications: [String])] = [
            ([], [], []),
            ([study], ["BSc Computer Science"], []),
            ([study, certification], ["BSc Computer Science"], ["Certified Scrum Developer"]),
        ]
        for body in bodies {
            let text = (body.before + [grade.line]).joined(separator: "\n")
            let found = try importText(cv(heading: "Education & Certifications", body: text))

            #expect(found.cv.education.map { $0.degree?.value } == body.studies)
            #expect(found.cv.certifications.map(\.name.value) == body.certifications + [grade.degree])
            #expect(found.unplaced.isEmpty, "\(found.unplaced.map(\.text))")
            #expect(Coverage.lost(found).isEmpty, "\(Coverage.describe(Coverage.lost(found)))")
        }
    }

    // MARK: A certificate named after a degree

    /// A line that names a degree together with the noun of a certificate ("Certificate", "Certificato"), with an issuer
    /// that is not a school, a single year and no period with an end, and the degree it gives under a heading of studies:
    /// with each separator, with the year first, and with the noun in a note after the degree.
    static let certificatesNamedAfterADegree = [
        DegreeLine(line: "MBA Exam Preparation Certificate — Meridian Board, 2021", degree: "MBA Exam Preparation Certificate"),
        DegreeLine(
            line: "Master's Certificate in Project Management — Meridian Board, 2021",
            degree: "Master's Certificate in Project Management"
        ),
        DegreeLine(line: "Diploma Certificate — Meridian Board, 2020", degree: "Diploma Certificate"),
        DegreeLine(line: "Certificato di Laurea — Meridian Board, 2014", degree: "Certificato di Laurea"),
        DegreeLine(line: "MBA Exam Preparation Certificate, Meridian Board, 2021", degree: "MBA Exam Preparation Certificate"),
        DegreeLine(line: "MBA Exam Preparation Certificate - Meridian Board, 2021", degree: "MBA Exam Preparation Certificate"),
        DegreeLine(line: "2021 — MBA Exam Preparation Certificate — Meridian Board", degree: "MBA Exam Preparation Certificate"),
        DegreeLine(line: "MBA — Meridian Board, 2021 (exam preparation certificate)", degree: "MBA"),
    ]

    /// A certificate is what a course and a study both give, so a degree named beside it does not tell the kind: under a
    /// heading that joins the two kinds the line stays in the text not imported, alone, after a study and after a
    /// certification, rather than move silently to Education or to Certifications.
    @Test(
        "A degree named with the noun of a certificate, with no school and no period, stays in the text not imported under a joined heading",
        arguments: StudiesAndCertificatesTests.certificatesNamedAfterADegree
    )
    func certificateNamedAfterADegree(certificate: DegreeLine) throws {
        let heading = "Education & Certifications"
        for body in Self.bodies {
            let found = try importText(cv(heading: heading, body: (body.before + [certificate.line]).joined(separator: "\n")))

            #expect(found.cv.education.map { $0.degree?.value } == body.studies)
            #expect(found.cv.certifications.map(\.name.value) == body.certifications)
            #expect(found.unplaced.map(\.text) == [certificate.line])
            #expect(found.unplaced.map(\.section) == [.additional], "the text not imported stays under the section it was in")
            #expect(found.unplaced.map(\.heading) == [heading])
            #expect(Coverage.lost(found).isEmpty, "\(Coverage.describe(Coverage.lost(found)))")
        }
    }

    /// Under a heading of studies the heading says what the line is: the noun of a certificate is no word of a
    /// certification, and the degree makes the line a study, alone, after a study and after a certification.
    @Test(
        "A degree named with the noun of a certificate is a study under a heading of studies",
        arguments: StudiesAndCertificatesTests.certificatesNamedAfterADegree
    )
    func certificateNamedAfterADegreeUnderStudies(certificate: DegreeLine) throws {
        for body in Self.bodies {
            let found = try importText(
                cv(heading: "EDUCATION & TRAINING", body: (body.before + [certificate.line]).joined(separator: "\n"))
            )

            #expect(found.cv.education.map { $0.degree?.value } == body.studies + [certificate.degree])
            #expect(found.cv.education.last?.school?.value == "Meridian Board")
            #expect(found.cv.certifications.map(\.name.value) == body.certifications)
            #expect(found.unplaced.isEmpty, "\(found.unplaced.map(\.text))")
            #expect(Coverage.lost(found).isEmpty, "\(Coverage.describe(Coverage.lost(found)))")
        }
    }

    /// The lines of a degree named with the noun of a certificate at a school, with the study they must give.
    struct CertificateAtASchool: Sendable, CustomTestStringConvertible {
        let lines: String
        let degree: String
        var testDescription: String { lines }
    }

    static let certificatesAtASchool = [
        CertificateAtASchool(lines: "MBA Certificate\nUniversity of Northbridge, 2021", degree: "MBA Certificate"),
        CertificateAtASchool(
            lines: "MBA Exam Preparation Certificate — University of Northbridge, 2021", degree: "MBA Exam Preparation Certificate"
        ),
    ]

    /// A school settles the doubt, on the same line or on the line below (rule 3): the degree, the school and the year are
    /// one study.
    @Test(
        "A degree named with the noun of a certificate at a school is a study under a joined heading",
        arguments: StudiesAndCertificatesTests.certificatesAtASchool
    )
    func certificateNamedAfterADegreeAtASchool(certificate: CertificateAtASchool) throws {
        for body in Self.bodies {
            let text = (body.before + [certificate.lines]).joined(separator: "\n")
            let found = try importText(cv(heading: "Education & Certifications", body: text))

            #expect(found.cv.education.map { $0.degree?.value } == body.studies + [certificate.degree])
            #expect(found.cv.education.last?.school?.value == "University of Northbridge")
            #expect(found.cv.education.last?.period?.value == ImportedPeriod(start: ym(2021), end: nil))
            #expect(found.cv.certifications.map(\.name.value) == body.certifications)
            #expect(found.unplaced.isEmpty, "\(found.unplaced.map(\.text))")
            #expect(Coverage.lost(found).isEmpty, "\(Coverage.describe(Coverage.lost(found)))")
        }
    }

    /// The lines before the line under test: none, a study, a study and a certification; with what they give.
    static let bodies: [(before: [String], studies: [String?], certifications: [String])] = [
        ([], [], []),
        (["BSc Computer Science — University of Leipzig\n2010 – 2014"], ["BSc Computer Science"], []),
        (
            ["BSc Computer Science — University of Leipzig\n2010 – 2014", "Certified Scrum Developer — Scrum Alliance, 2019"],
            ["BSc Computer Science"], ["Certified Scrum Developer"]
        ),
    ]

    // MARK: Other joined headings

    @Test("A heading that joins two other kinds is still additional information", arguments: [
        "Skills and Languages", "Competenze e lingue", "Projects & Volunteering",
    ])
    func otherPairsStayAdditional(heading: String) throws {
        let match = try #require(SectionVocabulary.kind(ofHeading: heading))
        #expect(match.kind == .additional)
    }
}
