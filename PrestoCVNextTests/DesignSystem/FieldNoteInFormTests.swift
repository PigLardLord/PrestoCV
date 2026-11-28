#if os(iOS)
import SwiftUI
import Testing
import UIKit
@testable import PrestoCV

/// The sizes a note took in the form, in the order it took them.
@MainActor
private final class NoteSizes {
    var seen: [CGSize] = []
}

/// A row of the form shaped like a job's: its fields, then the period, whose note sits under the dates and the switch,
/// then the description. The description, a field that grows to several lines, is what made the form cut a note in the
/// same row to one line. The test target cannot build the editor's own values, so the row is built from the same views.
private struct PeriodRow: View {
    let note: LocalizedStringResource
    let sizes: NoteSizes

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            TextField("Company", text: .constant("Maasbouw"))
            VStack(alignment: .leading, spacing: Spacing.medium) {
                date("Start month", year: "2021")
                Toggle(isOn: .constant(false)) { Text(verbatim: "I work here now") }
                    .frame(minHeight: TapTarget.minimumHeight)
                date("End month", year: "2019")
                FieldNote(note)
                    .onGeometryChange(for: CGSize.self) { proxy in
                        proxy.size
                    } action: { size in
                        sizes.seen.append(size)
                    }
            }
            TextField("Description", text: .constant("Ran crews of twelve on housing sites."), axis: .vertical)
        }
        .padding(.vertical, Spacing.small)
        .contextMenu { Button("Delete") {} }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) { Button("Delete") {} }
    }

    private func date(_ label: String, year: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.medium) {
            VStack(alignment: .leading, spacing: Spacing.small) {
                Text(verbatim: label).font(.footnote)
                Picker(selection: .constant(3)) {
                    Text(verbatim: "March").tag(3)
                } label: {
                    Text(verbatim: label)
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(minHeight: TapTarget.minimumHeight)
            }
            VStack(alignment: .leading, spacing: Spacing.small) {
                Text(verbatim: "Year").font(.footnote)
                TextField("Year", text: .constant(year))
            }
        }
    }
}

@Suite("FieldNote in a form: the note under a field shows all its lines")
@MainActor
struct FieldNoteInFormTests {
    /// The width in points of the narrowest iPhone the app runs on.
    private static let narrowestPhoneWidth: CGFloat = 375

    private let words = LocalizedStringResource(
        stringLiteral: "Not saved: the end comes before the start. Change one of the two dates."
    )

    /// The size the note takes alone at the width, drawn at the scale of the screen.
    private func alone(width: CGFloat, scale: CGFloat) throws -> CGSize {
        let renderer = ImageRenderer(content: FieldNote(words))
        renderer.scale = scale
        renderer.proposedSize = ProposedViewSize(width: width, height: nil)
        var size: CGSize?
        renderer.render { laidOut, _ in size = laidOut }
        return try #require(size, "The renderer laid the note out")
    }

    @Test("Under the dates and the switch of a period, the note takes the lines it takes alone at its width")
    func noteUnderAPeriodShowsAllItsLines() async throws {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let sizes = NoteSizes()
        let window = UIWindow(windowScene: scene)
        // As wide as the narrowest iPhone, so that the note takes two lines on every device the test runs on: on an
        // iPad the row is wide enough for the note to take one, and there would be nothing for the form to cut
        let height = scene.coordinateSpace.bounds.height
        window.frame = CGRect(origin: .zero, size: CGSize(width: Self.narrowestPhoneWidth, height: height))
        window.rootViewController = UIHostingController(
            rootView: Form { Section { PeriodRow(note: words, sizes: sizes) } }.formStyle(.grouped)
        )
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        let scale = window.traitCollection.displayScale
        // The form lays the row out over the next passes of the main run loop, and may size the note more than once:
        // wait, for five seconds at most, until the note takes the height it takes alone at its last width.
        var expected: CGSize?
        for _ in 0..<200 {
            if let last = sizes.seen.last {
                let alone = try alone(width: last.width, scale: scale)
                expected = alone
                if abs(last.height - alone.height) < 1 { break }
            }
            try await Task.sleep(for: .milliseconds(25))
        }
        let inForm = try #require(sizes.seen.last, "The form laid the note out")
        let whole = try #require(expected)
        let line = try alone(width: 10_000, scale: scale).height
        try #require(whole.height > line * 1.5, "At \(inForm.width) points the note takes two lines or more: \(whole)")
        #expect(abs(inForm.height - whole.height) < 1, "In the form \(sizes.seen), alone \(whole)")
    }
}
#endif
