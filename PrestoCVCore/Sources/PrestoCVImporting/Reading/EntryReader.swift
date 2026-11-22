import PrestoCVDomain

/// Reads the entries of an experience or education section (ADR 0027). Entries are anchored to their dates; whether a
/// CV puts the dates before or after the entry's other lines is read from the whole section (`EntryLayout`). The
/// labelled rows of the Europass and the formato europeo are read by their labels. Within an entry, the role and the
/// employer (or the degree and the school) are told apart by a connector ("at", "presso", "bei"), by their words, or,
/// failing both, by the order the section's other entries use, and then the entry is flagged.
enum EntryReader {

    enum Kind { case experience, education }

    /// A line of the section, as the entry rules see it.
    struct Line {
        let block: SourceBlock
        let cells: [Piece]
        let isBullet: Bool
        let isProse: Bool
        /// The period that anchors an entry, where the line states one prominently.
        var period: (piece: Piece, value: ImportedPeriod)?
        /// The durations LinkedIn computes.
        var durations: [Piece] = []
        /// The line is only a duration: LinkedIn's total of a company's roles.
        var isDurationOnly = false
        /// A Europass or formato europeo label, and its value.
        var label: EntryVocabulary.EntryLabel?
        var labelValue: [Piece] = []
        /// The line is a cell of a table row: only the row's first cell opens an entry.
        var opensRow: Bool?

        var isBody: Bool { isBullet || isProse }
    }

    /// An entry being read: its lines by role.
    struct Draft {
        var head: [Line] = []
        var anchor: Line?
        var tail: [Line] = []
        var body: [Line] = []
        var inheritedEmployer: Piece?
        /// The employer the entry shares with the roles before it is a line that may be a heading the vocabulary does not
        /// know (#454).
        var inheritsADoubtfulHeading = false
        /// The section's two readings part the lines next to this entry's date differently, and neither fits better.
        var boundsUnsure = false
    }

    static func read(_ section: Section, kind: Kind, into findings: inout Findings) throws {
        let lines = section.blocks.filter { !findings.consumedBlocks.contains($0.index) }
            .map { line($0, cells: section.cells(of: $0, in: findings.document)) }
        for part in tableParts(of: lines, findings: &findings) {
            switch part {
            case .columns(let rows):
                readLabelled(rows, section: section, kind: kind, into: &findings)
            case .ordinary(let ordinary, let isDoubtful):
                try readOrdinary(ordinary, isDoubtful: isDoubtful, section: section, kind: kind, into: &findings)
            }
        }
    }

    /// The lines that are not a table's mapped rows, read by their dates, or by their labels where a Europass has them.
    /// The entries read from rows a table's header does not explain are marked for the person to check.
    private static func readOrdinary(_ lines: [Line], isDoubtful: Bool, section: Section, kind: Kind,
                                     into findings: inout Findings) throws {
        for line in lines where line.isDurationOnly {
            findings.leaveOut(line.block, .computedDuration)
        }
        for line in lines {
            for duration in line.durations where !line.isDurationOnly { findings.leaveOut(duration, .computedDuration) }
        }
        let labelled = lines.filter { $0.label != nil }.count
        let before = (findings.cv.experience.count, findings.cv.education.count)
        defer { if isDoubtful { flagColumnsByOrder(before, kind: kind, into: &findings) } }
        if labelled >= 2 {
            readLabelled(lines, section: section, kind: kind, into: &findings)
        } else {
            let drafts = try entries(of: lines, section: section, kind: kind, findings: &findings)
            let order = sectionOrder(drafts, kind: kind)
            for draft in drafts {
                append(draft, kind: kind, order: order, section: section, into: &findings)
            }
        }
    }

    // MARK: Lines

    static func line(_ block: SourceBlock, cells: [Piece]) -> Line {
        let text = cells.map(\.text).joined(separator: " ")
        let words = text.words
        let isBullet = block.kind == .listItem
        // A sentence: long, or ended by a full stop with words in lower case, as a description is
        let lowerCaseWords = words.filter { $0.first?.isLowercase == true }.count
        let isProse = !isBullet && !block.isEmphasized
            && (words.count > 16 || (text.hasSuffix(".") && words.count >= 4 && lowerCaseWords >= 2))
        var line = Line(block: block, cells: cells, isBullet: isBullet, isProse: isProse)
        line.isDurationOnly = DurationReader.isDurationOnly(text)
        if !isProse {
            for cell in cells {
                line.durations += DurationReader.ranges(in: cell.text).map { cell.sub($0) }
            }
        }
        if let (label, value) = entryLabel(cells) {
            line.label = label
            line.labelValue = value
        }
        if !isProse && !line.isDurationOnly {
            line.period = anchorPeriod(in: line.label == .period ? line.labelValue : cells, isBullet: isBullet)
        }
        return line
    }

