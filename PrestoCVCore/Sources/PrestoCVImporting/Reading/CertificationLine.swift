/// The certification that the lines under it may go on with (#283): its place among the findings, and the line of its title.
struct OpenCertification {
    let index: Int
    let title: SourceBlock
    /// Whether the title is itself a sentence, as an item of a list can be: sentences under it are then items of their own.
    let titleIsSentence: Bool
    /// Whether the certification has an issuer or a year, as the title of an entry with details has.
    var statesIssuerOrYear: Bool
    /// Whether the title is the line right above: only that line can be completed by a line that names its issuer.
    var isRightAbove = true
}

/// A line of a certifications section, as the rules that join it to the certification above it see it (#283).
struct CertificationLine {

    /// A web address of the line and where it stands.
    struct Address {
        let link: ImportedLink
        let piece: Piece
    }

    /// What a line is to the certification above it.
    enum Role {
        /// Its first address is the link of that certification, and what labels it is left out.
        case link(OpenCertification)
        /// It goes on with that certification's description. With a reason when only its words, not the layout, placed it
        /// there: the person checks that certification.
        case description(OpenCertification, check: CheckReason?)
        /// A certification of its own. With a reason when it reads as the description of the certification above as well:
        /// the person checks it.
        case entry(check: CheckReason?)
        /// No field takes it: it stays visible as text not imported.
        case unplaced
    }

    let block: SourceBlock
    let cells: [Piece]
    let addresses: [Address]
    /// What the line says besides its addresses, cell by cell: a cell with an address is cut there, and the punctuation
    /// that stood against an address, "(…)" or "….", is no text of its own.
    let around: [Piece]
    /// The labels of a link among the pieces around the addresses: "Credential URL:", "Verify". With no address, none.
    let labels: [Piece]
    /// The line as the certification reader cuts it: its cells, or, when it has addresses, the pieces around them that
    /// are no label of a link.
    let split: CertificationReader.Line

    init(block: SourceBlock, cells: [Piece]) {
        self.block = block
        self.cells = cells
        var addresses: [Address] = []
        var around: [Piece] = []
        for cell in cells {
            let found = ContactReader.webAddresses(in: cell)
            addresses += found.map { Address(link: $0.link, piece: cell.sub($0.range)) }
            around += found.isEmpty ? [cell] : cell.removing(found.map(\.range)).filter { $0.text.contains { $0.isLetter || $0.isNumber } }
        }
        self.addresses = addresses
        self.around = around
        labels = addresses.isEmpty ? [] : around.filter { CertificationLinkLabel.isLabel($0.text) }
        split = CertificationReader.Line(addresses.isEmpty ? cells : around.filter { !CertificationLinkLabel.isLabel($0.text) })
    }

    // MARK: What the line is to the certification above it

    /// What the line is to the certification above it, `open`, if there is one. Split rather than merge: a line joins
    /// that certification only on clear evidence, because a wrong split shows on screen and costs one tap to fix, and a
    /// wrong merge loses a certification without a word. Where only the words of a line decide, the person checks the
    /// certification. In order:
    ///
    /// 1. A line that holds only web addresses, with at most the labels of a link around them ("Credential URL:",
    ///    "Verifica online", in the six languages), is that certification's link. With none above, it is text not
    ///    imported. A bare noun, "Certificate https://…", is no label: the line is a certification of its own.
    /// 2. With no certification above, any other line is a certification of its own.
    /// 3. A plain line (not bold, with no gap before it and no web address) that reads as one text and names no
    ///    organisation or school, that the layout places under the title (in the same column, indented or in a smaller
    ///    size), is that certification's description when the certification has an issuer or a year: a bare name could as
    ///    well be a heading over the lines under it. The weight of a line is never evidence.
    /// 4. A plain line that reads as one text and as a sentence is that certification's description, when the
    ///    certification's title is no sentence itself. When the layout does not place it under the title, only its
    ///    words did: the person checks the certification ("First Certificate" over "Introduction to machine learning.").
    /// 5. Everything else is a certification of its own: a line the reader cuts into a title and its issuer, "Swift
    ///    Basics, Example Academy.", whatever it ends with. One that reads as a sentence with no issuer, split off only by
    ///    an address, a date, a gap, a marker or a part in capitals, may as well be the description above: the person
    ///    checks it.
    func role(after open: OpenCertification?) -> Role {
        guard let open else { return isLinkOnly ? .unplaced : .entry(check: nil) }
        if isLinkOnly { return .link(open) }
        if isPlacedUnder(open) { return .description(open, check: nil) }
        if isSentence(under: open) { return .description(open, check: isLaidOutUnder(open) ? nil : .descriptionOrEntryUnsure) }
        return .entry(check: isInDoubt(under: open) ? .descriptionOrEntryUnsure : nil)
    }

