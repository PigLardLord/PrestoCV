import PrestoCVPresentation
import SwiftUI

/// What the import of the released app's CVs left out, in a sheet over the list: the CVs that lost details, those that
/// keep details for the person to check, the CVs not imported by cause, and Confirm, which removes the old copies. Not now
/// keeps them; with "Don't remind me again" the sheet does not come back. The view model decides what shows and when; this
/// view picks the words. At the accessibility sizes Confirm is the last item of the scroll, so it never fills the screen.
struct LegacyImportReportView: View {
    @Bindable var report: LegacyImportReportViewModel
    @Environment(\.dynamicTypeSize) private var textSize
    @Environment(\.locale) private var locale
    @AccessibilityFocusState private var titleFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.large) {
                    ScreenTitle("legacyImport.title")
                        .frame(maxWidth: .infinity)
                        .accessibilityFocused($titleFocused)
                    leftOut
                    toCheck
                    notImported
                    choice
                    if textSize.isAccessibilitySize {
                        actions
                    }
                }
                .padding(Spacing.medium)
                .readableWidth()
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaInset(edge: .bottom) {
                if !textSize.isAccessibilitySize {
                    actions
                        .padding(Spacing.medium)
                        .readableWidth()
                        .background(.bar)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    notNow
                }
            }
        }
        .accessibilityIdentifier("legacyImport.sheet")
        .interactiveDismissDisabled(report.isBusy)
        .presentationSizing(.form)
        // The sheet opens over the list at launch: VoiceOver starts from its heading
        .task { titleFocused = true }
    }

    // MARK: Groups

    @ViewBuilder
    private var leftOut: some View {
        if !report.leftOut.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                WholeWordsText("legacyImport.summary \(report.leftOut.count)")
                header("legacyImport.header.leftOut")
                ForEach(report.leftOut) { row in
                    reportRow(row) { name, details in Text("legacyImport.row.label \(name) \(details)") }
                }
            }
        }
    }

    @ViewBuilder
    private var toCheck: some View {
        if !report.toCheck.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                header("legacyImport.header.toCheck")
                WholeWordsText("legacyImport.toCheck.note")
                    .footerTextStyle()
                ForEach(report.toCheck) { row in
                    reportRow(row) { name, details in Text("legacyImport.row.toCheck \(name) \(details)") }
                }
            }
        }
    }

    @ViewBuilder
    private var notImported: some View {
        if !report.notImported.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                header("legacyImport.header.failed")
                LegacyNotImportedLines(report: report)
            }
        }
    }

    private func header(_ key: LocalizedStringResource) -> some View {
        WholeWordsText(key)
            .font(.title3.bold())
            .accessibilityAddTraits(.isHeader)
    }

    /// The CV's name as the list shows it, then one line per detail. VoiceOver reads the row as one element: the name, then
    /// the details as a list in the screen's language.
    private func reportRow(_ row: LegacyReportRow, label: (String, String) -> Text) -> some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text(verbatim: row.label)
                .font(.headline)
            ForEach(row.details, id: \.self) { detail in
                WholeWordsText(Self.name(of: detail))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label(row.label, details(of: row)))
        .accessibilityIdentifier("legacyImport.row")
    }

    private func details(of row: LegacyReportRow) -> String {
        row.details.map { detail in
            var name = Self.name(of: detail)
            name.locale = locale
            return String(localized: name)
        }
        .formatted(.list(type: .and).locale(locale))
    }

    // MARK: Choice and actions

    /// The footer and the check, while the person has not chosen.
    @ViewBuilder
    private var choice: some View {
        switch report.state {
        case .review, .removing:
            VStack(alignment: .leading, spacing: Spacing.medium) {
                WholeWordsText("legacyImport.footer")
                    .footerTextStyle()
                Toggle(isOn: $report.remindsNoMore) {
                    WholeWordsText("legacyImport.remindNoMore")
                }
                .frame(minHeight: TapTarget.minimumHeight)
                .disabled(report.isBusy)
                .accessibilityIdentifier("legacyImport.remindNoMore")
            }
        case .hidden, .removed, .keptSome:
            EmptyView()
        }
    }

    @ViewBuilder
    private var actions: some View {
        switch report.state {
        case .review:
            PrimaryButton("legacyImport.confirm") { Task { await report.confirm() } }
                .accessibilityHint(Text("legacyImport.confirm.hint"))
                .accessibilityIdentifier("legacyImport.confirm")
        case .removing:
            HStack(spacing: Spacing.small) {
                ProgressView()
                WholeWordsText("legacyImport.removing")
            }
            .frame(maxWidth: .infinity, minHeight: TapTarget.minimumHeight)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("legacyImport.removing")
        case .keptSome(let count):
            VStack(alignment: .leading, spacing: Spacing.medium) {
                WholeWordsText(Self.kept(count))
                    .accessibilityIdentifier("legacyImport.result")
                PrimaryButton("legacyImport.done") { report.close() }
                    .accessibilityIdentifier("legacyImport.done")
            }
        case .hidden, .removed:
            EmptyView()
        }
    }

    /// Not now, while the person has not chosen; disabled while the old copies are removed.
    @ViewBuilder
    private var notNow: some View {
        switch report.state {
        case .review, .removing:
            Button("legacyImport.notNow") { report.close() }
                .disabled(report.isBusy)
                .accessibilityIdentifier("legacyImport.notNow")
        case .hidden, .removed, .keptSome:
            EmptyView()
        }
    }

    // MARK: Words

    /// What VoiceOver says when Confirm has done its work: the sheet closes, or stays on the line of the copies kept.
    static func announcement(of state: LegacyReportState) -> LocalizedStringResource? {
        switch state {
        case .removed: "legacyImport.result.removed"
        case .keptSome(let count): kept(count)
        case .hidden, .review, .removing: nil
        }
    }

    private static func kept(_ count: Int) -> LocalizedStringResource {
        "legacyImport.result.kept \(count)"
    }

    static func name(of detail: LegacyDetail) -> LocalizedStringResource {
        switch detail {
        case .look: "legacyImport.detail.look"
        case .email: "legacyImport.detail.email"
        case .phone: "legacyImport.detail.phone"
        case .website: "legacyImport.detail.website"
        case .skillLevel: "legacyImport.detail.skillLevel"
        case .certificationYear: "legacyImport.detail.certificationYear"
        case .certificationLink: "legacyImport.detail.certificationLink"
        case .profile: "legacyImport.detail.profile"
        case .documentLanguage: "legacyImport.detail.documentLanguage"
        case .period: "legacyImport.detail.period"
        }
    }
}

/// The old CVs the import did not bring in: the count, then one line per cause with what the person can do.
struct LegacyNotImportedLines: View {
    let report: LegacyImportReportViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            WholeWordsText("legacyImport.failed.count \(report.notImportedTotal)")
                .font(.headline)
            ForEach(report.notImported, id: \.self) { line in
                cause(line)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func cause(_ line: NotImportedCount) -> some View {
        switch line.cause {
        case .damaged: WholeWordsText("legacyImport.failed.damaged \(line.count)")
        case .notSaved: WholeWordsText("legacyImport.failed.notSaved \(line.count)")
        }
    }
}