    /// A Europass row: its label in the first cell, or before a colon.
    private static func entryLabel(_ cells: [Piece]) -> (EntryVocabulary.EntryLabel, [Piece])? {
        guard let first = cells.first else { return nil }
        if let label = EntryVocabulary.entryLabel(first.text) {
            return (label, Array(cells.dropFirst()))
        }
        guard cells.count == 1, let colon = first.text.firstIndex(of: ":") else { return nil }
        let name = first.sub(first.text.startIndex..<colon).trimmed()
        guard name.words.count <= 9, let label = EntryVocabulary.entryLabel(name.text) else { return nil }
        let value = first.sub(first.text.index(after: colon)..<first.text.endIndex).trimmed()
        return (label, value.isEmpty ? [] : [value])
    }

    /// A period stated as a line's anchor: alone in its cell, or at a cell's start or end, next to a separator. A
    /// bullet anchors an entry only with its period at the start.
    private static func anchorPeriod(in cells: [Piece], isBullet: Bool) -> (Piece, ImportedPeriod)? {
        for cell in cells {
            for match in DateReader.periods(in: cell.text) {
                let before = cell.text[..<match.range.lowerBound].trimmingSpaces()
                // The text after the period as a string of its own: a range read in it indexes that string
                let after = String(cell.text[match.range.upperBound...].trimmingSpaces())
                let opensCell = before.isEmpty || before.last.map { "|·•—–-,(:/[*".contains($0) } == true
                let closesCell = after.isEmpty || after.first.map { "|·•—–-,):/]*".contains($0) } == true
                    || DurationReader.ranges(in: after).first?.lowerBound == after.startIndex
                if isBullet ? before.isEmpty : (opensCell || closesCell) {
                    return (cell.sub(match.range), match.period)
                }
            }
        }
        return nil
    }

    // MARK: Entries by their dates

    private static func entries(of lines: [Line], section: Section, kind: Kind, findings: inout Findings) throws -> [Draft] {
        // A table's row of column names heads no entry: it stays visible
        for line in lines where isColumnHeader(line) {
            for cell in line.cells { findings.unplace(cell, in: section) }
        }
        let usable = lines.filter { !$0.isDurationOnly && !isColumnHeader($0) }
        let isOnlyBullets = usable.allSatisfy { $0.isBullet }
        let anchors = usable.indices.filter { usable[$0].period != nil && (!usable[$0].isBullet || isOnlyBullets) }
        guard !anchors.isEmpty else { return entriesWithoutDates(usable) }

        // Which lines belong to which date, read both ways over the whole section
        let usuallyDatesFirst = opensWithItsFirstDate(usable, anchors: anchors, in: findings.document)
        let layout = try EntryLayout.reading(usable, anchors: anchors, kind: kind, usuallyDatesFirst: usuallyDatesFirst, work: &findings.work)

        // LinkedIn groups a company's roles: the line before the company's total duration names it
        var groupStarts: [Int: Piece] = [:]
        for (index, line) in lines.enumerated() where line.isDurationOnly && index > 0 && !lines[index - 1].isBody {
            if let employer = lines[index - 1].cells.first { groupStarts[lines[index - 1].block.index] = employer }
        }

        // Lines before the first entry, and a range that sums up the section, stay visible
        let firstEntry = layout.opensWithSummary ? 1 : 0
        let shown = firstEntry < anchors.count ? layout.starts[firstEntry] : usable.count
        for line in usable[..<shown] {
            for cell in line.cells { findings.unplace(cell, in: section) }
        }
        var drafts: [Draft] = []
        var group: (employer: Piece, block: Int)?
        for position in anchors.indices.dropFirst(firstEntry) {
            let anchor = anchors[position]
            let entry = layout.range(of: position, lineCount: usable.count)
            var draft = Draft()
            draft.head = Array(usable[entry.lowerBound..<anchor])
            // A group's roles share its company until a role names a company of its own
            if let start = draft.head.first(where: { groupStarts[$0.block.index] != nil }),
               let employer = groupStarts[start.block.index] {
                group = (employer, start.block.index)
            } else if draft.head.count >= 2 {
                group = nil
            }
            draft.anchor = usable[anchor]
            var index = anchor + 1
            while index < entry.upperBound, !usable[index].isBody, usable[index].period == nil {
                draft.tail.append(usable[index])
                index += 1
            }
            draft.body = Array(usable[index..<entry.upperBound])
            if let group, draft.head.count < 2 {
                draft.inheritedEmployer = group.employer
                draft.inheritsADoubtfulHeading = section.doubtfulHeadings.contains(group.block)
            }
            draft.boundsUnsure = layout.unsure.contains(position)
            drafts.append(draft)
        }
        return drafts
    }

