import Testing
import SwiftUI
@testable import PrestoCV

@Suite("WholeWordsText size Tests - a label takes the room of its lines, and no more")
@MainActor
struct WholeWordsTextSizeTests {

    private let sizes: [DynamicTypeSize] = [.large, .accessibility1, .accessibility3, .accessibility5]

    /// The size the view takes for the proposal, as its parent sees it: the size the renderer lays it out at, read
    /// before anything is drawn.
    private func size(of view: some View, at dynamicTypeSize: DynamicTypeSize, proposal: ProposedViewSize) throws -> CGSize {
        let renderer = ImageRenderer(content: view.font(.body).dynamicTypeSize(dynamicTypeSize))
        renderer.proposedSize = proposal
        var size: CGSize?
        renderer.render { laidOut, _ in size = laidOut }
        let laidOut = try #require(size, "The renderer laid the view out")
        try #require(laidOut.width > 0 && laidOut.height > 0, "The view takes room: \(laidOut)")
        return laidOut
    }

    @Test("Where the width is left open, as a parent does when it asks for the ideal size, a label is one line, as a text is",
          arguments: ["Document language", "Dokumentsprache", "Social-Media-Profile"])
    func openWidthKeepsOneLine(text: String) throws {
        for dynamicTypeSize in sizes {
            let label = try size(of: WholeWordsText(text), at: dynamicTypeSize, proposal: .unspecified)
            let line = try size(of: Text(text), at: dynamicTypeSize, proposal: .unspecified)
            #expect(label == line, "\(dynamicTypeSize)")
        }
    }

    @Test("In a width it fits, a label is one line at the size the person chose")
    func boundedWidthKeepsOneLine() throws {
        let proposal = ProposedViewSize(width: 360, height: nil)
        let label = try size(of: WholeWordsText("Document language"), at: .large, proposal: proposal)
        let line = try size(of: Text("Document language"), at: .large, proposal: proposal)
        #expect(label.height == line.height)
    }

    @Test("A word wider than the line takes the largest size at which it fits on the line whole")
    func longWordShrinksToFit() throws {
        let word = "Dokumentsprache"
        let width: CGFloat = 220
        let fitting = try WordFit.sizes(upTo: .accessibility5).first { candidate in
            try size(of: Text(word), at: candidate, proposal: .unspecified).width <= width
        }
        let largest = try #require(fitting)
        let label = try size(of: WholeWordsText(word), at: .accessibility5, proposal: ProposedViewSize(width: width, height: nil))
        let line = try size(of: Text(word), at: largest, proposal: .unspecified)
        #expect(label.height == line.height)
        #expect(label.width <= width)
    }
}
