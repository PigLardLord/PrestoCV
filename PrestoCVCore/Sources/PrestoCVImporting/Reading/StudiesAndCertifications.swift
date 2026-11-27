/// Splits a section that may hold both studies and certifications into runs of one kind, each read by its own reader
/// (#453). A short CV keeps the two under one heading ("Education & Certifications", "Istruzione e certificazioni"), and
/// a heading of studies alone may still list a certification.
///
/// Each line is sorted by its own shape, in this order:
/// 0. A certification by its name: the name the certification reader finds on the line (its first part) holds a word of a
///    certification ("Certified", "Certificazione", "Zertifizierung") and no school, and the line is more than that name
///    (an issuer, a date) or stands under a heading that joins the two kinds. The line also counts the evidence of a study
///    it holds: a degree in the name ("Master", "Diploma", "Laurea", wherever it stands), a school anywhere on the line, a
///    period with an end. One piece is not enough to doubt the name: "Certified Cloud Practitioner — University of
///    Northbridge, 2022" is issued by a school, the period of "Certified Safety Inspector — Meridian Board, 2021–2024" is
///    how long it is valid, and "Master Certified Coach — Kestrel Coaching Federation, 2020" is a certification whose
///    first word is also a degree's. Two or more pieces against the word of a certification ("Certified Nursing
///    Assistant Diploma — University of Northbridge, 2020–2022") leave both readings open: the line is of no kind the
///    reading can tell, and stays in the text not imported, with the lines of no kind after it, rather than move silently
///    to one of the two.
/// 1. A study: a period with an end ("2010 – 2014"), a school ("University of Leipzig", "Liceo Scientifico"), a first
///    word of a degree ("Laurea", "Diplom", "MBA") or a degree named in the name, wherever it stands ("Postgraduate
///    Diploma in Robotics — NIT, 2020", "Executive Master of Business Administration"). "Degree" after a number or an
///    ordinal is a grade or an angle, not a study ("2nd Degree Black Belt", "360 Degree Feedback Practitioner"). A degree
///    is not enough when the line names a certification by its word and no school: the word of the certification says
///    what the line is.
///    "Licence" is a degree only with a French word after it ("Licence en Droit"); "Licence to Practise" is a permission
///    to work.
///    Under a heading that joins the two kinds, a degree with no school and no period with an end ("MBA Exam Preparation
///    Certificate — Meridian Board, 2021", "Bachelor of Arts, 2014", "Licence en Droit") is of no kind the reading can
///    tell: a course and a study both give a certificate, and both show an issuer and a year. The line stays in the text
///    not imported, where the person sees it, unless the line just below names a school and no degree and the line itself
///    names no issuer (rule 3). Under a heading of studies the heading says what it is: a study.
/// 2. A certification, with no evidence of a study: under a heading that joins the two kinds, a word of a certification
///    ("Certified", "Certificazione", "Zertifizierung") or an issuer after a separator with a single date that is not a
///    period ("Professional Scrum Master I — Scrum.org, 2020"); under a heading of studies, the word together with an
///    issuer or a single date, so that a study that mentions a certification stays a study. An issuer and a year alone
///    are what a study shows too, so they count only when nothing on the line names a degree (rule 1).
/// 3. A line whose only evidence of a study is its school ("Hamburg Hospitality Institute, 2022": no degree in any of
///    its parts, no period with an end) is the second line of an entry whose name is on the line just above it. When
///    that line states no issuer and no date of its own, it is the name of a study at that school ("Food Safety Handler"
///    over "Hamburg Hospitality Institute, 2022"), even when it names a certification by its word ("Certified Cloud
///    Practitioner" over "University of Northbridge, 2022"): the name, the school and the year stay one entry. Read as a
///    certification, the school's line would be a certification of its own, named after the school. A line above of no
///    kind the reading can tell (rule 0) stays so: the school's line below is a study of its own. A degree above with no
///    school, no period with an end and no issuer (rule 1) is a study at the school the line just below names, with that
///    line's dates, when that line names no degree: "MBA Certificate" over "University of Northbridge, 2019 – 2021",
///    "Bachelor of Arts, 2014" over "University of Leipzig". A degree over its dates and then its school, or under its
///    school, stays in the text not imported. So does a degree over a school line that names a degree of its own in any
///    part ("University of Leipzig — Master of Science, 2014", "University of Leipzig, MSc Physics"): that line is a
///    study of its own, and the line above it is not its name.
/// 4. A line that holds nothing but dates ("2019 – 2021") has no shape of its own: it belongs to the entry beside it, and
///    takes that entry's kind, so that the entry reader sees the period with the line it dates. It goes to the neighbour
///    that has no date of its own before one that has ("Certified Scrum Master — Scrum Alliance, 2021" over "2015 – 2017"
///    over "MSc Physics" dates the MSc). Between two alike, a section that starts with such a line puts its dates first
///    (each belongs to the entry below it) and any other puts them after (each belongs to the entry above it); the last
///    line of a section goes to the entry above it whichever way ("Certified Scrum Master — Scrum Alliance" over
///    "2019 – 2021" is a certification of 2021, not a certification and a study with no name).
/// 5. Anything else goes with the line before it, a line already taken as noise too; the lines before the first line
///    with evidence go with that line. A section with no evidence at all keeps the kind of its heading, as before: read
///    as studies under a heading of studies, left in the text not imported under a heading that joins the two kinds.
enum StudiesAndCertifications {

