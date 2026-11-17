import PrestoCVDomain

/// Reads the head of the CV and its personal details: the name, the professional title, the contacts, the place and,
/// when the CV has no summary under a heading, the prose at the top. Contacts are read only here, never in references
/// (ADR 0027).
enum HeaderReader {

    private struct Candidate {
        let piece: Piece
        let block: SourceBlock
        let section: Section
        let blockHasContacts: Bool
        let isFirstInBlock: Bool
        /// The piece comes after a contact of its line ("person@example.com | Greater London"): the line under it is the
        /// head's, not its title.
        let followsContact: Bool
    }

    /// Reads the head from its `sections`. The `headingsThatCouldBeTheName` are the sections opened at a heading that
    /// closed the head and could have been the name (#301): the name the head gives is then to be checked, and such a
    /// heading with no line of its own is shown with the head, as text not imported.
    static func read(
        _ sections: [Section], headingsThatCouldBeTheName cut: [Section], hasSummarySection: Bool, into findings: inout Findings
    ) {
        var candidates: [Candidate] = []
        var emails: [(Sourced<EmailAddress>, Section)] = []
        var phones: [(Sourced<PhoneNumber>, Section)] = []
        var names = LabelledName()
        // The blocks that hold a contact: a line next to one of them can be the place
        var contactBlocks = Set<Int>()
        let blocks = sections.flatMap { $0.blocks.filter { !findings.consumedBlocks.contains($0.index) } }
        // The head's name and its contacts end at this block, across its columns: no later line is evidence of the name
        let closing = contactsAfterAName(blocks, in: findings.document)?.index

        for section in sections {
            let heading = findings.heading(of: section)
            for block in section.blocks where !findings.consumedBlocks.contains(block.index) {
                let cells = Piece.cells(of: block, in: findings.document)
                if let (label, values) = labelled(cells) {
                    switch label {
                    case .name:
                        names.add(withoutCredentials(values, in: section, into: &findings), to: \.name, section: section, into: &findings)
                    case .firstName:
                        names.add(values, to: \.firstName, section: section, into: &findings)
                    case .lastName:
                        names.add(values, to: \.lastName, section: section, into: &findings)
                    case .address:
                        if findings.cv.person.location == nil, let value = values.first {
                            findings.cv.person.location = value.quote()
                            for rest in values.dropFirst() { findings.unplace(rest, in: section) }
                        } else {
                            findings.unplace(block, in: section)
                        }
                    case .phone, .email, .web:
                        contactBlocks.insert(block.index)
                        for value in values {
                            let contacts = ContactReader.read(value, label: label)
                            emails += contacts.emails.map { ($0, section) }
                            phones += contacts.phones.map { ($0, section) }
                            findings.cv.person.links += contacts.links.map { $0.under(heading) }
                            for rest in contacts.rest + contacts.unknownLabels { findings.unplace(rest, in: section) }
                        }
                    case .birth, .nationality, .maritalStatus, .gender, .fax, .other:
                        // Personal details that the CV has no field for stay visible, with their label
                        findings.unplace(block, in: section)
                    }
                    continue
                }
                let line = LineContacts(cells)
                var rest: [Piece] = []
                for contacts in line.cells {
                    emails += contacts.emails.map { ($0, section) }
                    phones += contacts.phones.map { ($0, section) }
                    findings.cv.person.links += contacts.links.map { $0.under(heading) }
                    rest += contacts.rest + keepingNames(contacts.unknownLabels, in: section, into: &findings)
                }
                if line.hasContacts { contactBlocks.insert(block.index) }
                rest.sort { $0.span < $1.span }
                for (index, piece) in rest.enumerated() {
                    candidates.append(Candidate(
                        piece: piece, block: block, section: section, blockHasContacts: line.hasContacts, isFirstInBlock: index == 0,
                        followsContact: line.follows(piece)
                    ))
                }
            }
        }

        findings.cv.person.name = names.name(into: &findings)
        takeContacts(emails: emails, phones: phones, into: &findings)

        // The document's title and a template's placeholders are no part of the CV
        candidates = candidates.filter { candidate in
            if EntryVocabulary.isDocumentTitle(candidate.piece.text) {
                findings.leaveOut(candidate.piece, .documentTitle)
                return false
            }
            if candidate.piece.text.hasPrefix("[") && candidate.piece.text.hasSuffix("]") {
                findings.leaveOut(candidate.piece, .placeholder)
                return false
            }
            return true
        }

        var taken = Set<Int>()
        var head: HeadName?
        if findings.cv.person.name == nil, let chosen = headName(of: candidates, closedAt: closing, in: findings.document) {
            head = chosen
            let reading = chosen.reading
            let candidate = candidates[reading.index]
            findings.cv.person.name = reading.name.quote(check: chosen.isSure && cut.isEmpty ? nil : .nameByPosition)
            taken.insert(reading.index)
            // The title follows the name, in the same line or the next, as written up to a place of that line (#455), and
            // the credentials of the name go with it; a line that could have been the name is to be checked as the title
            if let next = titleLine(under: reading.index, in: candidates) {
                let whole = wholeTitle(from: next, in: candidates, document: findings.document)
                findings.cv.person.title = title(whole, with: reading.split?.credentials ?? [], couldBeTheName: chosen.couldBeTheName(next))
                taken.formUnion(whole.indices)
            } else if let tail = reading.split?.tail {
                findings.unplace(tail, in: candidate.section)
            }
        }
        if findings.cv.person.location == nil,
           let index = candidates.indices.first(where: { !taken.contains($0) && looksLikePlace(candidates[$0], beside: contactBlocks) }) {
            taken.insert(index)
            let doubt = PlaceDoubt(
                couldBeTheName: head?.couldBeTheName(index) ?? false, isInDoubt: head?.leavesInDoubt(index, in: candidates) ?? false
            )
            findings.cv.person.location = location(at: index, in: candidates, beside: contactBlocks, doubt: doubt, taken: &taken)
        }
        if !hasSummarySection {
            let prose = candidates.indices.filter {
                !taken.contains($0) && candidates[$0].piece.words.count >= 12 && candidates[$0].section.kind == .header
                    && (candidates[$0].block.column ?? 0) == 0
            }
            if !prose.isEmpty {
                let pieces = prose.map { candidates[$0].piece }
                findings.cv.person.summary = Sourced(
                    value: pieces.map(\.text).joined(separator: "\n"), spans: pieces.map(\.span), check: .summaryWithoutHeading
                )
                taken.formUnion(prose)
            }
        }
        for (index, candidate) in candidates.enumerated() where !taken.contains(index) {
            findings.unplace(candidate.piece, in: candidate.section)
        }
        // A heading that could have been the name and has no line of its own would vanish with its section
        for section in cut where section.blocks.isEmpty {
            guard let heading = section.heading,
                  let head = sections.last(where: { ($0.heading ?? $0.blocks.first).map { $0.index < heading.index } ?? false }) ?? sections.first
            else { continue }
            findings.unplace(heading, in: head)
        }
    }

