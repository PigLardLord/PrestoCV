import PrestoCVPresentation
import SwiftUI

/// The ways to start a CV, as the view model gives them: the import when it is offered, the examples, then blank. The
/// examples are one way here, which opens them in a sheet. The first run shows the ways below its welcome, "+" in the
/// sidebar in a sheet of its own.
struct StartChoicesView: View {
    let firstRun: FirstRunViewModel
    /// Opens what the person chose, once the examples sheet has closed.
    let choose: (StartChoice) -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var showingExamples = false
    /// The example picked in the sheet, opened when the sheet has closed.
    @State private var pickedExample: ExampleChoice?

    var body: some View {
        let isDense = Self.isDense(dynamicTypeSize, verticalSizeClass)
        VStack(spacing: isDense ? Spacing.small : Spacing.medium) {
            if firstRun.choices.contains(.importCV) {
                PrimaryButton("start.import") { choose(.importCV) }
                    .accessibilityIdentifier("start.import")
            }
            if !examples.isEmpty {
                ChoiceButton(title: "start.examples", symbol: "doc.text.image", isDense: isDense) { showingExamples = true }
                    .accessibilityIdentifier("start.examples")
            }
            examplesIssue
            ChoiceButton(title: "start.blank", symbol: "doc.badge.plus", isDense: isDense) { choose(.blank) }
                .accessibilityIdentifier("start.blank")
        }
        .sheet(isPresented: $showingExamples, onDismiss: openPickedExample) {
            ExamplesSheet(examples: examples) { example in
                pickedExample = example
                showingExamples = false
            }
        }
    }

    /// The examples among the choices, in their order.
    private var examples: [ExampleChoice] {
        firstRun.choices.compactMap { choice in
            guard case .example(let example) = choice else { return nil }
            return example
        }
    }

    /// Why the examples are missing, where their way to start would be.
    @ViewBuilder
    private var examplesIssue: some View {
        switch firstRun.examplesIssue {
        case .unavailable?:
            issueLine("start.examples.unavailable")
        case .failed?:
            issueLine("start.examples.failed")
        case nil:
            EmptyView()
        }
    }

    private func issueLine(_ text: LocalizedStringResource) -> some View {
        WholeWordsText(text)
            .footerTextStyle()
            .multilineTextAlignment(.center)
            .accessibilityIdentifier("start.examples.issue")
    }

    private func openPickedExample() {
        guard let pickedExample else { return }
        self.pickedExample = nil
        choose(.example(pickedExample))
    }
}

extension StartChoicesView {
    /// At the accessibility text sizes and in compact height, an iPhone on its side, the ways to start sit closer
    /// together, without symbols, and come before a welcome, so that each can be tapped without scrolling past it.
    static func isDense(_ dynamicTypeSize: DynamicTypeSize, _ verticalSizeClass: UserInterfaceSizeClass?) -> Bool {
        dynamicTypeSize.isAccessibilitySize || verticalSizeClass == .compact
    }
}

/// A way to start that is not the main one: bordered, at least as tall as the smallest tap target, with its symbol
/// unless the choices are dense.
private struct ChoiceButton: View {
    let title: LocalizedStringResource
    /// The name of a system symbol
    let symbol: String
    let isDense: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.small) {
                if !isDense {
                    Image(systemName: symbol)
                        .accessibilityHidden(true)
                }
                WholeWordsText(title)
            }
            .frame(maxWidth: .infinity, minHeight: TapTarget.minimumHeight)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: CornerRadius.control))
        .controlSize(.large)
    }
}