    /// A table's row of column names: two cells or more, each an entry label ("Zeitraum | Schule | Abschluss").
    private static func isColumnHeader(_ line: Line) -> Bool {
        let names = line.cells.flatMap { $0.split(by: Separators.strong) }.map { $0.trimmed() }
        return names.count >= 2 && line.period == nil && names.allSatisfy { EntryVocabulary.entryLabel($0.text) != nil }
    }

    /// Whether the section opens with its first entry's date, the line holding nothing before it: the more common
    /// layout when the two readings fit the section equally (a date at the end of the first line says nothing, that
    /// line holds its entry's head).
    private static func opensWithItsFirstDate(_ usable: [Line], anchors: [Int], in document: SourceDocument) -> Bool {
        guard anchors[0] == 0, let first = surroundings(of: usable[0], in: document) else { return false }
        return !hasContent(first.before)
    }

    /// The text of the line before and after its period.
    private static func surroundings(of line: Line, in document: SourceDocument) -> (before: String, after: String)? {
        guard let period = line.period?.piece, line.block.span.lowerBound <= period.span.lowerBound,
              period.span.upperBound <= line.block.span.upperBound else { return nil }
        return (document.text(of: SourceSpan(line.block.span.lowerBound, period.span.lowerBound)),
                document.text(of: SourceSpan(period.span.upperBound, line.block.span.upperBound)))
    }

    /// Whether the text holds a letter or a digit, not only marks.
    private static func hasContent(_ text: String) -> Bool {
        text.contains { $0.isLetter || $0.isNumber }
    }

    /// Entries with no dates: a new entry at each line of a head that follows a body or a gap.
    private static func entriesWithoutDates(_ lines: [Line]) -> [Draft] {
        var drafts: [Draft] = []
        var current = Draft()
        // A list of one-line entries: each line names its parts with a separator
        let oneLineEach = lines.allSatisfy { !$0.isBody && $0.cells.count == 1 && hasSeparator($0.cells[0].text) }
        for line in lines {
            if line.isBody {
                if current.head.isEmpty && current.body.isEmpty && !drafts.isEmpty {
                    drafts[drafts.count - 1].body.append(line)
                } else {
                    current.body.append(line)
                }
                continue
            }
            if !current.head.isEmpty && (!current.body.isEmpty || line.block.followsGap || oneLineEach || current.head.count >= 3) {
                drafts.append(current)
                current = Draft()
            } else if current.head.isEmpty && !current.body.isEmpty {
                drafts.append(current)
                current = Draft()
            }
            current.head.append(line)
        }
        if !current.head.isEmpty || !current.body.isEmpty { drafts.append(current) }
        return drafts
    }

    private static func hasSeparator(_ text: String) -> Bool {
        Separators.strong.contains { text.contains($0) } || text.contains(", ")
            || EntryVocabulary.roleEmployerConnectors.contains { text.contains($0) }
    }

    // MARK: The parts of an entry

    enum Part: Equatable { case primary, secondary, location, unknown, address }

    struct Segment {
        let piece: Piece
        var part: Part
        /// The part came from a connector or a word, not from the order.
        var isMarked: Bool
        /// A place whose start no rule tells: the person checks it.
        var isUnsure = false
    }

    /// The segments of an entry's lines without its dates and durations, each with the part it reads as.
    static func segments(of draft: Draft, kind: Kind) -> [Segment] {
        var segments: [Segment] = []
        let lines = draft.head + (draft.anchor.map { [$0] } ?? []) + draft.tail
        for line in lines {
            var removed = line.durations
            if let period = line.period?.piece { removed.append(period) }
            for cell in line.cells {
                let ranges = removed.filter { cell.span.contains($0.span) }.map { cell.range(of: $0.span) }
                for piece in cell.removing(ranges).flatMap({ $0.split(by: Separators.strong + [" - "]) }) {
                    segments += split(piece, kind: kind)
                }
            }
        }
        return segments
    }

