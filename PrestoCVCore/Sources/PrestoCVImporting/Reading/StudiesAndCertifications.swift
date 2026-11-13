/// Splits a section that may hold both studies and certifications into runs of one kind, each read by its own reader
/// (#453). A short CV keeps the two under one heading ("Education & Certifications", "Istruzione e certificazioni"), and
/// a heading of studies alone may still list a certification.
///
/// Each line is sorted by its own shape, in this order:
/// 0. A certification by its name: the name the certification reader finds on the line (its first part) holds a word of a
///    certification ("Certified", "Certificazione", "Zertifizierung"), no first word of a degree and no school, and the
///    line is more than that name (an issuer, a date) or stands under a heading that joins the two kinds. The rest of the
///    line is then the issuer and the year: "Certified Cloud Practitioner — University of Northbridge, 2022" is issued by a
///    school, and the period of "Certified Safety Inspector — Meridian Board, 2021–2024" is how long it is valid.
/// 1. A study: a period with an end ("2010 – 2014"), a school ("University of Leipzig", "Liceo Scientifico") or a first
///    word of a degree ("Laurea", "Diplom", "MBA"). A first word of a degree is not enough when the line names a
///    certification by its word and no school ("Master Certified Coach — Kestrel Coaching Federation, 2020"): the word
///    of the certification says what the line is. "Licence" is a degree only with a French word after it ("Licence en
///    Droit"); "Licence to Practise" is a permission to work.
/// 2. A certification, with no evidence of a study: under a heading that joins the two kinds, a word of a certification
///    ("Certified", "Certificazione", "Zertifizierung") or an issuer after a separator with a single date that is not a
///    period ("Professional Scrum Master I — Scrum.org, 2020"); under a heading of studies, the word together with an
///    issuer or a single date, so that a study that mentions a certification stays a study.
/// 3. A line whose only evidence of a study is its school ("Hamburg Hospitality Institute, 2022": no degree, no period
///    with an end) is the second line of an entry whose name is on the line just above it. When that line states no
///    issuer and no date of its own, it is the name of a study at that school ("Food Safety Handler" over "Hamburg
///    Hospitality Institute, 2022"), even when it names a certification by its word ("Certified Cloud Practitioner" over
///    "University of Northbridge, 2022"): the name, the school and the year stay one entry. Read as a certification, the
///    school's line would be a certification of its own, named after the school.
/// 4. Anything else goes with the line before it, a line already taken as noise too; the lines before the first line
///    with evidence go with that line. A section with no evidence at all keeps the kind of its heading, as before: read
///    as studies under a heading of studies, left in the text not imported under a heading that joins the two kinds.
enum StudiesAndCertifications {

    /// The kinds of a heading that joins the studies and the certifications.
    static let joinedKinds: Set<SectionKind> = [.education, .certifications]

    /// The section cut into runs of consecutive lines of one kind, in the order of the CV. Each run keeps the heading, the
    /// languages and the parts of the section; a section of studies whose lines are all studies comes back whole.
    static func runs(of section: Section, in document: SourceDocument, consumed: Set<Int>) -> [Section] {
        let joined = section.parts == joinedKinds
        let shapes = section.blocks.map { block -> Shape? in
            guard !consumed.contains(block.index) else { return nil }
            return shape(of: section.cells(of: block, in: document), joined: joined)
        }
        var evidence = shapes.map { $0?.kind }
        for index in shapes.indices.dropFirst() where shapes[index]?.schoolOnly == true && shapes[index - 1]?.bare == true {
            evidence[index - 1] = .education
        }
        guard let first = evidence.compactMap({ $0 }).first else { return [section] }
        var runs: [Section] = []
        var current = first
        for (block, found) in zip(section.blocks, evidence) {
            current = found ?? current
            if var last = runs.last, last.kind == current {
                last.blocks.append(block)
                runs[runs.count - 1] = last
            } else {
                var run = section
                run.kind = current
                run.blocks = [block]
                runs.append(run)
            }
        }
        return runs
    }

    /// What a line shows by its own words.
    private struct Shape {
        /// The kind the line shows, or nil when it shows none.
        var kind: SectionKind?
        /// The line is a study by its school alone: no degree, no period with an end.
        var schoolOnly = false
        /// The line states no issuer and no date.
        var bare = false
    }

    private static func shape(of cells: [Piece], joined: Bool) -> Shape? {
        guard !cells.isEmpty else { return nil }
        let text = cells.map(\.text).joined(separator: " — ")
        let dates = DateReader.periods(in: text)
        let hasIssuer = cells.flatMap { $0.split(by: Separators.strong) }.dropFirst().contains { part in
            part.text.contains(where: \.isLetter)
        }
        let bare = !hasIssuer && dates.isEmpty
        let (name, parts) = CertificationReader.nameAndParts(of: cells)
        if let name, EntryVocabulary.isCertification(name.text), !EntryVocabulary.opensAStudy(name.text),
            !EntryVocabulary.isSchool(name.text), joined || parts > 1 || !dates.isEmpty {
            return Shape(kind: .certifications, bare: bare)
        }
        if dates.contains(where: { $0.period.end != nil }) {
            return Shape(kind: .education, bare: bare)
        }
        let school = EntryVocabulary.isSchool(text)
        let hasWord = EntryVocabulary.isCertification(text)
        if EntryVocabulary.opensAStudy(text) && (school || !hasWord) {
            return Shape(kind: .education, bare: bare)
        }
        if school {
            return Shape(kind: .education, schoolOnly: true, bare: bare)
        }
        let hasSingleDate = dates.count == 1
        let certification = joined ? hasWord || (hasIssuer && hasSingleDate) : hasWord && (hasIssuer || hasSingleDate)
        return Shape(kind: certification ? .certifications : nil, bare: bare)
    }
}
