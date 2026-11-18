import SwiftUI
import PrestoCVPresentation

/// The language of the PDF's headings, and the way to change it (#407): "Headings in English", then Change, which lists
/// the languages the sheet offers with the one in use marked. The choice goes to the sheet, which keeps it in the CV, and
/// VoiceOver tells the row's sentence again for each pick. A line under them says the person's text is not translated.
/// Until the sheet has read the CV, the same lines stand unseen in the app's language, so that what stands below does
/// not move when they appear.
struct HeadingsLanguageLine: View {
    let sheet: ExportSheetViewModel
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var textSize

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .announce(sheet.languageToAnnounce) { chosen in
                let name = LanguageName.inSentence(chosen.language.tag, in: locale)
                return "export.headings \(name)"
            }
    }

    @ViewBuilder
    private var content: some View {
        if let language = sheet.effectiveLanguage {
            let name = LanguageName.inSentence(language.tag, in: locale)
            lines(named: name) { change(language, named: name) }
        } else {
            lines(named: LanguageName.appLanguage(in: locale)) {
                changeLabel
            }
            .hidden()
            .accessibilityHidden(true)
        }
    }

    /// "Headings in …" with Change beside it, or under it at the accessibility sizes, then the line on the person's text
    private func lines(named name: String, @ViewBuilder change: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            let layout = textSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.small))
                : AnyLayout(HStackLayout(alignment: .center, spacing: Spacing.small))
            layout {
                WholeWordsText("export.headings \(name)")
                    .footerTextStyle()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("export.headings")
                change()
            }
            WholeWordsText("export.headings.notTranslated")
                .footerTextStyle()
                .accessibilityIdentifier("export.headings.notTranslated")
        }
    }

    /// Change: a menu of the offered languages, the one in use marked. Picking one hands it to the sheet, which keeps it
    /// as the CV's language.
    private func change(_ language: ExportLanguage, named name: String) -> some View {
        Menu {
            Section {
                Picker(selection: Binding(get: { language }, set: { sheet.select(language: $0) })) {
                    ForEach(sheet.offeredLanguages, id: \.self) { offered in
                        Text(verbatim: LanguageName.alone(offered.tag, in: locale)).tag(offered)
                    }
                } label: {
                    Text("export.headings.menu")
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("export.headings.menu")
            }
        } label: {
            changeLabel
        }
        .accessibilityLabel(Text("export.headings.change.label"))
        .accessibilityValue(Text(verbatim: name))
        .accessibilityHint(Text("export.headings.change.hint"))
        .accessibilityInputLabels([Text("export.headings.change"), Text("export.headings.change.label")])
        .accessibilityIdentifier("export.headings.change")
    }

    /// The word Change, a tap target high and at least as wide
    private var changeLabel: some View {
        Text("export.headings.change")
            .font(.footnote)
            .frame(minWidth: TapTarget.minimumHeight, minHeight: TapTarget.minimumHeight)
            .contentShape(Rectangle())
    }
}
