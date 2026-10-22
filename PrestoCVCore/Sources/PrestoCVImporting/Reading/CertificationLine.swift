/// The certification that the lines under it may go on with: its place among the findings, and the line of its title.
struct OpenCertification {
    let index: Int
    let title: SourceBlock
    /// Whether the title is itself a sentence, as a bullet can be: sentences under it are then items of their own.
    let titleIsSentence: Bool
    /// Whether the title's line states an issuer or a year, as the title of an entry with details does.
    let statesIssuerOrYear: Bool
}

/// A line of a certifications section, as the rules that join it to the certification above it see it.
struct CertificationLine {

    /// A web address of the line and where it stands.
    struct Address {
        let link: ImportedLink
        let piece: Piece
    }

    /// What a line is to the certification above it.
    enum Role: Equatable {
        /// Its addresses are the link of that certification, and what labels them is left out.
        case link
        /// It is a sentence of that certification's description.
        case description
        /// A certification of its own; `check` says why the person should look at it when it may be a detail instead.
        case entry(check: CheckReason?)
        /// No field takes it: it stays visible as text not imported.
        case unplaced
    }

    let block: SourceBlock
    let cells: [Piece]
    let addresses: [Address]
    /// What the line says besides its addresses, cell by cell: a cell with an address is cut there.
    let around: [Piece]

    init(block: SourceBlock, cells: [Piece]) {
        self.block = block
        self.cells = cells
        var addresses: [Address] = []
        var around: [Piece] = []
        for cell in cells {
            let found = ContactReader.webAddresses(in: cell)
            addresses += found.map { Address(link: $0.link, piece: cell.sub($0.range)) }
            // The punctuation that stood against an address, "(…)" or "….", is no text of its own
            around += found.isEmpty ? [cell] : cell.removing(found.map(\.range)).filter { $0.text.contains { $0.isLetter || $0.isNumber } }
        }
        self.addresses = addresses
        self.around = around
    }

    // MARK: What the line is to the certification above it

    /// What the line is to the certification above it, `open`, if there is one. Split rather than merge: a line joins
    /// that certification only on clear evidence, because a wrong split shows on screen and costs one tap to fix, and a
    /// wrong merge loses a certification without a word. In order:
    ///
    /// 1. A line that holds only a web address, or an address after the label of a link, is that certification's link.
    ///    With none above, it is text not imported.
    /// 2. With no certification above, any other line is a certification of its own.
    /// 3. A sentence (a plain line that ends with a full stop after words in lower case) is that certification's
    ///    description when it states no date, comes with no gap before it, and the certification's own title is no
    ///    sentence. Otherwise it is a certification of its own, to check, and it is kept whole.
    /// 4. A plain line that is not bold, with no address, no date and no issuer, directly under the title, and that the
    ///    layout places under it, indented or in a smaller size, is that certification's description, when the title
    ///    states an issuer or a year: a bare name could as well be a heading over the lines under it. The weight of a
    ///    line is never evidence.
    /// 5. Everything else is a certification of its own, to check when it may be a detail of the one above: a bare word
    ///    with an address, which could be the label of the link, or a regular line under a bold title.
    func role(after open: OpenCertification?) -> Role {
        if isLinkOnly { return open == nil ? .unplaced : .link }
        guard let open else { return .entry(check: nil) }
        if endsAsSentence {
            return isDescription(of: open) ? .description : .entry(check: .certificationOrDetail)
        }
        if isPlacedUnder(open) { return .description }
        return .entry(check: couldBeDetail(of: open) ? .certificationOrDetail : nil)
    }

    private func isDescription(of open: OpenCertification) -> Bool {
        !open.titleIsSentence && !block.followsGap && !isDated
    }

    // MARK: Facts about the line

    var text: String { around.map(\.text).joined(separator: " ") }

    /// A line with no marker and one cell.
    private var isPlain: Bool { block.kind == .line && cells.count == 1 }

    /// Only web addresses, with at most the labels of a link: "https://…", "Credential URL: https://…".
    var isLinkOnly: Bool { !addresses.isEmpty && around.allSatisfy { EntryVocabulary.isLinkLabel($0.text) } }

    /// Whether the line states a date, judged on its words outside any address: an address can hold digits.
    var isDated: Bool { around.contains { !DateReader.periods(in: $0.text).isEmpty } }

    /// Whether the line is a sentence, judged on its words outside any address, so that the length of an address does not
    /// make a sentence of a title.
    var endsAsSentence: Bool { isPlain && !block.isEmphasized && EntryReader.endsAsSentence(text) }

    /// Whether a part of the line after its first is an organisation or a school: "Swift Basics – Example Academy".
    private var namesIssuer: Bool {
        around.flatMap { $0.split(by: Separators.strong + [" - ", ", "]) }.dropFirst().contains {
            EntryVocabulary.isOrganisation($0.text) || EntryVocabulary.isSchool($0.text)
        }
    }

    // MARK: Layout

    /// Whether the layout places the line under the certification's title: right below it (no gap), in the same column,
    /// and either indented or in a smaller size. A bold line, a bullet and a line that reads as a certification (a date,
    /// an issuer, an address) are never placed under another by their layout.
    private func isPlacedUnder(_ open: OpenCertification) -> Bool {
        guard open.statesIssuerOrYear, isPlain, !block.isEmphasized, !block.followsGap, addresses.isEmpty, !isDated, !namesIssuer,
              let frame = block.frame, let titleFrame = open.title.frame, let size = block.fontSize, let titleSize = open.title.fontSize,
              block.page == open.title.page, block.column == open.title.column else { return false }
        return frame.x - titleFrame.x > 0.5 * titleSize || size < 0.9 * titleSize
    }

    // MARK: Doubt

    /// Whether the line, right under a certification, may be a detail of it more than a certification of its own.
    private func couldBeDetail(of open: OpenCertification) -> Bool {
        guard isPlain, !block.followsGap else { return false }
        // A single word with an address, "Certificate https://…": a noun could be the label of the link
        if !addresses.isEmpty { return text.words.count == 1 }
        return open.title.isEmphasized && !block.isEmphasized && !isDated && !namesIssuer
    }
}