    /// A segment split at a role's connector ("Developer at Acme") or at its commas, each part classified. A place in
    /// brackets at the end, "Tienda Ejemplo S.L. (Madrid)", is a part of its own.
    private static func split(_ piece: Piece, kind: Kind) -> [Segment] {
        if piece.text.hasSuffix(")"), let open = piece.text.lastIndex(of: "("), open > piece.text.startIndex {
            let inside = piece.sub(piece.text.index(after: open)..<piece.text.index(before: piece.text.endIndex)).trimmed()
            let before = piece.sub(piece.text.startIndex..<open).trimmed()
            let looksLikePlace = (1...3).contains(inside.words.count) && inside.text.first?.isUppercase == true
                && !inside.text.contains(where: \.isNumber) && EntryVocabulary.isOrganisation(before.text)
            if !before.isEmpty, Places.isKnownPlace(inside.text) || Places.isCountryOrRegion(inside.text) || looksLikePlace {
                return split(before, kind: kind) + [Segment(piece: inside, part: .location, isMarked: true)]
            }
        }
        if kind == .experience {
            for connector in EntryVocabulary.roleEmployerConnectors {
                guard let range = piece.text.firstRange(of: connector) else { continue }
                let role = piece.sub(piece.text.startIndex..<range.lowerBound).trimmed()
                let employer = piece.sub(range.upperBound..<piece.text.endIndex).trimmed()
                guard !role.isEmpty, !employer.isEmpty, EntryVocabulary.isRole(role.text) || EntryVocabulary.isOrganisation(employer.text)
                        || role.words.count <= 4 && employer.words.count <= 5 else { continue }
                return [Segment(piece: role, part: .primary, isMarked: true)]
                    + piece.sub(range.upperBound..<piece.text.endIndex).split(by: [", "]).enumerated().map { index, part in
                        index == 0 ? Segment(piece: part, part: .secondary, isMarked: true) : classify(part, kind: kind)
                    }
            }
        }
        let parts = piece.split(by: [", "])
        // "Leeds, United Kingdom": short capitalised parts that end with a known country or region are one place
        if let place = placeStart(in: parts), let last = parts.last {
            let lower = piece.range(of: parts[place.start].span).lowerBound
            let upper = piece.range(of: last.span).upperBound
            return parts[..<place.start].map { classify($0, kind: kind) }
                + [Segment(piece: piece.sub(lower..<upper), part: .location, isMarked: true, isUnsure: place.isUnsure)]
        }
        return parts.map { classify($0, kind: kind) }
    }

    /// Where the place starts in the parts of a line that ends with a country or a region: the city before it, and the
    /// regions before that, as in "Springfield, Illinois, United States". What comes before the city, "Harbor Law Firm,
    /// Medford, Ohio", is no part of the place. The lists cut the place from what comes before it only where they tell the
    /// city: a known city, or a part before an area by its form or before a region that is no country. Before a country a
    /// part no list knows may be the city or the employer ("Curitiba, Paraná, Brasil"), so the run of short capitalised
    /// parts back to an organisation, a role, a school or a degree is the place, unsure, and no part of it moves to the
    /// employer (ADR 0027, #301).
    private static func placeStart(in parts: [Piece]) -> (start: Int, isUnsure: Bool)? {
        guard parts.count >= 2, let last = parts.last, Places.isCountryOrRegion(last.text) else { return nil }
        var start = parts.count - 2
        while start > 0, Places.isCountryOrRegion(parts[start].text) { start -= 1 }
        // A city before an area the rules do not know: "Leeds, West Yorkshire, United Kingdom". An area by its form, or a known
        // city before a part that is none, belongs to the place; "Harbor Law Firm, Medford, Ohio" keeps its employer.
        if start > 0, Places.isArea(parts[start].text) || (!Places.isPlaceOnly(parts[start].text) && Places.isPlaceOnly(parts[start - 1].text)) {
            start -= 1
        }
        guard parts[start...].allSatisfy(hasPlaceShape) else { return nil }
        guard start > 0, !isCityByTheLists(parts[start], before: parts[start + 1]) else { return (start, false) }
        let cut = start
        while start > 0, hasPlaceShape(parts[start - 1]) { start -= 1 }
        return (start, start < cut)
    }

    /// A part that can be a part of a place: up to three words, capitalised, that name no organisation, role, school or
    /// degree.
    private static func hasPlaceShape(_ part: Piece) -> Bool {
        part.words.count <= 3 && part.text.first?.isUppercase == true && !EntryVocabulary.isOrganisation(part.text)
            && !EntryVocabulary.isRole(part.text) && !EntryVocabulary.isSchool(part.text) && !EntryVocabulary.isDegree(part.text)
    }