    // MARK: Labelled name

    /// The parts of the name given by label: a name, a first name and a last name. A first name and a last name are
    /// one name, the first name first; a part that is not in the name stays visible as text not imported.
    private struct LabelledName {
        struct Part {
            let piece: Piece
            let section: Section
        }

        var name: Part?
        var firstName: Part?
        var lastName: Part?

        /// Keeps the first value of a label; any other value of it is text not imported.
        mutating func add(_ values: [Piece], to slot: WritableKeyPath<LabelledName, Part?>, section: Section, into findings: inout Findings) {
            guard let first = values.first else { return }
            if self[keyPath: slot] == nil {
                self[keyPath: slot] = Part(piece: first, section: section)
            } else {
                findings.unplace(first, in: section)
            }
            for rest in values.dropFirst() { findings.unplace(rest, in: section) }
        }

        func name(into findings: inout Findings) -> Sourced<String>? {
            if name != nil, let firstName { findings.unplace(firstName.piece, in: firstName.section) }
            guard let given = name ?? firstName else { return lastName?.piece.quote() }
            guard let last = lastName else { return given.piece.quote() }
            // A name that holds the surname already is the whole name; the surname is not doubled
            let isWholeName = name != nil && given.piece.words.count >= 2
            if isWholeName || Self.holds(given.piece.text, last.piece.text) {
                findings.unplace(last.piece, in: last.section)
                return given.piece.quote()
            }
            return Sourced(value: given.piece.text + " " + last.piece.text, spans: [given.piece.span, last.piece.span])
        }

        private static func holds(_ name: String, _ part: String) -> Bool {
            let part = SectionVocabulary.key(part)
            return !part.isEmpty && " \(SectionVocabulary.key(name)) ".contains(" \(part) ")
        }
    }

