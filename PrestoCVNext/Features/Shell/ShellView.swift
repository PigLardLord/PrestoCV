import PrestoCVPresentation
import SwiftUI

/// The frame of the app: the list of CVs in the first column and the open CV in the detail. On a compact screen it
/// shows one column at a time, the list first. A first run shows the welcome in its place until a draft or the import
/// is open. The models decide what is open, which column shows, whether the welcome shows and whether the open CV may
/// be left; this view binds to them. It shows the export of the open CV in a sheet while the shell holds one. It tells
/// the shell when the scene stops being active, which stores the open CV at once on its way to the background. Over the
/// list it shows what the import of the released app's CVs left out, while the report's model presents it. The gear in
/// the sidebar's bar opens Settings in a sheet.
struct ShellView: View {
    let shell: ShellNavigationModel
    let list: CVListViewModel
    let firstRun: FirstRunViewModel
    let report: LegacyImportReportViewModel
    let settings: SettingsViewModel
    let licences: LicencesViewModel
    let diagnostics: DiagnosticsViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @State private var addingCV = false
    @State private var showingSettings = false
    /// The way to start chosen in the "+" sheet, opened when the sheet has closed.
    @State private var chosenInSheet: StartChoice?

    var body: some View {
        screen
            .task { await firstRun.load() }
            .task { await report.load() }
            .onChange(of: scenePhase) { _, phase in shell.sceneChanged(isActive: phase == .active) }
    }

    @ViewBuilder
    private var screen: some View {
        switch shell.screen(for: firstRun.state) {
        case .loading:
            LoadingView("root.loading")
        case .welcome:
            FirstRunView(firstRun: firstRun, choose: start)
        case .split:
            split
        }
    }

    private var split: some View {
        NavigationSplitView(preferredCompactColumn: column) {
            CVListView(
                list: list, report: report, firstRun: firstRun, selection: selection, choose: start,
                kept: list.keptNotices(shell.keptEditors),
                retryKept: { id in Task { await shell.retryKept(id) } },
                openKept: { id in _ = shell.openKept(id) }
            )
                .toolbar {
                    ToolbarItem(placement: .navigation) {
                        Button { showingSettings = true } label: { Label("settings.open", systemImage: "gearshape") }
                            .accessibilityIdentifier("settings.open")
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button { addingCV = true } label: { Label("shell.add", systemImage: "plus") }
                            .accessibilityIdentifier("shell.add")
                    }
                }
        } detail: {
            // A destination pushes only inside a stack: in a detail column without one, it replaces the column
            NavigationStack {
                detail
            }
        }
        .onChange(of: list.rows) { _, rows in shell.reconcile(with: rows) }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $addingCV, onDismiss: startChosenInSheet) {
            NewCVSheet(firstRun: firstRun) { choice in
                chosenInSheet = choice
                addingCV = false
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(settings: settings, licences: licences, diagnostics: diagnostics)
        }
        .sheet(item: exportSheet) { sheet in
            ExportSheetView(sheet: sheet, close: { shell.closeExport() })
        }
        .sheet(isPresented: reportShown) {
            LegacyImportReportView(report: report)
        }
        // Here and not in the sheet, which has closed by the time the old copies are all removed
        .announce(report.state) { LegacyImportReportView.announcement(of: $0) }
    }

    /// The import report while its model presents it. A swipe down closes it as Not now does; it never confirms.
    private var reportShown: Binding<Bool> {
        Binding(
            get: { report.isPresented },
            set: { shown in
                if !shown { report.close() }
            }
        )
    }

    /// The export sheet of the open CV. A swipe down closes it as Close does, which stops an export that runs.
    private var exportSheet: Binding<ExportSheetViewModel?> {
        Binding(
            get: { shell.exportSheet },
            set: { sheet in
                if sheet == nil { shell.closeExport() }
            }
        )
    }

    /// The review's sheet while it is open. A swipe down closes it as Done does; it closes too when the review goes, with
    /// the editor.
    private var reviewSheet: Binding<ImportReviewViewModel?> {
        Binding(
            get: { shell.reviewSheet },
            set: { review in
                if review == nil { shell.review?.closeSheet() }
            }
        )
    }

    /// The open CV's editor, a new one for each CV opened, at the root of the detail's stack, so the page of a row
    /// opens on top of it. While its text cannot be stored, Back is hidden (which also stops the swipe), so the person
    /// answers the status first: the notice above the form offers the ways out, and "Discard" closes the editor without
    /// storing its text. The draft of an import shows its review, and the review's sheet opens over the editor, not
    /// over the split, where the export sheet is. In its place, the import while the shell holds one; the shell hears of each change of its
    /// status, and opens the draft of an import that is ready.
    @ViewBuilder
    private var detail: some View {
        if let editor = shell.editor {
            EditorView(editor: editor, title: title(of: editor), review: shell.review, export: { shell.openExport() },
                       discard: { shell.discardEditor() })
                .id(ObjectIdentifier(editor))
                .navigationBarBackButtonHidden(!shell.canLeave)
                .sheet(item: reviewSheet) { review in
                    ImportReviewSheet(review: review)
                }
        } else if let importer = shell.importer {
            ImportView(importer: importer)
                .id(ObjectIdentifier(importer))
                .onChange(of: importer.status) { shell.importStatusChanged() }
        } else {
            DetailPlaceholderView()
        }
    }

    /// The open CV's name as the list shows it, or "New CV" for a draft. A stored CV whose row has gone keeps the name it
    /// has in the editor.
    private func title(of editor: EditorViewModel) -> Text {
        switch shell.detail {
        case .stored?:
            shell.selectedRow(in: list.rows).map { Text(verbatim: $0.label) } ?? Text(verbatim: editor.content.title)
        case .draft?, .blank?, nil:
            Text("shell.draft.title")
        }
    }

    /// Goes where a way to start leads: the draft it gives, or the import.
    private func start(_ choice: StartChoice) {
        shell.start(at: firstRun.start(choice))
    }

    private func startChosenInSheet() {
        guard let chosenInSheet else { return }
        self.chosenInSheet = nil
        start(chosenInSheet)
    }

    /// The system selects a row, and clears the selection when the person goes back. The model may keep the open CV (its
    /// text cannot be stored yet); the selection then stays on it.
    private var selection: Binding<CVReference?> {
        Binding(
            get: { shell.selection },
            set: { reference in
                if let reference { shell.open(.stored(reference)) } else { shell.deselect() }
            }
        )
    }

    /// Going back to the list closes the open CV, when one column shows at a time (a compact width). The system also
    /// writes the sidebar while it changes between one column and two, which is not the person going back.
    private var column: Binding<NavigationSplitViewColumn> {
        Binding(
            get: { shell.preferredColumn == .detail ? .detail : .sidebar },
            set: { column in
                shell.columnChanged(to: column == .sidebar ? .sidebar : .detail, isCollapsed: horizontalSizeClass == .compact)
            }
        )
    }
}