    /// Whether the lists tell `part` as the city that starts a place: a city they know, or a part before an area by its
    /// form ("Leeds, West Yorkshire") or before a region that is no country ("Medford, Ohio").
    private static func isCityByTheLists(_ part: Piece, before next: Piece) -> Bool {
        (Places.isPlaceOnly(part.text) && !Places.isCountryOrRegion(part.text)) || Places.isArea(next.text)
            || (Places.isCountryOrRegion(next.text) && !Places.isCountry(next.text))
    }

    static func classify(_ piece: Piece, kind: Kind) -> Segment {
        let text = piece.text
        let isPlace = Places.isKnownPlace(text) && piece.words.count <= 4
        switch kind {
        case .experience:
            let isOrganisation = EntryVocabulary.isOrganisation(text)
            let isRole = EntryVocabulary.isRole(text)
            if isOrganisation && !isRole { return Segment(piece: piece, part: .secondary, isMarked: true) }
            if isRole && !isOrganisation { return Segment(piece: piece, part: .primary, isMarked: true) }
            if isRole && isOrganisation {
                return Segment(piece: piece, part: hasLegalForm(text) ? .secondary : .primary, isMarked: true)
            }
        case .education:
            let isSchool = EntryVocabulary.isSchool(text)
            let isDegree = EntryVocabulary.isDegree(text)
            if isSchool && isDegree {
                let firstWord = piece.words.first.map(String.init) ?? ""
                return Segment(piece: piece, part: EntryVocabulary.isDegree(firstWord) ? .primary : .secondary, isMarked: true)
            }
            if isSchool { return Segment(piece: piece, part: .secondary, isMarked: true) }
            if isDegree { return Segment(piece: piece, part: .primary, isMarked: true) }
        }
        if isPlace { return Segment(piece: piece, part: .location, isMarked: true) }
        if Places.isAddress(text) { return Segment(piece: piece, part: .address, isMarked: true) }
        return Segment(piece: piece, part: .unknown, isMarked: false)
    }

    private static func hasLegalForm(_ text: String) -> Bool {
        let words = Set(text.words.map { $0.folded })
        return ["gmbh", "ag", "spa", "srl", "ltd", "inc", "llc", "sa", "sl", "sarl", "lda", "kg"].contains(where: words.contains)
            || ["s.p.a", "s.r.l", "s.a.", "e.v"].contains { text.folded.contains($0) }
    }

    /// The order in which the section's entries put their two main parts, learned from the entries that mark both.
    struct Order: Equatable {
        let secondaryFirst: Bool
    }

    private static func sectionOrder(_ drafts: [Draft], kind: Kind) -> Order {
        var primaryFirst = 0
        var secondaryFirst = 0
        for draft in drafts {
            let segments = segments(of: draft, kind: kind)
            guard let primary = segments.firstIndex(where: { $0.part == .primary && $0.isMarked }),
                  let secondary = segments.firstIndex(where: { $0.part == .secondary && $0.isMarked }) else { continue }
            if primary < secondary { primaryFirst += 1 } else { secondaryFirst += 1 }
        }
        return Order(secondaryFirst: secondaryFirst > primaryFirst)
    }

    // MARK: Building an entry

