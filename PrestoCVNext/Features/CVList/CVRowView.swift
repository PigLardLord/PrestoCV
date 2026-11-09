import PrestoCVPresentation
import SwiftUI

/// A row of the list: the label of the CV, the person and the role under it, and the time since the last save. Its
/// actions are in the context menu and among the actions of VoiceOver, in the order the view model gives; a swipe offers
/// some of them. Rename asks for the title in an alert, starting from the stored one; delete asks first and names the CV.
struct CVRowView: View {
    let list: CVListViewModel
    let row: CVRow
    @Environment(\.locale) private var locale
    @State private var renaming = false
    @State private var newTitle = ""
    @State private var deleting = false

    var body: some View {
        content
            .frame(maxWidth: .infinity, minHeight: TapTarget.minimumHeight, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("shell.row")
            .accessibilityActions {
                ForEach(list.rowActions, id: \.self) { action in button(action) }
            }
            .contextMenu {
                ForEach(list.rowActions, id: \.self) { action in button(action) }
            }
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                ForEach(list.leadingSwipeActions, id: \.self) { action in swipeButton(action) }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                ForEach(list.trailingSwipeActions, id: \.self) { action in swipeButton(action) }
            }
            .alert(Text("list.rename.title"), isPresented: $renaming) {
                TextField("list.rename.field", text: $newTitle)
                Button("list.cancel", role: .cancel) {}
                Button("list.action.rename", action: rename)
            }
            .confirmationDialog(Text("list.delete.title \(row.label)"), isPresented: $deleting, titleVisibility: .visible) {
                Button("list.delete.confirm", role: .destructive, action: delete)
                Button("list.cancel", role: .cancel) {}
            } message: {
                Text("list.delete.message")
            }
    }

    private var content: some View {
        VStack(alignment: .leading) {
            Text(verbatim: row.label)
                .font(.body)
            if !row.subtitle.isEmpty {
                Text(verbatim: row.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let lastSaved = row.lastSaved {
                let saved = sinceSaved(lastSaved)
                Text("list.row.saved \(saved)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Actions

    /// The button of an action, for the context menu and for VoiceOver.
    @ViewBuilder
    private func button(_ action: RowAction) -> some View {
        switch action {
        case .duplicate:
            Button(action: duplicate) { Label("list.action.duplicate", systemImage: "plus.square.on.square") }
        case .rename:
            Button(action: startRenaming) { Label("list.action.rename", systemImage: "pencil") }
        case .delete:
            Button(role: .destructive) { deleting = true } label: { Label("list.action.delete", systemImage: "trash") }
        }
    }

    /// The button of an action in a swipe. Delete has no destructive role there: the list would take the row away before
    /// the person confirms.
    @ViewBuilder
    private func swipeButton(_ action: RowAction) -> some View {
        switch action {
        case .delete:
            Button { deleting = true } label: { Label("list.action.delete", systemImage: "trash") }
                .tint(.red)
        case .duplicate, .rename:
            button(action)
                .tint(.accentColor)
        }
    }

    /// The copy is named after the label of the row, in the language the app shows (R13).
    private func duplicate() {
        let title = String(localized: "list.copy.title \(row.label)")
        Task { await list.duplicate(row.reference, title: title) }
    }

    private func startRenaming() {
        newTitle = row.title
        renaming = true
    }

    private func rename() {
        let title = newTitle
        Task { await list.rename(row.reference, to: title) }
    }

    private func delete() {
        Task { await list.delete(row.reference) }
    }

    /// "2 days ago", from the moment the list last read the time.
    private func sinceSaved(_ lastSaved: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.dateTimeStyle = .named
        formatter.formattingContext = .middleOfSentence
        return formatter.localizedString(for: lastSaved, relativeTo: list.now)
    }
}
