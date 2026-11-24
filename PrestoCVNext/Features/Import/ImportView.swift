import PrestoCVPresentation
import SwiftUI

/// The import of a CV the person already has, as text: they paste or type it in the box and tap Import, and the shell
/// opens the draft in the editor. One scroll at the readable width, which a later section joins without moving the
/// rest. The box keeps its height and a long CV scrolls inside it, so the buttons stay one swipe away. While the text
/// is read, a layer over the screen says so and offers Cancel; a problem shows in an alert, and the text stays.
struct ImportView: View {
    @Bindable var importer: ImportViewModel
    @FocusState private var focused: Bool
    @Environment(\.isCompactHeight) private var isCompactHeight
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// How much the box grows with the text size
    @ScaledMetric(relativeTo: .body) private var growth: CGFloat = 1
    /// The screen's height without the keyboard, of which the box takes at most a share
    @State private var room: CGFloat = 0

    var body: some View {
        let importing = importer.status == .importing
        ScrollView {
            content
                .padding(Spacing.large)
                .readableWidth()
        }
        .disabled(importing)
        .accessibilityHidden(importing)
        .overlay {
            if importing {
                ImportingOverlay(cancel: { importer.cancel() })
            }
        }
        .navigationTitle(Text("import.title"))
        .inlineNavigationTitle()
        .aboveTheKeyboard(shown: focused) { KeyboardDoneBar("import.done") { focused = false } }
        .background {
            // The keyboard does not shrink the box: it would move the text the person is typing
            Color.clear
                .ignoresSafeArea(.keyboard)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { room = $0 }
        }
        .modifier(ImportProblemAlert(problem: problem) {
            importer.clearProblem()
            focused = true
        })
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            VStack(spacing: Spacing.small) {
                ScreenTitle("import.title")
                    .accessibilityIdentifier("import.title")
                WholeWordsText("import.header")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: Spacing.small) {
                FieldLabel("import.text.title")
                box
            }
            PasteTextButton { importer.paste($0) }
            PrimaryButton("import.button") {
                focused = false
                importer.importText()
            }
            .disabled(!importer.canImportText)
            .accessibilityHint(Text("import.button.hint"))
            .accessibilityIdentifier("import.button")
            WholeWordsText("import.privacy")
                .footerTextStyle()
        }
    }

    private var box: some View {
        TextEditor(text: $importer.text)
            .focused($focused)
            .overlay(alignment: .topLeading) { placeholder }
            .padding(.horizontal, Spacing.small)
            .frame(height: boxHeight)
            .overlay {
                RoundedRectangle(cornerRadius: CornerRadius.control)
                    .strokeBorder(focused ? AnyShapeStyle(.tint) : AnyShapeStyle(.separator), lineWidth: 1)
            }
            .accessibilityLabel(Text("import.text.title"))
            .accessibilityHint(Text("import.text.hint"))
            .accessibilityIdentifier("import.text")
    }

    /// Where the system's editor puts the first letter (its text container's inset and line padding), so that the
    /// placeholder does not move when the person starts typing
    private static let firstLetter = EdgeInsets(top: 8, leading: 5, bottom: 0, trailing: 5)

    @ViewBuilder
    private var placeholder: some View {
        if importer.text.isEmpty {
            Text("import.text.placeholder")
                .foregroundStyle(.tertiary)
                .padding(Self.firstLetter)
                .accessibilityHidden(true)
                .allowsHitTesting(false)
        }
    }

    /// The base for the screen, grown with the text size, and at most a share of the room
    private var boxHeight: CGFloat {
        let base = isCompactHeight ? ImportBoxHeight.compactHeight
            : horizontalSizeClass == .regular ? ImportBoxHeight.regular : ImportBoxHeight.compact
        let grown = base * growth
        return room > 0 ? min(grown, room * ImportBoxHeight.maximumShare) : grown
    }

    private var problem: ImportProblem? {
        if case .failed(let problem) = importer.status { problem } else { nil }
    }
}