    private static func append(_ draft: Draft, kind: Kind, order: Order, section: Section, into findings: inout Findings) {
        var segments = segments(of: draft, kind: kind)
        var primary: Segment?
        var secondary: Segment?
        var locations: [Segment] = []
        var extra: [Segment] = []
        for segment in segments where segment.isMarked {
            switch segment.part {
            case .primary where primary == nil: primary = segment
            case .secondary where secondary == nil: secondary = segment
            case .location, .address: locations.append(segment)
            default: extra.append(segment)
            }
        }
        segments = segments.filter { !$0.isMarked }
        var byOrder = false
        if secondary == nil, let inherited = draft.inheritedEmployer, kind == .experience {
            secondary = Segment(piece: inherited, part: .secondary, isMarked: true)
        }
        // What no word marked fills the empty parts in the section's order; a short one after them is a place
        let slots: [Part] = order.secondaryFirst ? [.secondary, .primary] : [.primary, .secondary]
        for segment in segments {
            if let slot = slots.first(where: { ($0 == .primary ? primary : secondary) == nil }) {
                var filled = segment
                filled.part = slot
                if slot == .primary { primary = filled } else { secondary = filled }
                byOrder = true
            } else if segment.piece.words.count <= 4, locations.isEmpty, segment.piece.text.first?.isUppercase == true {
                locations.append(segment)
            } else {
                extra.append(segment)
            }
        }
        // An entry has one place: the first; any other place line stays visible
        let places = locationGroups(locations, in: findings.document)
        let location = places.first
        let period = draft.anchor?.period.map { periodValue($0.piece, $0.value) }
        let details = (extra.map(\.piece) + draft.body.flatMap(\.cells)).map { $0.quote() }
        // Lines that may be another entry's come first, then a line that may be a heading: either may also be why the parts
        // were read by their order
        let takesADoubtfulHeading = (draft.head + [draft.anchor].compactMap { $0 } + draft.tail + draft.body)
            .contains { section.doubtfulHeadings.contains($0.block.index) }
            || (draft.inheritsADoubtfulHeading && secondary?.piece == draft.inheritedEmployer)
        let check: CheckReason? = draft.boundsUnsure ? .entryBoundsUnsure
            : takesADoubtfulHeading ? .headingUnsure
            : byOrder && (primary != nil && secondary != nil) ? .roleOrEmployerByOrder : nil
        switch kind {
        case .experience:
            var entry = ImportedExperience()
            entry.role = primary?.piece.quote()
            entry.employer = secondary?.piece.quote()
            entry.location = location
            entry.period = period
            entry.details = details
            entry.check = check
            guard entry.role != nil || entry.employer != nil || entry.period != nil else { return unplace(details + places, in: section, &findings) }
            findings.cv.experience.append(entry)
            unplace(Array(places.dropFirst()), in: section, &findings)
        case .education:
            var entry = ImportedEducation()
            entry.degree = primary?.piece.quote()
            entry.school = secondary?.piece.quote()
            entry.location = location
            entry.period = period
            entry.details = details
            entry.check = check
            entry.heading = findings.heading(of: section)
            guard entry.degree != nil || entry.school != nil || entry.period != nil else { return unplace(details + places, in: section, &findings) }
            findings.cv.education.append(entry)
            unplace(Array(places.dropFirst()), in: section, &findings)
        }
    }

    private static func unplace(_ values: [Sourced<String>], in section: Section, _ findings: inout Findings) {
        for value in values { findings.unplace(value, in: section) }
    }

    /// The places of an entry, in order: one quote for each run of location segments that only a separator parts, so
    /// "Leeds, United Kingdom" is one place and the same two on two lines are two. A place with an unsure part is to be
    /// checked.
    private static func locationGroups(_ segments: [Segment], in document: SourceDocument) -> [Sourced<String>] {
        var groups: [[Segment]] = []
        for segment in segments.sorted(by: { $0.piece.span < $1.piece.span }) {
            if let last = groups.last?.last, !hasContentBetween(last.piece, segment.piece, in: document) {
                groups[groups.count - 1].append(segment)
            } else {
                groups.append([segment])
            }
        }
        return groups.map { group in
            covering(group[0].piece, group[group.count - 1].piece, in: document, check: group.contains(where: \.isUnsure) ? .locationByPosition : nil)
        }
    }

    /// Whether a letter, a digit or a line break comes between two pieces.
    private static func hasContentBetween(_ first: Piece, _ second: Piece, in document: SourceDocument) -> Bool {
        document.text(of: SourceSpan(first.span.upperBound, second.span.lowerBound)).contains { $0.isLetter || $0.isNumber || $0 == "\n" || $0 == "\t" }
    }

    /// One quote from the start of `first` to the end of `last`, in one line.
    private static func covering(_ first: Piece, _ last: Piece, in document: SourceDocument, check: CheckReason? = nil) -> Sourced<String> {
        let span = SourceSpan(first.span.lowerBound, last.span.upperBound)
        return Sourced(value: document.text(of: span), spans: [span], check: check)
    }

    static func periodValue(_ piece: Piece, _ period: ImportedPeriod) -> Sourced<ImportedPeriod> {
        var check: CheckReason?
        if period.end == .unstated {
            check = .periodOpenEnd
        } else if !isReadable(period) {
            check = .periodUnreadable
        }
        return Sourced(value: period, spans: [piece.span], reading: .period, check: check)
    }

    /// Whether the CV's own period rule accepts the period (R6).
    private static func isReadable(_ period: ImportedPeriod) -> Bool {
        guard let end = period.end else { return PartialDate(year: period.start.year, month: period.start.month) != nil }
        let start = (year: period.start.year, month: period.start.month)
        do {
            switch end {
            case .current: return try Period.make(start: start, end: nil, current: true) != nil
            case .date(let date): return try Period.make(start: start, end: (date.year, date.month), current: false) != nil
            case .unstated: return try Period.make(start: start, end: nil, current: false) != nil
            }
        } catch {
            return false
        }
    }