    /// The kinds of a heading that joins the studies and the certifications.
    static let joinedKinds: Set<SectionKind> = [.education, .certifications]

    /// The section cut into runs of consecutive lines of one kind, in the order of the CV. Each run keeps the heading, the
    /// languages and the parts of the section; a section of studies whose lines are all studies comes back whole. A run of
    /// a line whose kind the reading cannot tell (rule 0) has the kind `.unknown`.
    static func runs(of section: Section, in document: SourceDocument, consumed: Set<Int>) -> [Section] {
        let joined = section.parts == joinedKinds
        let shapes = section.blocks.map { block -> Shape? in
            guard !consumed.contains(block.index) else { return nil }
            return shape(of: section.cells(of: block, in: document), joined: joined)
        }
        var evidence = shapes.map { $0?.kind }
        var partners: [Int: Int] = [:]
        for index in shapes.indices.dropFirst() {
            guard let above = shapes[index - 1], let below = shapes[index] else { continue }
            if above.schoolDecides, below.namesASchool {
                evidence[index - 1] = .education
                partners[index - 1] = index
                partners[index] = index - 1
            } else if below.schoolOnly, above.bare, above.kind != .unknown {
                evidence[index - 1] = .education
                partners[index - 1] = index
                partners[index] = index - 1
            }
        }
        let owned = giveDateLinesToTheirEntry(&evidence, shapes, partners: partners)
        let owners = Dictionary(uniqueKeysWithValues: owned.map { (section.blocks[$0.key].index, $0.value) })
        guard let first = evidence.compactMap({ $0 }).first else { return [section] }
        var runs: [Section] = []
        var current = first
        for (block, found) in zip(section.blocks, evidence) {
            current = found ?? current
            if var last = runs.last, last.kind == current {
                last.blocks.append(block)
                last.dateOwners[block.index] = owners[block.index]
                runs[runs.count - 1] = last
            } else {
                var run = section
                run.kind = current
                run.blocks = [block]
                run.dateOwners = [:]
                run.dateOwners[block.index] = owners[block.index]
                runs.append(run)
            }
        }
        return runs
    }

    /// Rule 4: a line of dates alone takes the kind of the entry it dates. Both neighbours are looked at, with what each
    /// already shows: a neighbour with a date of its own, or one that an earlier date line took, is dated already, so the
    /// line goes to the neighbour that is not ("Certified Scrum Master — Scrum Alliance, 2021" over "2015 – 2017" over
    /// "MSc Physics"). An entry of two lines (a degree over its school, `partners`) is one neighbour: it is dated when
    /// either line is. When both are alike the section decides: dates first, the line belongs to the entry below it, and
    /// otherwise to the one above. A line with no entry below it (the last of the section) goes to the one above it, and a
    /// line with none above it to the one below. A neighbour that shows no kind is not an entry; with none left, the line
    /// keeps the kind its own period shows. So does a line between the degree and the school of one study ("Master of
    /// Science" over "2010 – 2014" over "University of Leipzig"): the dates are that study's, see `datesInsideAStudy`.
    /// The result says which neighbour each line took, by its position in the section, for the reader of its run.
    private static func giveDateLinesToTheirEntry(
        _ evidence: inout [SectionKind?], _ shapes: [Shape?], partners: [Int: Int]
    ) -> [Int: Section.DateOwner] {
        var owners: [Int: Section.DateOwner] = [:]
        guard let first = shapes.lazy.compactMap({ $0 }).first else { return owners }
        let datesFirst = first.datesOnly
        var taken = Set<Int>()
        func isFree(_ line: Int) -> Bool {
            let lines = [line] + (partners[line].map { [$0] } ?? [])
            return !lines.contains { shapes[$0]?.dated == true || taken.contains($0) }
        }
        for index in shapes.indices where shapes[index]?.datesOnly == true {
            let above = entry(at: index - 1, shapes, evidence)
            let below = entry(at: index + 1, shapes, evidence)
            let neighbour: Int
            switch (above, below) {
            case (nil, nil): continue
            case (let only?, nil), (nil, let only?): neighbour = only
            case (let up?, let down?):
                if isFree(up) != isFree(down) {
                    neighbour = isFree(up) ? up : down
                } else if !datesFirst, datesInsideAStudy(at: index, shapes, evidence) {
                    continue
                } else {
                    neighbour = datesFirst ? down : up
                }
            }
            if let kind = evidence[neighbour] {
                evidence[index] = kind
                taken.insert(neighbour)
                if let partner = partners[neighbour] { taken.insert(partner) }
                owners[index] = neighbour > index ? .below : .above
            }
        }
        return owners
    }

