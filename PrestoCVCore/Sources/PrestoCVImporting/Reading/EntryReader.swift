import PrestoCVDomain

/// Reads the entries of an experience or education section (ADR 0027). Entries are anchored to their dates; whether a
/// CV puts the dates before or after the entry's other lines is learned from the section itself. The labelled rows of
/// the Europass and the formato europeo are read by their labels. Within an entry, the role and the employer (or the
/// degree and the school) are told apart by a connector ("at", "presso", "bei"), by their words, or, failing both, by
/// the order the section's other entries use, and then the entry is flagged.
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

        var isBody: Bool { isBullet || isProse }
    }

    /// An entry being read: its lines by role.
    struct Draft {
        var head: [Line] = []
        var anchor: Line?
        var tail: [Line] = []
        var body: [Line] = []
        var inheritedEmployer: Piece?
    }

    static func read(_ section: Section, kind: Kind, into findings: inout Findings) {
        let lines = section.blocks.filter { !findings.consumedBlocks.contains($0.index) }
            .map { line($0, cells: section.cells(of: $0, in: findings.document)) }
        for line in lines where line.isDurationOnly {
            findings.leaveOut(line.block, .computedDuration)
        }
        for line in lines {
            for duration in line.durations where !line.isDurationOnly { findings.leaveOut(duration, .computedDuration) }
        }
        let labelled = lines.filter { $0.label != nil }.count
        if labelled >= 2 {
            readLabelled(lines, section: section, kind: kind, into: &findings)
        } else {
            let drafts = entries(of: lines, section: section, findings: &findings)
            let order = sectionOrder(drafts, kind: kind)
            for draft in drafts {
                append(draft, kind: kind, order: order, section: section, into: &findings)
            }
        }
    }

    // MARK: Lines

    static func line(_ block: SourceBlock, cells: [Piece]) -> Line {
        let text = cells.map(\.text).joined(separator: " ")
        let isBullet = block.kind == .listItem
        // A sentence: long, or ended by a full stop with words in lower case, as a description is
        let isProse = !isBullet && !block.isEmphasized && (text.words.count > 16 || endsAsSentence(text))
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

    /// Whether the text ends as a sentence does: a full stop after at least four words, two of them in lower case.
    static func endsAsSentence(_ text: String) -> Bool {
        let words = text.words
        return text.hasSuffix(".") && words.count >= 4 && words.filter { $0.first?.isLowercase == true }.count >= 2
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
                let after = cell.text[match.range.upperBound...].trimmingSpaces()
                let opensCell = before.isEmpty || before.last.map { "|·•—–-,(:/[*".contains($0) } == true
                let closesCell = after.isEmpty || after.first.map { "|·•—–-,):/]*".contains($0) } == true
                    || DurationReader.ranges(in: String(after)).first?.lowerBound == after.startIndex
                if isBullet ? before.isEmpty : (opensCell || closesCell) {
                    return (cell.sub(match.range), match.period)
                }
            }
        }
        return nil
    }

    // MARK: Entries by their dates

    private static func entries(of lines: [Line], section: Section, findings: inout Findings) -> [Draft] {
        let usable = lines.filter { !$0.isDurationOnly }
        let anchors = usable.indices.filter { usable[$0].period != nil && (!usable[$0].isBullet || usable.allSatisfy { $0.isBullet }) }
        guard !anchors.isEmpty else { return entriesWithoutDates(usable) }

        // How many lines before each date belong to its entry
        var heads: [Int] = []
        for (position, anchor) in anchors.enumerated() {
            let floor = position == 0 ? 0 : anchors[position - 1] + 1
            var count = 0
            var index = anchor - 1
            while index >= floor, !usable[index].isBody {
                count += 1
                index -= 1
            }
            heads.append(count)
        }
        let datesFirst = heads.filter { $0 == 0 }.count * 2 > heads.count
        let positive = heads.filter { $0 > 0 }
        let typicalHead = mode(positive) ?? 0

        // LinkedIn groups a company's roles: the line before the company's total duration names it
        var groupStarts: [Int: Piece] = [:]
        for (index, line) in lines.enumerated() where line.isDurationOnly && index > 0 && !lines[index - 1].isBody {
            if let employer = lines[index - 1].cells.first { groupStarts[lines[index - 1].block.index] = employer }
        }

        var drafts: [Draft] = []
        var starts: [Int] = []
        for (position, anchor) in anchors.enumerated() {
            let head = datesFirst ? 0 : min(heads[position], max(typicalHead, position == 0 ? heads[position] : 0))
            starts.append(anchor - head)
        }
        // Lines before the first entry stay visible
        if let first = starts.first {
            for line in usable[..<first] {
                for cell in line.cells { findings.unplace(cell, in: section) }
            }
        }
        var group: Piece?
        for (position, anchor) in anchors.enumerated() {
            let start = starts[position]
            let end = position + 1 < starts.count ? starts[position + 1] : usable.count
            var draft = Draft()
            draft.head = Array(usable[start..<anchor])
            // A group's roles share its company until a role names a company of its own
            if let employer = draft.head.lazy.compactMap({ groupStarts[$0.block.index] }).first {
                group = employer
            } else if draft.head.count >= 2 {
                group = nil
            }
            draft.anchor = usable[anchor]
            var index = anchor + 1
            while index < end, !usable[index].isBody, usable[index].period == nil {
                draft.tail.append(usable[index])
                index += 1
            }
            draft.body = Array(usable[index..<end])
            if let employer = group, draft.head.count < 2 { draft.inheritedEmployer = employer }
            drafts.append(draft)
        }
        return drafts
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

    private static func mode(_ values: [Int]) -> Int? {
        let counts = Dictionary(values.map { ($0, 1) }, uniquingKeysWith: +)
        return counts.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }.first?.key
    }

    // MARK: The parts of an entry

    enum Part: Equatable { case primary, secondary, location, unknown, address }

    struct Segment {
        let piece: Piece
        var part: Part
        /// The part came from a connector or a word, not from the order.
        var isMarked: Bool
    }

    /// The segments of an entry's lines without its dates and durations, each with the part it reads as.
    static func segments(of draft: Draft, kind: Kind) -> [Segment] {
        var segments: [Segment] = []
        let lines = draft.head + (draft.anchor.map { [$0] } ?? []) + draft.tail
        for line in lines {
            var removed = line.durations
            if let period = line.period?.piece { removed.append(period) }
            for cell in line.cells {
                let ranges = removed.filter { cell.span.contains($0.span) }.map { cellRange(of: $0, in: cell) }
                for piece in cell.removing(ranges).flatMap({ $0.split(by: Separators.strong + [" - "]) }) {
                    segments += split(piece, kind: kind)
                }
            }
        }
        return segments
    }

    private static func cellRange(of piece: Piece, in cell: Piece) -> Range<String.Index> {
        let scalars = cell.text.unicodeScalars
        let lower = scalars.index(scalars.startIndex, offsetBy: piece.span.lowerBound - cell.span.lowerBound)
        let upper = scalars.index(scalars.startIndex, offsetBy: piece.span.upperBound - cell.span.lowerBound)
        return lower..<upper
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
        if parts.count >= 2, let last = parts.last, Places.isCountryOrRegion(last.text),
           parts.allSatisfy({ $0.words.count <= 3 && $0.text.first?.isUppercase == true && !EntryVocabulary.isOrganisation($0.text)
               && !EntryVocabulary.isRole($0.text) && !EntryVocabulary.isSchool($0.text) && !EntryVocabulary.isDegree($0.text) }) {
            return [Segment(piece: piece, part: .location, isMarked: true)]
        }
        return parts.map { classify($0, kind: kind) }
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
        if isAddress(text) { return Segment(piece: piece, part: .address, isMarked: true) }
        return Segment(piece: piece, part: .unknown, isMarked: false)
    }

    private static func hasLegalForm(_ text: String) -> Bool {
        let words = Set(text.words.map { $0.folded })
        return ["gmbh", "ag", "spa", "srl", "ltd", "inc", "llc", "sa", "sl", "sarl", "lda", "kg"].contains(where: words.contains)
            || ["s.p.a", "s.r.l", "s.a.", "e.v"].contains { text.folded.contains($0) }
    }

    /// A street and number, or a postal code.
    private static func isAddress(_ text: String) -> Bool {
        if Places.hasPostalCode(text) { return true }
        let words = text.words.map { $0.folded }
        guard text.contains(where: \.isNumber) else { return false }
        return words.contains { streetWords.contains($0) || $0.hasSuffix("strasse") || $0.hasSuffix("straße".folded) || $0.hasSuffix("weg") || $0.hasSuffix("platz") }
    }

    private static let streetWords: Set<String> = Set(["via", "viale", "piazza", "corso", "largo", "str", "strasse", "weg", "platz", "allee",
        "calle", "avenida", "av", "plaza", "paseo", "rua", "avenue", "rue", "boulevard", "bd", "street", "st", "road", "rd", "lane", "travessa", "largo"].map(\.folded))

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
        let location = locationValue(locations, in: findings.document)
        let period = draft.anchor?.period.map { periodValue($0.piece, $0.value) }
        let details = (extra.map(\.piece) + draft.body.flatMap(\.cells)).map { $0.quote() }
        let check: CheckReason? = byOrder && (primary != nil && secondary != nil) ? .roleOrEmployerByOrder : nil
        switch kind {
        case .experience:
            var entry = ImportedExperience()
            entry.role = primary?.piece.quote()
            entry.employer = secondary?.piece.quote()
            entry.location = location
            entry.period = period
            entry.details = details
            entry.check = check
            guard entry.role != nil || entry.employer != nil || entry.period != nil else { return unplace(details, in: section, &findings) }
            findings.cv.experience.append(entry)
        case .education:
            var entry = ImportedEducation()
            entry.degree = primary?.piece.quote()
            entry.school = secondary?.piece.quote()
            entry.location = location
            entry.period = period
            entry.details = details
            entry.check = check
            guard entry.degree != nil || entry.school != nil || entry.period != nil else { return unplace(details, in: section, &findings) }
            findings.cv.education.append(entry)
        }
    }

    private static func unplace(_ details: [Sourced<String>], in section: Section, _ findings: inout Findings) {
        for detail in details {
            guard let span = detail.spans.first else { continue }
            findings.unplace(Piece(text: detail.value, span: span), in: section)
        }
    }

    /// The place of an entry: one quote from its first location segment to its last, when they are in one block;
    /// otherwise the first.
    private static func locationValue(_ segments: [Segment], in document: SourceDocument) -> Sourced<String>? {
        let pieces = segments.map(\.piece).sorted { $0.span < $1.span }
        guard let first = pieces.first, let last = pieces.last else { return nil }
        return covering(first, last, in: document)
    }

    /// One quote from the start of `first` to the end of `last`, when no line break comes between them.
    private static func covering(_ first: Piece, _ last: Piece, in document: SourceDocument) -> Sourced<String> {
        let span = SourceSpan(first.span.lowerBound, last.span.upperBound)
        let text = document.text(of: span)
        guard !text.contains("\n") else { return first.quote() }
        return Sourced(value: text, spans: [span])
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

    // MARK: Labelled rows

    private static func readLabelled(_ lines: [Line], section: Section, kind: Kind, into findings: inout Findings) {
        var entries: [[(EntryVocabulary.EntryLabel?, [Piece])]] = []
        var current: [(EntryVocabulary.EntryLabel?, [Piece])] = []
        var pendingLabel: EntryVocabulary.EntryLabel?
        for line in lines {
            var label = line.label
            var values = line.label == nil ? line.cells : line.labelValue
            if label != nil && values.isEmpty {
                pendingLabel = label
                continue
            }
            if label == nil, let pending = pendingLabel {
                label = pending
                values = line.cells
            }
            pendingLabel = nil
            let opensEntry = label == .period || (label == .employer && current.contains { $0.0 == .employer })
                || (label == .school && current.contains { $0.0 == .school })
            if opensEntry && !current.isEmpty {
                entries.append(current)
                current = []
            }
            current.append((label, values))
        }
        if !current.isEmpty { entries.append(current) }

        for rows in entries {
            var period: Sourced<ImportedPeriod>?
            var primary: Piece?
            var secondary: Piece?
            var location: Sourced<String>?
            var details: [Sourced<String>] = []
            for (label, values) in rows {
                switch label {
                case .period:
                    if let value = values.first, let match = DateReader.periods(in: value.text).first {
                        period = periodValue(value.sub(match.range), match.period)
                    } else {
                        details += values.map { $0.quote(check: .periodUnreadable) }
                    }
                case .employer, .school:
                    let parts = values.first?.split(by: [", "]) ?? []
                    secondary = parts.first
                    if parts.count > 1, let first = parts.dropFirst().first, let last = parts.last {
                        location = covering(first, last, in: findings.document)
                    }
                case .role, .qualification:
                    primary = values.first
                    details += values.dropFirst().map { $0.quote() }
                case .location:
                    location = values.first?.quote()
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
                findings.cv.experience.append(entry)
            case .education:
                var entry = ImportedEducation()
                entry.degree = primary?.quote()
                entry.school = secondary?.quote()
                entry.location = location
                entry.period = period
                entry.details = details
                findings.cv.education.append(entry)
            }
        }
    }
}