    // MARK: Tables

    /// A part of a section, read on its own: the rows of one table whose header names the columns, or everything else.
    enum TablePart {
        case columns([Line])
        /// The lines read by their dates; `true` where they are rows of a table the header does not explain.
        case ordinary([Line], Bool)

        /// The part with one more line of description: a mapped part gets it as a line with no label, which the
        /// labelled reading keeps as a detail of the entry open above.
        func appending(_ line: Line) -> TablePart {
            switch self {
            case .columns(let rows): return .columns(rows + [line])
            case .ordinary(let held, let isDoubtful): return .ordinary(held + [line], isDoubtful)
            }
        }
    }

    /// Cuts a section's lines into its tables and the lines between them. A Markdown table's header row is markup,
    /// never data, and each table is read by its own header: a row ends the table when it does not follow the one
    /// before without a gap, or has a single cell. Where the header names the columns, each cell of a row with as many
    /// cells becomes a labelled line, the first one opening an entry. Any other row, and the rows of a table with no
    /// known column name, are read by their dates like the rest of the section and are flagged.
    private static func tableParts(of lines: [Line], findings: inout Findings) -> [TablePart] {
        var result: [TablePart] = []
        func add(_ line: Line, isDoubtful: Bool) {
            if case .ordinary(let held, let flag)? = result.last, flag == isDoubtful {
                result[result.count - 1] = .ordinary(held + [line], flag)
            } else {
                result.append(.ordinary([line], isDoubtful))
            }
        }
        var names: [EntryVocabulary.EntryLabel?] = []
        var inTable = false
        var previous = -1
        var table = 0
        var rowsOfTable = -1
        for line in lines {
            if line.block.kind == .tableHeader {
                findings.leaveOut(line.block, .markup)
                names = line.cells.map { EntryVocabulary.entryLabel($0.text) }
                inTable = true
                previous = line.block.index
                table += 1
                continue
            }
            // A row follows the one before; a blank line between two rows keeps the table where the cell count matches
            let isRow = inTable && line.block.index == previous + 1
                && (line.block.followsGap ? line.cells.count > 1 && line.cells.count == names.count
                    : line.cells.count > 1 || line.cells.count == names.count)
            if !isRow, inTable, continues(line, after: result.last, ofTable: rowsOfTable == table) {
                // A line with no date right under a row is that job's description, not an entry of its own
                previous = line.block.index
                result[result.count - 1] = result[result.count - 1].appending(line)
                continue
            }
            guard isRow else {
                inTable = false
                add(line, isDoubtful: false)
                continue
            }
            previous = line.block.index
            guard names.contains(where: { $0 != nil }), line.cells.count == names.count else {
                add(line, isDoubtful: true)
                continue
            }
            var opened = false
            var rows: [Line] = []
            for (column, cell) in line.cells.enumerated() where !cell.text.isEmpty {
                var part = Line(block: line.block, cells: [cell], isBullet: false, isProse: false)
                part.label = names[column]
                part.labelValue = [cell]
                part.opensRow = !opened
                opened = true
                rows.append(part)
            }
            if case .columns(let held)? = result.last, rowsOfTable == table {
                result[result.count - 1] = .columns(held + rows)
            } else {
                result.append(.columns(rows))
                rowsOfTable = table
            }
        }
        return result
    }

    /// Whether a line with no date, right under a row of the table being read, goes on with that row's entry.
    private static func continues(_ line: Line, after last: TablePart?, ofTable current: Bool) -> Bool {
        guard !line.block.followsGap, line.period == nil, line.label == nil, !line.isDurationOnly else { return false }
        switch last {
        case .columns?: return current
        case .ordinary(_, let isDoubtful)?: return isDoubtful
        case nil: return false
        }
    }

    /// The entries read from a table whose columns the vocabulary does not name are marked for the person to check.
    private static func flagColumnsByOrder(_ before: (Int, Int), kind: Kind, into findings: inout Findings) {
        switch kind {
        case .experience:
            for place in before.0..<findings.cv.experience.count where findings.cv.experience[place].check == nil {
                findings.cv.experience[place].check = .roleOrEmployerByOrder
            }
        case .education:
            for place in before.1..<findings.cv.education.count where findings.cv.education[place].check == nil {
                findings.cv.education[place].check = .roleOrEmployerByOrder
            }
        }
    }