    /// The index of a line that is an entry of some kind: not a date line itself, with a kind.
    private static func entry(at index: Int, _ shapes: [Shape?], _ evidence: [SectionKind?]) -> Int? {
        guard shapes.indices.contains(index), let shape = shapes[index], !shape.datesOnly, evidence[index] != nil else { return nil }
        return index
    }

    /// Whether the line of dates at `index` stands between the degree and the school of one study: the line above names a
    /// degree and nothing else (no school, issuer or date, and no certification), the line below names a school and no
    /// degree, and no line of dates follows. Any other pair is two entries, and the section's direction decides.
    private static func datesInsideAStudy(at index: Int, _ shapes: [Shape?], _ evidence: [SectionKind?]) -> Bool {
        guard shapes.indices.contains(index + 1), let above = shapes[index - 1], let below = shapes[index + 1],
            !below.datesOnly, !below.dated, below.namesASchool, evidence[index + 1] == .education,
            above.bare, !above.namesASchool, evidence[index - 1] == .education || evidence[index - 1] == .unknown
        else { return false }
        return !(shapes.indices.contains(index + 2) && shapes[index + 2]?.datesOnly == true)
    }

    /// What a line shows by its own words.
    private struct Shape {
        /// The kind the line shows, or nil when it shows none.
        var kind: SectionKind?
        /// The line is a study by its school alone: no degree in any of its parts, no period with an end.
        var schoolOnly = false
        /// The line states no issuer and no date.
        var bare = false
        /// The line is a degree of no kind the reading can tell (rule 1) and names no issuer: a line just below that names
        /// a school settles it as a study (rule 3).
        var schoolDecides = false
        /// The line names a school and no degree in any of its parts, with or without dates: it settles a degree just
        /// above it (rule 3).
        var namesASchool = false
        /// The line holds dates and no other word (rule 4).
        var datesOnly = false
        /// The line holds a date.
        var dated = false
    }

    private static func shape(of cells: [Piece], joined: Bool) -> Shape? {
        guard !cells.isEmpty else { return nil }
        let text = cells.map(\.text).joined(separator: " — ")
        let dates = DateReader.periods(in: text)
        var shape = byItsWords(cells, text: text, dates: dates, joined: joined)
        shape.dated = !dates.isEmpty
        shape.datesOnly = !dates.isEmpty && !text.indices.contains { index in
            text[index].isLetter && !dates.contains { $0.range.contains(index) }
        }
        return shape
    }

    private static func byItsWords(_ cells: [Piece], text: String, dates: [DateMatch], joined: Bool) -> Shape {
        let hasIssuer = cells.flatMap { $0.split(by: Separators.strong) }.dropFirst().contains { part in
            part.text.contains(where: \.isLetter)
        }
        let bare = !hasIssuer && dates.isEmpty
        let period = dates.contains { $0.period.end != nil }
        let school = EntryVocabulary.isSchool(text)
        let (name, parts) = CertificationReader.nameAndParts(of: cells)
        if let name, EntryVocabulary.isCertification(name.text), !EntryVocabulary.isSchool(name.text),
            joined || parts > 1 || !dates.isEmpty {
            let degree = EntryVocabulary.opensAStudy(name.text) || EntryVocabulary.namesADegree(name.text)
            let studyEvidence = [degree, school, period].count(where: \.self)
            return Shape(kind: studyEvidence >= 2 ? .unknown : .certifications, bare: bare)
        }
        let hasWord = EntryVocabulary.isCertification(text)
        let namesAStudy = EntryVocabulary.opensAStudy(text) || name.map { EntryVocabulary.namesADegree($0.text) } == true
        let namesADegree = namesAStudy || degreeInAnyPart(of: cells, text: text)
        if period {
            return Shape(kind: .education, bare: bare, namesASchool: school && !namesADegree)
        }
        if joined, namesAStudy, !school {
            return Shape(kind: .unknown, bare: bare, schoolDecides: !hasIssuer)
        }
        if namesAStudy && (school || !hasWord) {
            return Shape(kind: .education, bare: bare)
        }
        if school {
            return Shape(kind: .education, schoolOnly: !namesADegree, bare: bare, namesASchool: !namesADegree)
        }
        let hasSingleDate = dates.count == 1
        let certification = joined ? hasWord || (hasIssuer && hasSingleDate) : hasWord && (hasIssuer || hasSingleDate)
        return Shape(kind: certification ? .certifications : nil, bare: bare)
    }

    /// Whether a degree stands anywhere on a line: named in its text ("Master of Science", "Bachelor's", "Laurea") or as
    /// the first word of one of its parts ("MSc Physics", "Diplom-Ingenieur"). The parts are cut at the strong separators
    /// and at a comma too, as a school line may write "University of Leipzig, MSc Physics, 2014". Taking a word for a
    /// degree when it is not one only leaves the line above in the text not imported, where the person sees it.
    private static func degreeInAnyPart(of cells: [Piece], text: String) -> Bool {
        EntryVocabulary.namesADegree(text)
            || cells.flatMap { $0.split(by: Separators.strong + [", "]) }.contains { EntryVocabulary.opensAStudy($0.text) }
    }
}
