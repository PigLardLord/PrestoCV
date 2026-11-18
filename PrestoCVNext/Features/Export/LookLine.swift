import PrestoCVPresentation
import SwiftUI

/// The look of the PDF on a narrow screen (#407): one line, "Design" with the chosen names and Change, so the PDF keeps
/// the room above it. A tap opens the picker in a sheet that stops at half the height, so the PDF stays in view and
/// shows each choice as it is made; at the accessibility text sizes the sheet takes the whole height, as the picker's
/// rows need it.
struct LookLine: View {
    let sheet: ExportSheetViewModel
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var isPicking = false

    var body: some View {
        Button {
            isPicking = true
        } label: {
            label
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("look.title"))
        .accessibilityValue(Text(verbatim: LookName.chosen(sheet.lookPicker, in: locale)))
        .accessibilityHint(Text("look.row.hint"))
        .accessibilityIdentifier("export.look")
        .sheet(isPresented: $isPicking) {
            picker
        }
    }

    /// "Design" and the chosen names, with Change beside them, or under them at the accessibility sizes
    private var label: some View {
        let layout = textSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.small))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: Spacing.small))
        return layout {
            WholeWordsText("look.title")
                .footerTextStyle()
            Text(verbatim: LookName.chosen(sheet.lookPicker, in: locale))
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("look.change")
                .font(.footnote)
                .foregroundStyle(.tint)
        }
        .frame(maxWidth: .infinity, minHeight: TapTarget.minimumHeight, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var picker: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.medium) {
                    LookPicker(sheet: sheet)
                    ExportStatusView(status: sheet.status)
                }
                .padding(Spacing.medium)
            }
            .navigationTitle("look.title")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        isPicking = false
                    } label: {
                        Label("export.done", systemImage: "checkmark")
                    }
                    .accessibilityIdentifier("look.done")
                }
            }
        }
        .presentationDetents(textSize.isAccessibilitySize ? [.large] : [.medium, .large])
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
    }
}