    // MARK: Labels

    /// A row whose first cell is the label of a personal detail, or a line that reads "Label: value".
    private static func labelled(_ cells: [Piece]) -> (EntryVocabulary.PersonalLabel, [Piece])? {
        guard let first = cells.first else { return nil }
        if cells.count >= 2, let label = EntryVocabulary.personalLabel(first.text) {
            return (label, Array(cells.dropFirst()))
        }
        guard cells.count == 1, let colon = first.text.firstIndex(of: ":") else { return nil }
        let name = first.sub(first.text.startIndex..<colon).trimmed()
        guard name.words.count <= 5, let label = EntryVocabulary.personalLabel(name.text) else { return nil }
        let value = first.sub(first.text.index(after: colon)..<first.text.endIndex).trimmed()
        return value.isEmpty ? nil : (label, [value])
    }

    // MARK: Contacts

    /// The contacts in the cells of a line, and where the first of them starts.
    private struct LineContacts {
        private(set) var cells: [ContactReader.Contacts] = []
        private var firstContact: Int?
        /// Whether a cell of the line holds a contact: told once, for the line may have a cell for each character.
        private(set) var hasContacts = false

        init(_ pieces: [Piece]) {
            for piece in pieces {
                let contacts = ContactReader.read(piece)
                let spans = contacts.emails.flatMap(\.spans) + contacts.phones.flatMap(\.spans) + contacts.links.flatMap(\.address.spans)
                if let start = spans.map(\.lowerBound).min() { firstContact = min(firstContact ?? start, start) }
                if !contacts.isEmpty { hasContacts = true }
                cells.append(contacts)
            }
        }

        /// Whether a piece of the line comes after its first contact.
        func follows(_ piece: Piece) -> Bool {
            firstContact.map { $0 < piece.span.lowerBound } ?? false
        }
    }

    /// The block of the head, given as its blocks in reading order, where a line in the shape of a name is followed by its
    /// contacts, on the line itself or under it: "Anna Weber / person@example.com", "Anna Weber, RN | +44 20 7946 0000",
    /// or a name and a contact given by their labels. No line after it is evidence of the name, and a heading of the first
    /// level after it, in its column, opens a section, whatever its shape (#301). A piece after a contact of its line
    /// holds the place, and a line of known places alone is a place: neither is such a line. Nil when the head has none,
    /// as when its contacts come first.
    static func contactsAfterAName(_ blocks: [SourceBlock], in document: SourceDocument) -> SourceBlock? {
        var readings = HeadReadings()
        return contactsAfterAName(blocks, in: document, readings: &readings)
    }

    /// The same, with the blocks read from `readings`, which keeps what each block was read as.
    static func contactsAfterAName(_ blocks: [SourceBlock], in document: SourceDocument, readings: inout HeadReadings) -> SourceBlock? {
        var hasName = false
        for block in blocks {
            switch readings.line(of: block, in: document) {
            case .label(let label):
                switch label {
                case .name, .firstName, .lastName: hasName = true
                case .phone, .email, .web: if hasName { return block }
                case .address, .birth, .nationality, .maritalStatus, .gender, .fax, .other: break
                }
            case .line(let startsAName, let hasContacts):
                if startsAName { hasName = true }
                if hasName && hasContacts { return block }
            }
        }
        return nil
    }

    /// What the check of the head reads in a block, which depends on the block alone.
    enum HeadLine {
        /// A labelled detail: "Name: …", or a row whose first cell is a label.
        case label(EntryVocabulary.PersonalLabel)
        /// A line: whether a piece of it has the shape of a name and comes before its contacts, and whether it holds a contact.
        case line(startsAName: Bool, hasContacts: Bool)
    }

    /// What the blocks of the head were read as for that check, by block. The head is looked at again for each heading that
    /// could be the name, and the head grows by the heading that is not: a block is read once, however many times the head
    /// is looked at, and each look costs a few steps for each block of it (R8).
    struct HeadReadings {
        /// The steps of a look at one block of the head that was read: the walk over it and the gathering of the head.
        static let stepsToLook = 4

        private var lines: [Int: HeadLine] = [:]

        /// Reads the blocks that were not read, counting each one and its characters against `work`.
        mutating func read(_ blocks: [SourceBlock], in document: SourceDocument, work: inout AnalysisWork) throws {
            for block in blocks where lines[block.index] == nil {
                try work.count(1 + block.span.count)
                lines[block.index] = HeaderReader.headLine(of: block, in: document)
            }
        }

