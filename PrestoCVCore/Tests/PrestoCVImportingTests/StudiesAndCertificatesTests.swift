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

    // MARK: Other joined headings

    @Test("A heading that joins two other kinds is still additional information", arguments: [
        "Skills and Languages", "Competenze e lingue", "Projects & Volunteering",
    ])
    func otherPairsStayAdditional(heading: String) throws {
        let match = try #require(SectionVocabulary.kind(ofHeading: heading))
        #expect(match.kind == .additional)
    }
}
