import SwiftUI
import Testing
@testable import PrestoCVNext

@Suite("WholeWordsText size: a word never breaks, and a text takes the room of its lines and no more")
@MainActor
struct WholeWordsTextSizeTests {
    private let sizes: [DynamicTypeSize] = [.large, .accessibility1, .accessibility3, .accessibility5]
    /// The sizes a text may take when the person chose the largest one, largest first: down to the largest of the regular sizes.
    private let shrinking: [DynamicTypeSize] = [
        .accessibility5, .accessibility4, .accessibility3, .accessibility2, .accessibility1, .xxxLarge
    ]

    private func label(_ text: String) -> WholeWordsText {
        WholeWordsText(LocalizedStringResource(stringLiteral: text))
    }

    /// The size the view takes for the proposal, as its parent sees it: the size the renderer lays it out at, read
    /// before anything is drawn.
    private func size(
        of view: some View, font: Font, at dynamicTypeSize: DynamicTypeSize, proposal: ProposedViewSize
    ) throws -> CGSize {
        let renderer = ImageRenderer(content: view.font(font).dynamicTypeSize(dynamicTypeSize))
        renderer.proposedSize = proposal
        var size: CGSize?
        renderer.render { laidOut, _ in size = laidOut }
        let laidOut = try #require(size, "The renderer laid the view out")
        try #require(laidOut.width > 0 && laidOut.height > 0, "The view takes room: \(laidOut)")
        return laidOut
    }

    /// The largest size, from the person's largest one down, at which the word fits on a line of the width.
    private func largestFitting(_ word: String, font: Font, width: CGFloat) throws -> DynamicTypeSize {
        let fitting = try shrinking.first { candidate in
            try size(of: Text(verbatim: word), font: font, at: candidate, proposal: .unspecified).width <= width
        }
        return try #require(fitting, "\(word) fits on a line of \(width) points at some size")
    }

    @Test("Where the width is left open, as a parent does when it asks for the ideal size, a label is one line, as a text is",
          arguments: ["Document language", "Dokumentsprache", "Social-Media-Profile"])
    func openWidthKeepsOneLine(text: String) throws {
        for dynamicTypeSize in sizes {
            let label = try size(of: label(text), font: .body, at: dynamicTypeSize, proposal: .unspecified)
            let line = try size(of: Text(verbatim: text), font: .body, at: dynamicTypeSize, proposal: .unspecified)
            #expect(label == line, "\(dynamicTypeSize)")
        }
    }

    @Test("In a width it fits, a label is one line at the size the person chose")
    func boundedWidthKeepsOneLine() throws {
        let proposal = ProposedViewSize(width: 360, height: nil)
        let label = try size(of: label("Document language"), font: .body, at: .large, proposal: proposal)
        let line = try size(of: Text(verbatim: "Document language"), font: .body, at: .large, proposal: proposal)
        #expect(label.height == line.height)
    }

    @Test("A word wider than the line takes the largest size at which it fits on the line whole")
    func longWordShrinksToFit() throws {
        let word = "Dokumentsprache"
        let width: CGFloat = 220
        let largest = try largestFitting(word, font: .body, width: width)
        let label = try size(of: label(word), font: .body, at: .accessibility5, proposal: ProposedViewSize(width: width, height: nil))
        let line = try size(of: Text(verbatim: word), font: .body, at: largest, proposal: .unspecified)
        #expect(label.height == line.height)
        #expect(label.width <= width)
    }

    @Test("The code line of an error keeps its code whole at the largest size: the line wraps between words, at the size where the code fits")
    func codeLineKeepsTheCodeWhole() throws {
        let font = Font.footnote.monospaced()
        let code = "launchFixturesRejected"
        let line = "Error code: \(code)"
        // A line narrower than the code at the largest size, as the readable column of an iPad is
        let width = try size(of: Text(verbatim: code), font: font, at: .accessibility5, proposal: .unspecified).width * 0.85
        let largest = try largestFitting(code, font: font, width: width)
        try #require(largest < .accessibility5, "The code does not fit at the largest size, so the case is the one shown")
        let proposal = ProposedViewSize(width: width, height: nil)
        let label = try size(of: label(line), font: font, at: .accessibility5, proposal: proposal)
        let wrapped = try size(of: Text(verbatim: line), font: font, at: largest, proposal: proposal)
        #expect(label.height == wrapped.height, "\(label) against \(wrapped) at \(largest)")
        #expect(label.width <= width)
    }
}