        mutating func line(of block: SourceBlock, in document: SourceDocument) -> HeadLine {
            if let known = lines[block.index] { return known }
            let line = HeaderReader.headLine(of: block, in: document)
            lines[block.index] = line
            return line
        }
    }

    private static func headLine(of block: SourceBlock, in document: SourceDocument) -> HeadLine {
        let cells = Piece.cells(of: block, in: document)
        if let (label, _) = labelled(cells) { return .label(label) }
        let line = LineContacts(cells)
        let pieces = line.cells.flatMap { $0.rest + $0.unknownLabels.filter(isContent) }
        var startsAName = false
        if let first = pieces.min(by: { $0.span < $1.span }), !line.follows(first), let name = nameShaped(first)?.name,
           !Places.isPlaceOnly(name.text) {
            startsAName = true
        }
        return .line(startsAName: startsAName, hasContacts: line.hasContacts)
    }

    /// The first e-mail address and phone number are the person's; any other one stays visible as text not imported.
    private static func takeContacts(emails: [(Sourced<EmailAddress>, Section)], phones: [(Sourced<PhoneNumber>, Section)], into findings: inout Findings) {
        for (index, (email, section)) in emails.enumerated() {
            if index == 0 && findings.cv.person.email == nil {
                findings.cv.person.email = email
            } else if let span = email.spans.first {
                findings.unplace(Piece(text: findings.document.text(of: span), span: span), in: section)
            }
        }
        for (index, (phone, section)) in phones.enumerated() {
            if index == 0 && findings.cv.person.phone == nil {
                findings.cv.person.phone = phone
            } else if let span = phone.spans.first {
                findings.unplace(Piece(text: findings.document.text(of: span), span: span), in: section)
            }
        }
        var seen = Set<String>()
        findings.cv.person.links = findings.cv.person.links.filter { seen.insert($0.address.value.value.lowercased()).inserted }
    }

    // MARK: Name, title and place

    /// A line of the head read as a name, with its credentials cut off.
    private struct NameReading {
        let index: Int
        let name: Piece
        let split: Credentials.Split?
        /// What the word lists say against the line as a name: it breaks a tie of evidence and takes away sureness, and
        /// never decides alone.
        let doubt: Int
    }

    /// The name chosen among the lines of the head, and the lines that could have been it.
    private struct HeadName {
        let reading: NameReading
        let isSure: Bool
        /// The other lines with the shape of a name, except a piece after a contact of its line, which holds the place.
        let rivals: Set<Int>

        /// Whether the line at `index` could have been the name: the name is not sure and the line has the shape of one.
        /// The place or the title it becomes is then to be checked as well.
        func couldBeTheName(_ index: Int) -> Bool {
            !isSure && rivals.contains(index)
        }

        /// Whether a place that only a known word tells, at `index`, is in doubt: the line could have been the name, or it
        /// is the line right under the name, where a title is expected. A place after a contact of its line is where the
        /// head puts its place, and in no doubt.
        func leavesInDoubt(_ index: Int, in candidates: [Candidate]) -> Bool {
            guard !candidates[index].followsContact else { return false }
            return couldBeTheName(index) || (index == reading.index + 1 && !candidates[index].blockHasContacts)
        }
    }

