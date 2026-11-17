import PrestoCVPresentation
import SwiftUI

/// The line of a row that opens on a page of its own: what the row is, and under it its years and its other texts; a
/// language's level on the right, under the texts at the accessibility sizes; a chevron. A tap opens the page. A row whose
/// fields name nothing shows what a row of its section with no name is called.
struct EntryRow: View {
    let section: EditorSection
    let summary: EntrySummary
    /// What the row is called where the person must tell it from the others.
    let name: String
    let action: () -> Void
    @Environment(\.dynamicTypeSize) private var textSize

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.small) {
                let layout = textSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.small))
                    : AnyLayout(HStackLayout(alignment: .center, spacing: Spacing.small))
                layout {
                    texts
                    if let level = summary.level {
                        ProficiencyPicker.words(of: level)
                            .foregroundStyle(.secondary)
                    }
                }
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: TapTarget.minimumHeight, alignment: .leading)
            .contentShape(Rectangle())
        }
        .accessibilityIdentifier("editor.entry.\(section)")
    }

    private var texts: some View {
        VStack(alignment: .leading) {
            Text(title)
                .foregroundStyle(.primary)
            if let line {
                Text(line)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var title: String {
        summary.title.isEmpty ? name : summary.title.joined(separator: " · ")
    }

    /// The years and the other texts, together; nil when the row gives none.
    private var line: String? {
        let parts = [summary.years.map(Self.words(of:))].compactMap { $0 } + summary.details
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// The years as the person reads them (R13).
    private static func words(of years: EntryYears) -> String {
        switch years {
        case .span(let from, let to): "\(from) – \(to)"
        case .ongoing(let since): String(localized: "editor.entry.since \(since)")
        case .year(let year): year
        }
    }
}

/// A group of an entry's fields: a section on the entry's page, with its title when it has one; in the form, where the
/// entry's fields stand together, only the fields.
struct EntryGroup<Content: View>: View {
    let onPage: Bool
    var title: LocalizedStringResource?
    @ViewBuilder let content: Content

    var body: some View {
        if !onPage {
            content
        } else if let title {
            Section {
                content
            } header: {
                Text(title)
            }
        } else {
            Section {
                content
            }
        }
    }
}
