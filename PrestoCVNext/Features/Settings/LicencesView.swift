import PrestoCVPresentation
import SwiftUI

/// The notices the app ships, each with the name of its licence, and a line under them while none is about the work of
/// others. A notice opens with its text and the text of its licence. Settings reads the notices when it opens.
struct LicencesView: View {
    let licences: LicencesViewModel

    var body: some View {
        content
            .navigationTitle(Text("settings.licences.title"))
            .inlineNavigationTitle()
    }

    @ViewBuilder
    private var content: some View {
        switch licences.state {
        case .loading:
            LoadingView("settings.licences.loading")
        case .failed:
            Form {
                InlineNotice(actionTitle: "settings.licences.retry", actionIdentifier: "settings.licences.retry",
                             action: { Task { await licences.load() } }) {
                    WholeWordsText("settings.licences.failed")
                }
            }
            .formStyle(.grouped)
        case .loaded:
            list
        }
    }

    private var list: some View {
        Form {
            Section {
                ForEach(licences.rows) { row in
                    NavigationLink {
                        if let detail = licences.detail(of: row.id) {
                            LicenceDetailView(detail: detail)
                        }
                    } label: {
                        VStack(alignment: .leading) {
                            Text(verbatim: row.title)
                            Text(verbatim: row.licenceName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("settings.licences.row.\(row.id)")
                }
            } footer: {
                if licences.othersState == .noOthers {
                    Text("settings.licences.noOthers")
                        .accessibilityIdentifier("settings.licences.noOthers")
                }
            }
        }
        .formStyle(.grouped)
    }
}

/// One notice and the text of its licence, a paragraph to an element, so VoiceOver moves by paragraph and by heading.
/// The texts stay in English in every language of the app, since a translation is not the licence. VoiceOver reads them
/// in the voice of the app's language: SwiftUI offers no speech language for a text without UIKit, a known limit.
private struct LicenceDetailView: View {
    let detail: LicenceDetail

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.medium) {
                heading("settings.licences.notice")
                paragraphs(detail.noticeParagraphs)
                heading("settings.licences.text")
                paragraphs(detail.licenceParagraphs)
            }
            .padding(Spacing.medium)
            .readableWidth()
        }
        .navigationTitle(Text(verbatim: detail.title))
        .inlineNavigationTitle()
    }

    private func heading(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.headline)
            .accessibilityAddTraits(.isHeader)
    }

    private func paragraphs(_ paragraphs: [String]) -> some View {
        ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
            Text(verbatim: paragraph)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }
}