    /// The name of the head, chosen among its first lines that have the shape of a name on the evidence of the whole head,
    /// which no vocabulary gives (ADR 0027, #301): a mark (a heading of the first level, the largest type of its page)
    /// counts most, then a title under the line, then being the first line of the head, and a line made only of known
    /// places reads as a place. A name can hold a word that is also a city, a trade or a point of the compass ("Thomas
    /// Kiel", "Rebecca Cook", "Victoria West") and a place a word no list knows ("Greater Wexby"), so a word list only
    /// breaks a tie: on equal evidence the line the lists say less against wins, then the earlier one. The best line is the
    /// name even on weak evidence; it is sure only when no list knows it, no other line has a title under it, and it is the
    /// only marked line, or the first line with a title of its own (one without the shape of a name) or with no other line
    /// that could be the name. A piece that follows a contact of its own line is the head's place: it is not its first
    /// line, it has no title under it, and it could not be the name.
    ///
    /// A mark tells the name only where no name has come before it, which the shape of a line cannot tell: a line after
    /// the `closing` block, where a line in the shape of a name and its contacts end, in any column of the head, gains no
    /// evidence, neither a mark of any kind nor a title ("Anna Weber / person@example.com / Community Outreach", the last
    /// line the largest); nor does a heading of the first level under a line in the shape of a name, in any column ("Anna
    /// Weber / Nurse / # University Projects"). Such a line stays one that could be the name, so the name is to be checked
    /// unless a mark of its own makes it sure. A line made only of known places above it, or a piece after a contact,
    /// takes no evidence away.
    private static func headName(of candidates: [Candidate], closedAt closing: Int?, in document: SourceDocument) -> HeadName? {
        let window = candidates.indices.prefix(6).filter { candidates[$0].isFirstInBlock }
        let readings = window.compactMap { nameReading(at: $0, in: candidates) }
        let indices = Set(readings.map(\.index))
        func gainsNoEvidence(_ index: Int) -> Bool {
            if let closing, candidates[index].block.index > closing { return true }
            return candidates[index].block.kind == .heading(level: 1) && readings.contains { above in
                above.index < index && !candidates[above.index].followsContact && !Places.isPlaceOnly(above.name.text)
            }
        }
        let titled = indices.filter {
            !candidates[$0].followsContact && !gainsNoEvidence($0) && hasTitle(under: $0, in: candidates, readings: indices)
        }
        let first = candidates.indices.first { !candidates[$0].followsContact }
        func isMarked(_ index: Int) -> Bool {
            !gainsNoEvidence(index)
                && (candidates[index].block.kind == .heading(level: 1) || isLargestText(candidates[index].block, in: document))
        }
        func evidence(_ reading: NameReading) -> Int {
            let mark = isMarked(reading.index) ? 4 : 0
            let title = titled.contains(reading.index) ? 3 : 0
            let position = reading.index == first ? 2 : 0
            return mark + title + position - (Places.isPlaceOnly(reading.name.text) ? 3 : 0)
        }
        let best = readings.max { (evidence($0), -$0.doubt, -$0.index) < (evidence($1), -$1.doubt, -$1.index) }
        guard let best else { return nil }
        let rivals = indices.filter { $0 != best.index && !candidates[$0].followsContact }
        let hasOwnTitle = titleLine(under: best.index, in: candidates).map { !indices.contains($0) } ?? false
        let isOnlyMarked = isMarked(best.index) && !rivals.contains(where: isMarked)
        let isPlainlyFirst = best.index == first && (hasOwnTitle || rivals.isEmpty)
        let isSure = (isOnlyMarked || isPlainlyFirst) && best.doubt == 0 && titled.subtracting([best.index]).isEmpty
        return HeadName(reading: best, isSure: isSure, rivals: rivals)
    }

    /// The line at `index` read as a name: without its credentials, whole, or without a code that may also be a state's,
    /// which counts against it ("Jane Rowe, MD" is a name, "Silver Spring, MD" a place).
    private static func nameReading(at index: Int, in candidates: [Candidate]) -> NameReading? {
        guard let shaped = nameShaped(candidates[index].piece) else { return nil }
        return NameReading(index: index, name: shaped.name, split: shaped.split, doubt: doubt(shaped.name.text) + (shaped.isAmbiguous ? listWeight : 0))
    }

    /// A piece in the shape of a name: without its credentials, whole, or without a code that may also be a state's.
    private static func nameShaped(_ piece: Piece) -> (name: Piece, split: Credentials.Split?, isAmbiguous: Bool)? {
        if let split = Credentials.split(piece, allowingAmbiguous: false), hasNameShape(split.name.text) {
            return (split.name, split, false)
        }
        if hasNameShape(piece.text) {
            return (piece, nil, false)
        }
        if let split = Credentials.split(piece, allowingAmbiguous: true), hasNameShape(split.name.text) {
            return (split.name, split, true)
        }
        return nil
    }

    /// Whether the line under the one at `index` is its title: it reads as a title and not as another name, or it names a
    /// role and has no title under it in turn ("Greater London / Rebecca Cook / Nurse": the cook is the name, not a title).
    private static func hasTitle(under index: Int, in candidates: [Candidate], readings: Set<Int>) -> Bool {
        guard let next = titleLine(under: index, in: candidates) else { return false }
        guard readings.contains(next) else { return true }
        return EntryVocabulary.isRole(candidates[next].piece.text) && titleLine(under: next, in: candidates) == nil
    }

