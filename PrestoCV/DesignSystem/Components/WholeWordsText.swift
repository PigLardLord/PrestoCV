import SwiftUI

/// A short text, such as a label, a heading or the name of an option, that breaks between its words and never
/// inside one.
///
/// At the accessibility sizes a long word is wider than an iPhone, and the system hyphenates it: the German
/// "Dokumentsprache" became "Dokumentspra-che". This text takes the largest size, up to the one the person chose, at
/// which each of its words fits on a line. Running text, such as a description, still hyphenates, as print does.
///
/// It takes its font, weight, colour and line limit from the modifiers around it, as a `Text` does.
struct WholeWordsText: View {
    private let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        WholeWordsFit(fitting: [text]) {
            Text(text)
        }
    }
}

/// Content whose text breaks between words and never inside one, also where a control sets that text, such as the
/// value of a menu picker: the content takes the largest text size, up to the person's own, at which each word of
/// its texts fits on a line, beside what the line also holds (the chevrons of the menu).
struct WholeWordsFit<Content: View, Accessory: View>: View {
    private let words: [String]
    private let accessory: Accessory
    private let content: Content
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// - Parameters:
    ///   - texts: The texts the content can show. Each of their words has to fit on a line.
    ///   - accessory: What the content sets on the line beside its text.
    init(fitting texts: [String], beside accessory: Accessory, @ViewBuilder content: () -> Content) {
        self.words = texts.flatMap(WordFit.words(in:))
        self.accessory = accessory
        self.content = content()
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            ForEach(WordFit.sizes(upTo: dynamicTypeSize), id: \.self) { size in
                ZStack(alignment: .topLeading) {
                    // The widest word, with the accessory, is the width this size needs; the content asks for none
                    ForEach(words.indices, id: \.self) { index in
                        HStack {
                            Text(words[index])
                            accessory
                        }
                        .hidden()
                        .accessibilityHidden(true)
                    }
                    content
                        .frame(idealWidth: 0, alignment: .leading)
                }
                .dynamicTypeSize(size)
            }
        }
    }
}

extension WholeWordsFit where Accessory == EmptyView {
    init(fitting texts: [String], @ViewBuilder content: () -> Content) {
        self.init(fitting: texts, beside: EmptyView(), content: content)
    }
}

/// The sizes and the words that `WholeWordsFit` tries.
enum WordFit {
    /// The person's own size first, then each smaller one down to the largest of the regular sizes. Every word of
    /// the app fits on a line there, so a text is never made smaller than that.
    static func sizes(upTo size: DynamicTypeSize) -> [DynamicTypeSize] {
        let smallest = DynamicTypeSize.xxxLarge
        guard size > smallest else { return [size] }
        return DynamicTypeSize.allCases.filter { $0 >= smallest && $0 <= size }.reversed()
    }

    /// The pieces between which a line may break: at a space, and after a hyphen.
    static func words(in text: String) -> [String] {
        text.split(whereSeparator: \.isWhitespace).flatMap { word -> [String] in
            var pieces: [String] = []
            var piece = ""
            for character in word {
                piece.append(character)
                if character == "-" {
                    pieces.append(piece)
                    piece = ""
                }
            }
            if !piece.isEmpty {
                pieces.append(piece)
            }
            return pieces
        }
    }
}