    // MARK: Labelled rows

    private static func readLabelled(_ lines: [Line], section: Section, kind: Kind, into findings: inout Findings) {
        // Nothing in the rows leaves text out: what a row's period leaves over is asked of the text left out before it
        let leftOut = SpanIndex(findings.leftOut.compactMap(\.span))
        var entries: [[(EntryVocabulary.EntryLabel?, [Piece])]] = []
        var current: [(EntryVocabulary.EntryLabel?, [Piece])] = []
        // The entries that hold a line that may be a heading the vocabulary does not know (#454), by their place
        var doubtful: Set<Int> = []
        var currentIsDoubtful = false
        var pendingLabel: EntryVocabulary.EntryLabel?
        var pendingIsDoubtful = false
        for line in lines {
            var label = line.label
            var values = line.label == nil ? line.cells : line.labelValue
            let isDoubtful = section.doubtfulHeadings.contains(line.block.index)
            if label != nil && values.isEmpty {
                pendingLabel = label
                pendingIsDoubtful = isDoubtful
                continue
            }
            if label == nil, let pending = pendingLabel {
                label = pending
                values = line.cells
            }
            let rowIsDoubtful = isDoubtful || (pendingLabel != nil && pendingIsDoubtful)
            pendingLabel = nil
            pendingIsDoubtful = false
            let opensEntry = line.opensRow ?? (label == .period
                || (label == .employer && current.contains { $0.0 == .employer })
                || (label == .school && current.contains { $0.0 == .school }))
            if opensEntry && !current.isEmpty {
                if currentIsDoubtful { doubtful.insert(entries.count) }
                entries.append(current)
                current = []
                currentIsDoubtful = false
            }
            current.append((label, values))
            currentIsDoubtful = currentIsDoubtful || rowIsDoubtful
        }
        if !current.isEmpty {
            if currentIsDoubtful { doubtful.insert(entries.count) }
            entries.append(current)
        }

        for (place, rows) in entries.enumerated() {
            var period: Sourced<ImportedPeriod>?
            var primary: Piece?
            var secondary: Piece?
            var location: Sourced<String>?
            var details: [Sourced<String>] = []
            // An entry has one value for each of its parts; any other value of a row is kept as a detail, and a second
            // place or period stays visible as text not imported
            func setLocation(_ value: Sourced<String>) {
                if location == nil { location = value } else { findings.unplace(value, in: section) }
            }
            for (label, values) in rows {
                switch label {
                case .period:
                    if period == nil, let value = values.first, let match = DateReader.periods(in: value.text).first {
                        period = periodValue(value.sub(match.range), match.period)
                        for rest in value.removing([match.range]) where !leftOut.holds(rest.span) { findings.unplace(rest, in: section) }
                        for rest in values.dropFirst() { findings.unplace(rest, in: section) }
                    } else {
                        details += values.map { $0.quote(check: .periodUnreadable) }
                    }
                case .employer, .school:
                    guard secondary == nil, let first = values.first else {
                        details += values.map { $0.quote() }
                        continue
                    }
                    let parts = first.split(by: [", "])
                    secondary = parts.first
                    if parts.count > 1, let second = parts.dropFirst().first, let last = parts.last {
                        setLocation(covering(second, last, in: findings.document))
                    }
                    for rest in values.dropFirst() { findings.unplace(rest, in: section) }
                case .role, .qualification:
                    if primary == nil { primary = values.first } else { details += values.prefix(1).map { $0.quote() } }
                    details += values.dropFirst().map { $0.quote() }
                case .location:
                    if let first = values.first { setLocation(first.quote()) }
                    for rest in values.dropFirst() { findings.unplace(rest, in: section) }
                case .sector, .duties, .subjects, .level, nil:
                    details += values.map { $0.quote() }
                }
            }
            switch kind {
            case .experience:
                var entry = ImportedExperience()
                entry.role = primary?.quote()
                entry.employer = secondary?.quote()
                entry.location = location
                entry.period = period
                entry.details = details
                entry.check = doubtful.contains(place) ? .headingUnsure : nil
                findings.cv.experience.append(entry)
            case .education:
                var entry = ImportedEducation()
                entry.degree = primary?.quote()
                entry.school = secondary?.quote()
                entry.location = location
                entry.period = period
                entry.details = details
                entry.heading = findings.heading(of: section)
                entry.check = doubtful.contains(place) ? .headingUnsure : nil
                findings.cv.education.append(entry)
            }
        }
    }
}