    /// The line under the one at `index`, in the same section, when it reads as a title.
    private static func titleLine(under index: Int, in candidates: [Candidate]) -> Int? {
        let next = index + 1
        guard next < candidates.count, candidates[next].section == candidates[index].section, looksLikeTitle(candidates[next]) else { return nil }
        return next
    }

    /// What the word lists say against a line as a name: a word of a known place, a role, an organisation or a school each
    /// count once, and a line made only of places ("Berlin Germany") twice.
    private static func doubt(_ text: String) -> Int {
        let place = Places.isPlaceOnly(text) ? 2 : Places.isKnownPlace(text) ? 1 : 0
        let lists = [EntryVocabulary.isRole(text), EntryVocabulary.isOrganisation(text), EntryVocabulary.isSchool(text)]
        return (place + lists.count(where: \.self)) * listWeight
    }

    private static let listWeight = 2

    /// The credentials of a name given under the label of a name stay visible as text not imported.
    private static func withoutCredentials(_ values: [Piece], in section: Section, into findings: inout Findings) -> [Piece] {
        guard let first = values.first, let split = Credentials.split(first, allowingAmbiguous: false), hasNameShape(split.name.text) else { return values }
        findings.unplace(split.tail, in: section)
        return [split.name] + values.dropFirst()
    }

    /// The title with the credentials of the name after it: "Nurse, RN". A title that names a role and also has the form
    /// of a place ("Driver Creek, Oregon"), or that could have been the name, is to be checked. So is a title joined from
    /// several parts of its line: nothing tells a second part of the title ("Platform Lead") from a detail of the head
    /// ("Open to work"), so the person checks the whole of it, and no part is lost either way. The title quotes its runs
    /// and the credentials, joined by ", ", so that it is the text of its spans as the import's last check reads them.
    private static func title(_ whole: WholeTitle, with credentials: [Piece], couldBeTheName: Bool) -> Sourced<String> {
        let isJoined = whole.parts.count > 1
        let check: CheckReason? = isJoined || whole.parts.contains { hasPlaceForm($0.text) } || couldBeTheName ? .titleByPosition : nil
        let quoted = whole.runs + credentials
        return Sourced(value: quoted.map(\.text).joined(separator: ", "), spans: quoted.map(\.span), check: check)
    }

    /// The title line read as one title: the candidates it takes, its parts, and its runs, each run the text of the line
    /// from its first part to its last as written, separators included.
    private struct WholeTitle {
        var indices: [Int]
        var parts: [Piece]
        var runs: [Piece]
    }

    /// The title line from its first part on, cut at its separators and read as one title (#455): "iOS Engineer · Platform
    /// Lead". Parts with a separator between them in one cell make one run, quoted as written; parts set apart (in cells of
    /// their own, or by space alone) are runs of their own, which the title joins by ", ". It ends before the first part
    /// that is no part of a title (a place, a period, a heading), which is left for the place or shown as text not
    /// imported, and before a part that would take it past the words of a title. A line that holds a contact gives only its
    /// first part, as its other parts are the head's place and details. A title of more than one part is to be checked
    /// (`title(_:with:couldBeTheName:)`).
    private static func wholeTitle(from first: Int, in candidates: [Candidate], document: SourceDocument) -> WholeTitle {
        let line = candidates[first]
        var indices = [first]
        var runs = [line.piece]
        var words = line.piece.words.count
        guard !line.blockHasContacts else { return WholeTitle(indices: indices, parts: [line.piece], runs: runs) }
        var next = first + 1
        while next < candidates.count, candidates[next].block.index == line.block.index, candidates[next].section == line.section,
              goesOnWithTitle(candidates[next]), words + candidates[next].piece.words.count <= maxTitleWords,
              let gap = gap(between: candidates[next - 1].piece, and: candidates[next].piece, in: document) {
            let piece = candidates[next].piece
            switch gap {
            case .inOneCell:
                let run = runs.removeLast()
                let span = SourceSpan(run.span.lowerBound, piece.span.upperBound)
                runs.append(Piece(text: document.text(of: span), span: span))
            case .apart:
                runs.append(piece)
            }
            words += piece.words.count
            indices.append(next)
            next += 1
        }
        return WholeTitle(indices: indices, parts: indices.map { candidates[$0].piece }, runs: runs)
    }

