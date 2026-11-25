import SwiftUI

/// A text, such as a title, a label or the code of an error, that breaks between its words and never inside one.
///
/// At the accessibility sizes a long word is wider than the line, and the system hyphenates it: the code of an error,
/// "launchFixturesRejected", broke in two on an iPad at the largest size. This text takes the largest size, up to the
/// one the person chose, at which each of its words fits on a line. It is never made smaller than the largest of the
/// regular sizes, where every word of the app fits on a line.
///
/// It takes its font, weight, colour and alignment from the modifiers around it, as a `Text` does.
struct WholeWordsText: View {
    private let content: Content
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(_ resource: LocalizedStringResource) {
        content = .resource(resource)
    }

    /// A text the person wrote, shown as it is and never looked up.
    init(verbatim text: String) {
        content = .verbatim(text)
    }

    var body: some View {
        let text = resolved
        let words = WordFit.words(in: text)
        OpenWidthAsUnlimited {
            ViewThatFits(in: .horizontal) {
                ForEach(WordFit.sizes(upTo: dynamicTypeSize), id: \.self) { size in
                    ZStack(alignment: .topLeading) {
                        // The widest word is the width this size needs; the text itself asks for none
                        ForEach(words.indices, id: \.self) { index in
                            Text(verbatim: words[index])
                                .hidden()
                                .accessibilityHidden(true)
                        }
                        Text(verbatim: text)
                            .frame(idealWidth: 0, alignment: .leading)
                    }
                    .dynamicTypeSize(size)
                }
            }
        }
    }

    /// The text in the language the view shows, so that the words measured are the words shown.
    private var resolved: String {
        switch content {
        case .resource(let resource):
            var resource = resource
            resource.locale = locale
            return String(localized: resource)
        case .verbatim(let text):
            return text
        }
    }

    /// A text of the app, looked up in the language the view shows, or one the person wrote.
    private enum Content {
        case resource(LocalizedStringResource)
        case verbatim(String)
    }
}

/// Gives its content unlimited room where its parent leaves the width open, as a parent does when it asks for the
/// ideal size.
///
/// Inside, each size of `WholeWordsText` asks for the width of its widest word alone, so that `ViewThatFits` compares
/// only that with the line. Measured so, the text has no width, breaks after each letter and is as tall as half the
/// screen: a parent must never see that size. With unlimited room the text takes its own size, on one line.
private struct OpenWidthAsUnlimited: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        subviews.first?.sizeThatFits(Self.room(in: proposal)) ?? .zero
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, proposal: Self.room(in: proposal))
    }

    private static func room(in proposal: ProposedViewSize) -> ProposedViewSize {
        ProposedViewSize(width: proposal.width ?? .infinity, height: proposal.height)
    }
}

/// The sizes and the words that `WholeWordsText` tries.
enum WordFit {
    /// The person's own size first, then each smaller one down to the largest of the regular sizes. Every word of the
    /// app fits on a line there, so a text is never made smaller than that.
    static func sizes(upTo size: DynamicTypeSize) -> [DynamicTypeSize] {
        let smallest = DynamicTypeSize.xxxLarge
        guard size > smallest else { return [size] }
        return DynamicTypeSize.allCases.filter { $0 >= smallest && $0 <= size }.reversed()
    }

    /// The pieces between which a line surely may break: at a space, a tab or a line break, and after a hyphen between
    /// two letters. A point where a line may not break, such as a no-break space ("Code d’erreur : …" in French) or a
    /// hyphen before a digit, stays inside a piece: a piece measured wider than it is only makes the text a size smaller,
    /// one measured narrower would let it break inside a word.
    static func words(in text: String) -> [String] {
        let characters = Array(text)
        var pieces: [String] = []
        var piece = ""
        for (index, character) in characters.enumerated() {
            if isBreakingSpace(character) {
                if !piece.isEmpty {
                    pieces.append(piece)
                    piece = ""
                }
                continue
            }
            piece.append(character)
            if character == "-", index > 0, characters[index - 1].isLetter,
               index + 1 < characters.count, characters[index + 1].isLetter {
                pieces.append(piece)
                piece = ""
            }
        }
        if !piece.isEmpty {
            pieces.append(piece)
        }
        return pieces
    }

    /// A space at which a line may break: the ordinary space, a tab, a line break. The no-break spaces (U+00A0, U+2007,
    /// U+202F) are spaces too, but join the words around them.
    private static func isBreakingSpace(_ character: Character) -> Bool {
        character == " " || character == "\t" || character.isNewline
    }
}
