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
    }

    static func read(_ sections: [Section], hasSummarySection: Bool, into findings: inout Findings) {
        var candidates: [Candidate] = []
        var emails: [(Sourced<EmailAddress>, Section)] = []
        var phones: [(Sourced<PhoneNumber>, Section)] = []
        var names = LabelledName()
        // The blocks that hold a contact: a line next to one of them can be the place
        var contactBlocks = Set<Int>()

        for section in sections {
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
                            findings.cv.person.links += contacts.links
                            for rest in contacts.rest + contacts.unknownLabels { findings.unplace(rest, in: section) }
                        }
                    case .birth, .nationality, .maritalStatus, .gender, .fax, .other:
                        // Personal details that the CV has no field for stay visible, with their label
                        findings.unplace(block, in: section)
                    }
                    continue
                }
                var rest: [Piece] = []
                var hasContacts = false
                for cell in cells {
                    let contacts = ContactReader.read(cell)
                    hasContacts = hasContacts || !contacts.isEmpty
                    emails += contacts.emails.map { ($0, section) }
                    phones += contacts.phones.map { ($0, section) }
                    findings.cv.person.links += contacts.links
                    rest += contacts.rest + keepingNames(contacts.unknownLabels, in: section, into: &findings)
                }
                if hasContacts { contactBlocks.insert(block.index) }
                rest.sort { $0.span < $1.span }
                for (index, piece) in rest.enumerated() {
                    candidates.append(Candidate(piece: piece, block: block, section: section, blockHasContacts: hasContacts, isFirstInBlock: index == 0))
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
        if findings.cv.person.name == nil, let reading = nameCandidate(in: candidates) {
            let candidate = candidates[reading.index]
            let isMarked = !reading.isGuess
                && (candidate.block.kind == .heading(level: 1) || reading.index == 0 || isLargestText(candidate.block, in: findings.document))
            findings.cv.person.name = reading.name.quote(check: isMarked ? nil : .nameByPosition)
            taken.insert(reading.index)
            // The title follows the name, in the same line or the next, and the credentials of the name go with it
            let next = reading.index + 1
            if next < candidates.count, candidates[next].section == candidate.section, looksLikeTitle(candidates[next]) {
                findings.cv.person.title = title(candidates[next].piece, with: reading.split?.credentials ?? [])
                taken.insert(next)
            } else if let tail = reading.split?.tail {
                findings.unplace(tail, in: candidate.section)
            }
        }
        if findings.cv.person.location == nil,
           let index = candidates.indices.first(where: { !taken.contains($0) && looksLikePlace(candidates[$0], beside: contactBlocks) }) {
            taken.insert(index)
            findings.cv.person.location = location(at: index, in: candidates, beside: contactBlocks, taken: &taken)
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

    private struct NameReading {
        let index: Int
        let name: Piece
        let split: Credentials.Split?

        /// A name that only the position gives: a code of a state among its credentials.
        var isGuess: Bool { split?.isAmbiguous ?? false }
    }

    /// The first line of the head that reads as a name, with its credentials cut off. A line with a code that is also
    /// the code of a state ("Jane Rowe, MD") is a name only when no other line is one: "Silver Spring, MD" is a place.
    private static func nameCandidate(in candidates: [Candidate]) -> NameReading? {
        let window = candidates.indices.prefix(6).filter { candidates[$0].isFirstInBlock }
        for allowingAmbiguous in [false, true] {
            for index in window {
                let piece = candidates[index].piece
                if let split = Credentials.split(piece, allowingAmbiguous: allowingAmbiguous), looksLikeName(split.name.text) {
                    return NameReading(index: index, name: split.name, split: split)
                }
                if !allowingAmbiguous, looksLikeName(piece.text) { return NameReading(index: index, name: piece, split: nil) }
            }
        }
        return nil
    }

    /// The credentials of a name given under the label of a name stay visible as text not imported.
    private static func withoutCredentials(_ values: [Piece], in section: Section, into findings: inout Findings) -> [Piece] {
        guard let first = values.first, let split = Credentials.split(first, allowingAmbiguous: false), looksLikeName(split.name.text) else { return values }
        findings.unplace(split.tail, in: section)
        return [split.name] + values.dropFirst()
    }

    /// The title with the credentials of the name after it: "Nurse, RN".
    private static func title(_ piece: Piece, with credentials: [Piece]) -> Sourced<String> {
        guard !credentials.isEmpty else { return piece.quote() }
        let pieces = [piece] + credentials
        return Sourced(value: pieces.map(\.text).joined(separator: ", "), spans: pieces.map(\.span))
    }

    /// A label the vocabulary does not know ("Contact via") is shown as text not imported. One that reads as a name or as
    /// a place ("Jane Rowe: jane@example.com", "Torino: 333 000 0000") is the content of the line and stays a candidate.
    private static func keepingNames(_ labels: [Piece], in section: Section, into findings: inout Findings) -> [Piece] {
        var kept: [Piece] = []
        for label in labels {
            if looksLikeName(label.text) || Places.isKnownPlace(label.text) {
                kept.append(label)
            } else {
                findings.unplace(label, in: section)
            }
        }
        return kept
    }

    /// Two to five words, each with a capital (or a particle such as "de", "van", "von"), letters only, and not a
    /// heading, a role, a document's title or an organisation.
    static func looksLikeName(_ text: String) -> Bool {
        let words = text.split(separator: " ")
        guard (2...5).contains(words.count), text.count <= 60 else { return false }
        guard text.allSatisfy({ $0.isLetter || " -'’.".contains($0) }) else { return false }
        for word in words {
            guard let first = word.first(where: \.isLetter) else { return false }
            if !first.isUppercase && !nameParticles.contains(word.folded) { return false }
        }
        if SectionVocabulary.kind(ofHeading: text) != nil || EntryVocabulary.isDocumentTitle(text) { return false }
        if EntryVocabulary.isRole(text) || EntryVocabulary.isOrganisation(text) || EntryVocabulary.isSchool(text) { return false }
        return !Places.isKnownPlace(text)
    }

    private static let nameParticles: Set<String> = ["de", "da", "di", "del", "della", "dei", "van", "von", "der", "den", "la", "le", "y", "e", "dos", "das", "do", "du", "zu", "ten", "ter", "al", "el"]

    private static func looksLikeTitle(_ candidate: Candidate) -> Bool {
        let text = candidate.piece.text
        let words = candidate.piece.words
        guard (1...14).contains(words.count), text.contains(where: \.isLetter), candidate.isFirstInBlock else { return false }
        if !DateReader.periods(in: text).isEmpty || SectionVocabulary.kind(ofHeading: text) != nil || isBareLabel(text) { return false }
        // The line under the name is a title unless it is a place or a street, whatever follows it
        if looksLikePlace(candidate, beside: []) && !EntryVocabulary.isRole(text) { return false }
        return true
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

    /// The place at `index`. A street is followed by the line of its city, and the two are one place.
    private static func location(at index: Int, in candidates: [Candidate], beside contactBlocks: Set<Int>, taken: inout Set<Int>) -> Sourced<String> {
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
        let isKnown = pieces.contains { Places.isKnownPlace($0.text) } || Places.isAddress(candidate.piece.text)
        return Sourced(value: pieces.map(\.text).joined(separator: ", "), spans: pieces.map(\.span), check: isKnown ? nil : .locationByPosition)
    }

    /// The block drawn in the largest type of its page: the name of most PDFs.
    private static func isLargestText(_ block: SourceBlock, in document: SourceDocument) -> Bool {
        guard let size = block.fontSize else { return false }
        let sizes = document.blocks.filter { $0.page == block.page }.compactMap(\.fontSize)
        return size >= (sizes.max() ?? 0) - 0.1
    }
}
