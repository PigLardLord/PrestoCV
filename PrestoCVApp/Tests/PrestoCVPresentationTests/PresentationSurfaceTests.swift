// This file imports nothing of the domain or the application layer, and not `@testable`: what it uses is what a view sees.
import Testing
import PrestoCVPresentation

/// Every public member of the list, the first run and the look picker, each with its type spelled out. It compiles only
/// while each type is the presentation's own.
@MainActor
func useEveryPublicMember(of list: CVListViewModel, reference: CVReference) async {
    await list.load()
    let rows: [CVRow] = list.rows
    let _: ListStatus = list.status
    let _: Bool = list.isStale
    let _: StoreNotice? = list.notice
    let _: [CVReference: RowStatus] = list.rowStatuses
    let _: ListContent = list.content
    for notice in list.notices as [ListNotice] {
        switch notice {
        case .stale, .failed: break
        case .rowFailure(let failure):
            let _: CVReference = failure.reference
            let _: String = failure.label
            let _: RowStatus = failure.status
            let _: Int = failure.number
            list.dismissRowFailure(failure)
        case .unreadable(let unreadable):
            let _: Int = unreadable.count
            let _: [StoreIssueKind] = unreadable.kinds + unreadable.distinctKinds
        }
    }
    let _: [RowAction] = list.rowActions + list.leadingSwipeActions + list.trailingSwipeActions
    let kept: KeptNotices = list.keptNotices([] as [KeptEditor])
    let under: [CVReference: KeptNotice] = kept.under
    for notice in kept.above + under.values {
        let _: Int = notice.id
        let _: String = notice.label
        let _: SaveStatus = notice.status
        let _: Bool = notice.canRetry
    }
    _ = list.now
    list.refreshNow()
    list.dismissNotice()
    if let row = rows.first {
        let _: CVReference = row.reference
        let _: String = row.label
        let _: String = row.title
        let _: String = row.subtitle
        let _: String? = row.language
        _ = row.lastSaved
    }
    await list.rename(reference, to: "Title")
    await list.duplicate(reference, title: "Title")
    await list.setDocumentLanguage(reference, to: nil)
    await list.delete(reference)
}

@MainActor
func useEveryPublicMember(of firstRun: FirstRunViewModel) async {
    await firstRun.load()
    let _: FirstRunState = firstRun.state
    for entry in firstRun.entries as [StartEntry] {
        let _: String = entry.id
        var choices: [StartChoice] = []
        switch entry {
        case .importCV: choices = [.importCV]
        case .examples(let examples):
            for example in examples {
                let _: String = example.title
                let _: String = example.summary
                choices.append(.example(example))
            }
        case .examplesIssue(let issue): let _: ExamplesIssue = issue
        case .blank: choices = [.blank]
        }
        for choice in choices {
            let destination: StartDestination? = firstRun.start(choice)
            switch destination {
            case .draft(let draft): let _: CVDraft = draft
            case .importCV, nil: break
            }
        }
    }
}

@MainActor
func useEveryPublicMember(of look: LookViewModel) async {
    await look.load()
    let _: LookStatus = look.status
    let _: EditorLook = look.shown
    let _: Set<LookPart> = look.chosen
    let choices: LookChoices = look.choices
    let _: [LookChoice] = choices.designs + choices.palettes + choices.fontSchemes
    look.choose(design: "classic")
    look.choose(palette: nil)
    look.choose(fonts: nil)
    await look.apply()
}