    /// What lies between two parts of the title line.
    private enum Gap {
        /// A separator in one cell: "iOS Engineer · Platform Lead".
        case inOneCell
        /// A cell boundary, which the document writes as a tab, or space alone.
        case apart
    }

    /// The gap between two parts of one line; none when anything but a separator or space lies between them, such as a
    /// placeholder left out: the parts are then not one title.
    private static func gap(between left: Piece, and right: Piece, in document: SourceDocument) -> Gap? {
        let between = document.text(of: SourceSpan(left.span.upperBound, right.span.lowerBound))
        guard !between.contains(where: { $0.isLetter || $0.isNumber }) else { return nil }
        let isApart = between.allSatisfy(\.isWhitespace) || between.contains { $0 == "\t" || $0.isNewline }
        return isApart ? .apart : .inOneCell
    }

    /// A label the vocabulary does not know ("Contact via") is shown as text not imported. One that has the shape of a name
    /// or reads as a place ("Rebecca Cook: rebecca@example.com", "Torino: 333 000 0000") is the content of the line and
    /// stays a candidate.
    private static func keepingNames(_ labels: [Piece], in section: Section, into findings: inout Findings) -> [Piece] {
        var kept: [Piece] = []
        for label in labels {
            if isContent(label) {
                kept.append(label)
            } else {
                findings.unplace(label, in: section)
            }
        }
        return kept
    }

    /// Whether a label the vocabulary does not know is the content of its line: a name or a place.
    private static func isContent(_ label: Piece) -> Bool {
        hasNameShape(label.text) || Places.isKnownPlace(label.text)
    }

    /// A name with nothing against it, for a line that no other line of a head weighs: the shape of a name, and no word
    /// that a list of places, roles, organisations or schools knows.
    static func looksLikeName(_ text: String) -> Bool {
        hasNameShape(text) && doubt(text) == 0
    }

    /// The shape of a name, whatever its words mean: two to five words of letters, each with a capital or a particle
    /// such as "de", "van", "von", and no heading or document's title. A reader that finds the head of a CV by its name
    /// uses the shape, never the word lists, which would move the error to the other side (#301).
    static func hasNameShape(_ text: String) -> Bool {
        let words = text.split(separator: " ")
        guard (2...5).contains(words.count), text.count <= 60 else { return false }
        guard text.allSatisfy({ $0.isLetter || " -'’.".contains($0) }) else { return false }
        for word in words {
            guard let first = word.first(where: \.isLetter) else { return false }
            if !first.isUppercase && !nameParticles.contains(word.folded) { return false }
        }
        return SectionVocabulary.kind(ofHeading: text) == nil && !EntryVocabulary.isDocumentTitle(text)
    }

    private static let nameParticles: Set<String> = ["de", "da", "di", "del", "della", "dei", "van", "von", "der", "den", "la", "le", "y", "e", "dos", "das", "do", "du", "zu", "ten", "ter", "al", "el"]

    private static func looksLikeTitle(_ candidate: Candidate) -> Bool {
        let text = candidate.piece.text
        let words = candidate.piece.words
        guard (1...maxTitleWords).contains(words.count), text.contains(where: \.isLetter), candidate.isFirstInBlock else { return false }
        if !DateReader.periods(in: text).isEmpty || SectionVocabulary.kind(ofHeading: text) != nil || isBareLabel(text) { return false }
        // The line under the name is a title unless it is a place or a street, whatever follows it
        if looksLikePlace(candidate, beside: []) && !EntryVocabulary.isRole(text) { return false }
        return true
    }

    private static let maxTitleWords = 14

    /// A later part of the title line that goes on with the title: words with a letter, and neither a place nor the form
    /// of one, a period, a heading or a bare label.
    private static func goesOnWithTitle(_ candidate: Candidate) -> Bool {
        let text = candidate.piece.text
        guard text.contains(where: \.isLetter), DateReader.periods(in: text).isEmpty else { return false }
        if SectionVocabulary.kind(ofHeading: text) != nil || isBareLabel(text) || hasPlaceForm(text) { return false }
        return !looksLikePlace(candidate, beside: [])
    }

