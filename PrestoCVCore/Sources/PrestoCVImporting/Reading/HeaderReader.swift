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
        var firstName: Piece?
        var lastName: Piece?

        for section in sections {
            for block in section.blocks where !findings.consumedBlocks.contains(block.index) {
                let cells = Piece.cells(of: block, in: findings.document)
                if let (label, values) = labelled(cells) {
                    switch label {
                    case .name:
                        if findings.cv.person.name == nil, let value = values.first { findings.cv.person.name = value.quote() }
                    case .firstName:
                        firstName = values.first
                    case .lastName:
                        lastName = values.first
                    case .address:
                        if findings.cv.person.location == nil, let value = values.first {
                            findings.cv.person.location = value.quote()
                        } else {
                            findings.unplace(block, in: section)
                        }
                    case .phone, .email, .web:
                        for value in values {
                            let contacts = ContactReader.read(value)
                            emails += contacts.emails.map { ($0, section) }
                            phones += contacts.phones.map { ($0, section) }
                            findings.cv.person.links += contacts.links
                            for rest in contacts.rest { findings.unplace(rest, in: section) }
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
                    rest += contacts.rest
                }
                for (index, piece) in rest.enumerated() {
                    candidates.append(Candidate(piece: piece, block: block, section: section, blockHasContacts: hasContacts, isFirstInBlock: index == 0))
                }
            }
        }

        if findings.cv.person.name == nil, let first = firstName, let last = lastName {
            findings.cv.person.name = Sourced(value: first.text + " " + last.text, spans: [first.span, last.span])
        } else if findings.cv.person.name == nil, let only = firstName ?? lastName {
            findings.cv.person.name = only.quote()
        }
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
        if findings.cv.person.name == nil, let index = nameCandidate(in: candidates) {
            let candidate = candidates[index]
            let isMarked = candidate.block.kind == .heading(level: 1) || index == 0 || isLargestText(candidate.block, in: findings.document)
            findings.cv.person.name = candidate.piece.quote(check: isMarked ? nil : .nameByPosition)
            taken.insert(index)
            // The title follows the name, in the same line or the next
            let next = index + 1
            if next < candidates.count, candidates[next].section == candidate.section, looksLikeTitle(candidates[next]) {
                findings.cv.person.title = candidates[next].piece.quote()
                taken.insert(next)
            }
        }
        if findings.cv.person.location == nil,
           let index = candidates.indices.first(where: { !taken.contains($0) && looksLikePlace(candidates[$0]) }) {
            let piece = candidates[index].piece
            findings.cv.person.location = piece.quote(check: Places.isKnownPlace(piece.text) ? nil : .locationByPosition)
            taken.insert(index)
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

    private static func nameCandidate(in candidates: [Candidate]) -> Int? {
        candidates.indices.prefix(6).first { looksLikeName(candidates[$0].piece.text) && candidates[$0].isFirstInBlock }
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
        if !DateReader.periods(in: text).isEmpty || SectionVocabulary.kind(ofHeading: text) != nil { return false }
        if looksLikePlace(candidate) && !EntryVocabulary.isRole(text) { return false }
        return true
    }

    /// A short piece of letters that names a place: in a line of contacts, or alone with a comma or a known place.
    private static func looksLikePlace(_ candidate: Candidate) -> Bool {
        let text = candidate.piece.text
        let words = candidate.piece.words
        guard (1...8).contains(words.count), !text.contains("@"), text.contains(where: \.isLetter) else { return false }
        if EntryVocabulary.isRole(text) || EntryVocabulary.isOrganisation(text) || text.hasSuffix(".") { return false }
        if SectionVocabulary.kind(ofHeading: text) != nil || !DateReader.periods(in: text).isEmpty { return false }
        if Places.isKnownPlace(text) { return true }
        return candidate.blockHasContacts && (text.contains(",") || words.count <= 3)
    }

    /// The block drawn in the largest type of its page: the name of most PDFs.
    private static func isLargestText(_ block: SourceBlock, in document: SourceDocument) -> Bool {
        guard let size = block.fontSize else { return false }
        let sizes = document.blocks.filter { $0.page == block.page }.compactMap(\.fontSize)
        return size >= (sizes.max() ?? 0) - 0.1
    }
}