@MainActor
func useEveryPublicMember(of shell: ShellNavigationModel, rows: [CVRow]) async {
    let reference: CVReference? = shell.selection
    let column: ShellColumn = shell.preferredColumn
    switch column { case .sidebar, .detail: break }
    var verdicts: [LeaveVerdict] = []
    if let row = rows.first { verdicts.append(shell.open(.stored(row.reference))) }
    let detail: EditorStart? = shell.detail
    let editor: EditorViewModel? = shell.editor
    let screen: ShellScreen = shell.screen(for: .firstRun)
    switch screen { case .loading, .welcome, .split: break }
    let _: Bool = shell.canLeave
    let _: CVRow? = shell.selectedRow(in: rows)
    shell.reconcile(with: rows)
    shell.sceneChanged(isActive: false)
    shell.sceneChanged(isActive: true)
    for kept in shell.keptEditors as [KeptEditor] {
        let _: Int = kept.id
        let _: CVReference? = kept.reference
        let _: SaveStatus = kept.status
        let _: Bool = kept.canRetry
        await shell.retryKept(kept.id)
        verdicts.append(shell.openKept(kept.id))
    }
    shell.columnChanged(to: .detail, isCollapsed: true)
    verdicts.append(shell.deselect())
    shell.discardEditor()
    for verdict in verdicts {
        switch verdict {
        case .left: break
        case .stayed(let status): let _: SaveStatus = status
        }
    }
    _ = (reference, detail, editor)
}

func everyListCode() -> [Any] {
    let status: [ListStatus] = [.loading, .loaded, .failed]
    let rows: [RowStatus] = [.conflict, .gone, .tooLarge, .failed]
    let kinds: [StoreIssueKind] = [.corrupt, .upgradeRequired, .unreadable, .tooLarge, .quarantineFailed]
    let first: [FirstRunState] = [.loading, .firstRun, .returning, .failed]
    let examples: [ExamplesIssue] = [.unavailable, .failed]
    let look: [LookStatus] = [.loading, .ready, .applying, .applied, .missing, .conflict, .failed]
    let screens: [ShellScreen] = [.loading, .welcome, .split]
    let contents: [ListContent] = [.loading, .empty, .rows]
    let notices: [ListNotice] = [.stale, .failed]
    let actions: [RowAction] = [.duplicate, .rename, .delete]
    for value in contents { switch value { case .loading, .empty, .rows: break } }
    for value in notices { switch value { case .stale, .failed, .unreadable, .rowFailure: break } }
    for value in actions { switch value { case .duplicate, .rename, .delete: break } }
    for value in status { switch value { case .loading, .loaded, .failed: break } }
    for value in rows { switch value { case .conflict, .gone, .tooLarge, .failed: break } }
    for value in kinds { switch value { case .corrupt, .upgradeRequired, .unreadable, .tooLarge, .quarantineFailed: break } }
    for value in first { switch value { case .loading, .firstRun, .returning, .failed: break } }
    for value in examples { switch value { case .unavailable, .failed: break } }
    for value in look { switch value { case .loading, .ready, .applying, .applied, .missing, .conflict, .failed: break } }
    var all: [Any] = []
    status.forEach { all.append($0) }
    rows.forEach { all.append($0) }
    kinds.forEach { all.append($0) }
    first.forEach { all.append($0) }
    examples.forEach { all.append($0) }
    look.forEach { all.append($0) }
    screens.forEach { all.append($0) }
    contents.forEach { all.append($0) }
    notices.forEach { all.append($0) }
    actions.forEach { all.append($0) }
    all.append(StartChoice.importCV)
    all.append(StartChoice.blank)
    return all
}

@MainActor
@Suite("List, first run and look public surface")
struct PresentationSurfaceTests {

    @Test("the public surface holds no domain type: this file uses all of it importing only the presentation")
    func noDomainTypeInTheListFirstRunAndLookAPI() async throws {
        let world = Browsing()
        let cv = try await world.stored(title: "Backend")
        let list = world.list()

        await useEveryPublicMember(of: list, reference: world.reference(cv))
        await useEveryPublicMember(of: world.firstRun())
        await useEveryPublicMember(of: world.look(of: world.editing.new()))
        await useEveryPublicMember(of: Editing().shell(), rows: list.rows)

        #expect(list.status == .loaded)
    }

    @Test("statuses and notices are codes: none carries a text")
    func codesCarryNoText() {
        let notice = StoreNotice(kinds: [.corrupt, .unreadable])

        #expect(everyListCode().flatMap { strings(in: $0) }.isEmpty)
        #expect(strings(in: notice).isEmpty)
    }
}
