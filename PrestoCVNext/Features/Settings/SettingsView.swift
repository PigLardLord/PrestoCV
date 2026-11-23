import PrestoCVPresentation
import SwiftUI

/// The Settings sheet: the groups and rows the model gives, in its order. A link row leaves the app for the system's
/// handler, Licences opens inside the sheet, and the values can be selected to quote them. It holds nothing to lose, so
/// Done and a swipe down close it alike. It reads the notices when it opens, so the Licences screen keeps them while a
/// notice is open.
struct SettingsView: View {
    let settings: SettingsViewModel
    let licences: LicencesViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                ForEach(settings.groups, id: \.kind) { group in
                    Section {
                        ForEach(group.rows, id: \.self, content: row)
                    } header: {
                        header(of: group.kind)
                    } footer: {
                        footer(of: group.kind)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(Text("settings.title"))
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("settings.done") { dismiss() }
                        .accessibilityIdentifier("settings.done")
                }
            }
        }
        .task { await licences.load() }
        .presentationSizing(.form)
    }

    private func header(of kind: SettingsGroup.Kind) -> Text {
        switch kind {
        case .support: Text("settings.support.header")
        case .legal: Text("settings.legal.header")
        case .openSource: Text("settings.openSource.header")
        case .about: Text("settings.about.header \(settings.appName)")
        }
    }

    /// The support address under its row, as written, so it can be read and copied with no mail app.
    @ViewBuilder
    private func footer(of kind: SettingsGroup.Kind) -> some View {
        switch kind {
        case .support:
            Text("settings.support.footer \(settings.supportAddress)")
                .textSelection(.enabled)
                .accessibilityIdentifier("settings.support.footer")
        case .legal, .openSource, .about:
            EmptyView()
        }
    }

    @ViewBuilder
    private func row(_ row: SettingsRow) -> some View {
        switch row {
        case .contactSupport(let address):
            LinkRow("settings.support.contact", hint: "settings.support.contact.hint", destination: address)
                .accessibilityIdentifier("settings.contactSupport")
        case .privacyPolicy(let page):
            LinkRow("settings.privacy", hint: "settings.privacy.hint", destination: page)
                .accessibilityIdentifier("settings.privacy")
        case .openSourceStatement:
            Text("settings.openSource.statement")
                .accessibilityIdentifier("settings.openSource.statement")
        case .licences:
            NavigationLink { LicencesView(licences: licences) } label: { Text("settings.openSource.licences") }
                .accessibilityIdentifier("settings.licences")
        case .sourceCode(let page):
            LinkRow("settings.openSource.source", hint: "settings.openSource.source.hint", destination: page)
                .accessibilityIdentifier("settings.source")
        case .version(let version):
            ValueRow("settings.about.version", value: version)
                .accessibilityIdentifier("settings.version")
        case .build(let build):
            ValueRow("settings.about.build", value: build)
                .accessibilityIdentifier("settings.build")
        }
    }
}

/// A row that leaves the app: its words in the primary colour and an arrow, where a row that stays in the app has a
/// chevron. The whole row takes the tap.
private struct LinkRow: View {
    private let title: LocalizedStringKey
    private let hint: LocalizedStringKey
    private let destination: URL

    init(_ title: LocalizedStringKey, hint: LocalizedStringKey, destination: URL) {
        self.title = title
        self.hint = hint
        self.destination = destination
    }

    var body: some View {
        Link(destination: destination) {
            HStack(spacing: Spacing.small) {
                Text(title)
                    .foregroundStyle(.primary)
                Spacer(minLength: Spacing.small)
                Image(systemName: "arrow.up.right")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: TapTarget.minimumHeight)
            .contentShape(Rectangle())
        }
        .accessibilityHint(Text(hint))
    }
}

/// A name and its value, read as one element. The value goes under the name at the accessibility sizes, so a long one
/// is never cut.
private struct ValueRow: View {
    private let name: LocalizedStringKey
    private let value: String
    @Environment(\.dynamicTypeSize) private var textSize

    init(_ name: LocalizedStringKey, value: String) {
        self.name = name
        self.value = value
    }

    var body: some View {
        let layout = textSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.small))
            : AnyLayout(HStackLayout(spacing: Spacing.small))
        layout {
            Text(name)
            if !textSize.isAccessibilitySize {
                Spacer(minLength: Spacing.small)
            }
            Text(verbatim: value)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .accessibilityElement(children: .combine)
    }
}