    /// A short piece of letters that names a place: a known place or a street, in a line of contacts, or alone with a
    /// comma. A short line of capitalised words between lines of contacts is a place as well, to be checked.
    private static func looksLikePlace(_ candidate: Candidate, beside contactBlocks: Set<Int>) -> Bool {
        let text = candidate.piece.text
        let words = candidate.piece.words
        guard (1...8).contains(words.count), !text.contains("@"), text.contains(where: \.isLetter) else { return false }
        if EntryVocabulary.isRole(text) || EntryVocabulary.isOrganisation(text) || text.hasSuffix(".") { return false }
        if SectionVocabulary.kind(ofHeading: text) != nil || !DateReader.periods(in: text).isEmpty || isBareLabel(text) { return false }
        if Places.isKnownPlace(text) || Places.isAddress(text) { return true }
        if candidate.blockHasContacts && (text.contains(",") || words.count <= 3) { return true }
        return isLoneCity(candidate, beside: contactBlocks)
    }

    /// The label of a personal detail alone on its line, its value on the lines under it: "Anschrift:", "Address".
    private static func isBareLabel(_ text: String) -> Bool {
        EntryVocabulary.personalLabel(text) != nil
    }

    /// One to three capitalised words of letters, in a line of their own next to a line of contacts: "Bielefeld".
    private static func isLoneCity(_ candidate: Candidate, beside contactBlocks: Set<Int>) -> Bool {
        let index = candidate.block.index
        guard candidate.isFirstInBlock, contactBlocks.contains(index - 1) || contactBlocks.contains(index + 1) else { return false }
        let text = candidate.piece.text
        let words = candidate.piece.words
        guard (1...3).contains(words.count), text.allSatisfy({ $0.isLetter || " -'’.".contains($0) }) else { return false }
        return words.allSatisfy { $0.first?.isUppercase == true || cityParticles.contains($0.folded) }
    }

    private static let cityParticles: Set<String> = ["am", "an", "im", "upon", "sur", "en", "de", "del", "di", "da", "do", "la", "le", "les", "aux", "on"]

    /// The form of a place, whatever list knows its words: a postal code, a city with its region or country, a mode of
    /// work, only known places, or a street address.
    private static func hasPlaceForm(_ text: String) -> Bool {
        Places.isPlaceOnly(text) || Places.isAddress(text)
    }

    /// What the name of the head says about the line of the place: it could have been the name, or it is in doubt as a
    /// place that only a known word tells.
    private struct PlaceDoubt {
        let couldBeTheName: Bool
        let isInDoubt: Bool
    }

    /// The place at `index`. A street is followed by the line of its city, and the two are one place. A line that could
    /// have been the name is to be checked whatever its form; otherwise a place with the form of one is sure, and one that
    /// only a known word tells is sure unless the name leaves it in doubt.
    private static func location(
        at index: Int, in candidates: [Candidate], beside contactBlocks: Set<Int>, doubt: PlaceDoubt, taken: inout Set<Int>
    ) -> Sourced<String> {
        let candidate = candidates[index]
        var pieces = [candidate.piece]
        let next = index + 1
        if Places.isAddress(candidate.piece.text), !Places.isKnownPlace(candidate.piece.text), next < candidates.count, !taken.contains(next),
           candidates[next].section == candidate.section, candidates[next].isFirstInBlock,
           !Places.isAddress(candidates[next].piece.text) || Places.isKnownPlace(candidates[next].piece.text),
           looksLikePlace(candidates[next], beside: contactBlocks) {
            pieces.append(candidates[next].piece)
            taken.insert(next)
        }
        let hasForm = pieces.contains { Places.isPlaceOnly($0.text) } || Places.isAddress(candidate.piece.text)
        let isKnown = pieces.contains { Places.isKnownPlace($0.text) }
        let isSure = !doubt.couldBeTheName && (hasForm || (isKnown && !doubt.isInDoubt))
        return Sourced(value: pieces.map(\.text).joined(separator: ", "), spans: pieces.map(\.span), check: isSure ? nil : .locationByPosition)
    }

    /// The block drawn in the largest type of its page: the name of most PDFs.
    private static func isLargestText(_ block: SourceBlock, in document: SourceDocument) -> Bool {
        guard let size = block.fontSize else { return false }
        let sizes = document.blocks.filter { $0.page == block.page }.compactMap(\.fontSize)
        return size >= (sizes.max() ?? 0) - 0.1
    }
}

private extension ImportedLink {
    /// The link, under the heading of the section it stands in.
    func under(_ heading: String?) -> ImportedLink {
        var link = self
        link.heading = heading
        return link
    }
}
