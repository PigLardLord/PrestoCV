import PrestoCVPresentation
import SwiftUI

/// The examples to start from, each with its title and the first lines of its summary, which tell two examples apart. A
/// footer says that the names and details in them are invented.
struct ExamplesSheet: View {
    let examples: [ExampleChoice]
    /// The person picked an example; the presenter closes the sheet.
    let pick: (ExampleChoice) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(examples, id: \.self) { example in
                        Button { pick(example) } label: { row(of: example) }
                            .accessibilityIdentifier("examples.row")
                    }
                } footer: {
                    Text("examples.footer")
                        .footerTextStyle()
                        .accessibilityIdentifier("examples.footer")
                }
            }
            .navigationTitle(Text("examples.title"))
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("start.cancel") { dismiss() }
                        .accessibilityIdentifier("examples.cancel")
                }
            }
        }
    }

    private func row(of example: ExampleChoice) -> some View {
        VStack(alignment: .leading, spacing: Spacing.small / 2) {
            Text(verbatim: example.title)
                .font(.headline)
                .foregroundStyle(.primary)
            Text(verbatim: example.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
    }
}