    // MARK: Facts about the line

    /// The words of the line outside its addresses.
    var text: String { around.map(\.text).joined(separator: " ") }

    /// Only web addresses, with at most the labels of a link: "https://…", "Credential URL: https://…".
    private var isLinkOnly: Bool { !addresses.isEmpty && labels.count == around.count }

    /// A line with no marker and one cell, not bold, with no gap before it and no web address: the only lines that can
    /// go on with the certification above as its description.
    private var isPlainText: Bool {
        block.kind == .line && cells.count == 1 && !block.isEmphasized && !block.followsGap && addresses.isEmpty
    }

    /// Whether the line reads as a sentence: it ends with a full stop after at least four words outside its addresses,
    /// two of them in lower case. A title is written in capitals, "Advanced Swift Concurrency.", and is none.
    var readsAsSentence: Bool {
        let words = text.words
        return cells.last?.text.hasSuffix(".") == true && words.count >= 4 && words.filter { $0.first?.isLowercase == true }.count >= 2
    }

    /// Whether the reader's cut leaves the line one text: no date, and, when it cuts the line, no part that names an
    /// organisation or school and no part after the first in capitals. A comma alone is no evidence of an issuer:
    /// "Covers Swift, testing and deployment." is one text; "Swift Basics, Example Academy." and "Level 2, Remote" are a
    /// title with its details.
    private var readsAsOneText: Bool { split.year == nil && !namesAnIssuer && !namesAPartInCapitals }

    /// The reader cuts the line, and one of its parts names an organisation or school.
    private var namesAnIssuer: Bool { split.parts.count > 1 && split.parts.contains { Self.isIssuer($0.text) } }

    /// A part after the first is written in capitals, as a name is: "Remote", "Level 2", "Azure".
    private var namesAPartInCapitals: Bool {
        split.parts.dropFirst().contains { part in
            let words = part.text.words
            return words.contains { $0.first?.isLetter == true } && !words.contains { $0.first?.isLowercase == true }
        }
    }

    private func isSentence(under open: OpenCertification) -> Bool {
        isPlainText && readsAsOneText && !open.titleIsSentence && readsAsSentence
    }

    /// Whether a line made a certification of its own may as well be the description of the one above: it reads as a
    /// sentence, names no issuer, and the title above is no sentence itself.
    private func isInDoubt(under open: OpenCertification) -> Bool {
        !open.titleIsSentence && readsAsSentence && !namesAnIssuer
    }

    /// Whether the layout places the line under a certification with an issuer or a year, as its detail: a plain line
    /// that reads as one text and names no organisation or school.
    private func isPlacedUnder(_ open: OpenCertification) -> Bool {
        open.statesIssuerOrYear && isPlainText && readsAsOneText && !split.parts.contains { Self.isIssuer($0.text) } && isLaidOutUnder(open)
    }

    /// Whether the layout places the line under the certification's title: in the same column of the same page, and
    /// either indented or in a smaller size.
    private func isLaidOutUnder(_ open: OpenCertification) -> Bool {
        guard let frame = block.frame, let titleFrame = open.title.frame, let size = block.fontSize, let titleSize = open.title.fontSize,
              block.page == open.title.page, block.column == open.title.column else { return false }
        return frame.x - titleFrame.x > 0.5 * titleSize || size < 0.9 * titleSize
    }

    private static func isIssuer(_ text: String) -> Bool {
        EntryVocabulary.isOrganisation(text) || EntryVocabulary.isSchool(text)
    }
}
