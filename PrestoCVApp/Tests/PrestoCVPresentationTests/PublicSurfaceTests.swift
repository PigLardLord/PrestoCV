// This file imports nothing of the domain or the application layer, and not `@testable`: what it uses is what a view sees.
import Foundation
import Testing
import PrestoCVPresentation

/// Every public member of the editor, each with its type spelled out. It compiles only while each type is the
/// presentation's own: a domain type in the public surface breaks it.
@MainActor
func useEveryPublicMember(of editor: EditorViewModel) async {
    let content: EditorContent = editor.content
    editor.content = content
    let _: OpeningStatus = editor.opening
    let _: SaveStatus = editor.saveStatus
    let _: EditorAnnouncement? = editor.announcement
    let _: Bool = editor.isSavedOnThisDevice
    let _: Bool = editor.isReplacing
    let _: String? = editor.documentLanguage
    let _: EditorLook? = editor.look
    let rows: [ExperienceRow] = content.experiences
    let _: [EducationRow] = content.education
    let _: [SkillRow] = content.skills
    let _: [LanguageRow] = content.languages
    let _: [CertificationRow] = content.certifications
    let _: [ProfileRow] = content.profiles
    let _: [InterestRow] = content.interests
    _ = rows
    let periods: [PeriodParts] = content.experiences.map(\.period) + content.education.map(\.period)
    let dates: [DateParts] = periods.flatMap { [$0.start, $0.end] } + content.certifications.map(\.issued)
    let _: [Bool] = periods.map(\.isCurrent) + periods.map(\.asksForEnd)
    let _: [String] = dates.map(\.year)
    let _: [Int?] = dates.map(\.month)
    let _: [RowName] = content.experiences.map(\.rowName) + content.education.map(\.rowName)
        + content.skills.map(\.rowName) + content.languages.map(\.rowName) + content.certifications.map(\.rowName)
        + content.profiles.map(\.rowName) + content.interests.map(\.rowName)
    let summaries: [EntrySummary] = content.experiences.map(\.summary) + content.education.map(\.summary)
        + content.languages.map(\.summary) + content.certifications.map(\.summary) + content.profiles.map(\.summary)
    let _: [[String]] = summaries.map(\.title) + summaries.map(\.details)
    let _: [String?] = summaries.map(\.level)
    for years in summaries.compactMap(\.years) {
        switch years {
        case .span(let from, let to): _ = [from, to]
        case .ongoing(let since): _ = since
        case .year(let year): _ = year
        }
    }
    let _: [RowID] = ids(content.experiences) + ids(content.education) + ids(content.skills) + ids(content.languages)
        + ids(content.certifications) + ids(content.profiles) + ids(content.interests)
    if let shown = content.interests.first {
        let row: InterestRow = editor.content.interests[row: shown.id, or: shown]
        editor.content.interests[row: shown.id, or: shown] = row
        let _: InterestRow? = editor.content.interests[row: shown.id]
    }
    if let removal: RowRemoval = editor.pendingRemoval {
        switch removal.name {
        case .text(let text): _ = text
        case .placeholder(let section): _ = section
        }
    }
    let _: [Int] = EditorChoices.skillLevels
    let _: [String] = EditorChoices.proficiencies
    let _: [Int] = EditorChoices.months
    editor.fieldWasLeft(.email)
    let problems: [FieldProblem] = editor.problems
    for problem in problems {
        let _: RowID? = problem.row
        let _: EditorField = problem.field
        switch problem.code {
        case .unreadable, .endBeforeStart: break
        }
    }
    let _: FieldProblem.Code? = editor.problem(of: .email)
    if let told = editor.announcement {
        let _: SaveStatus? = told.status
        let _: [FieldProblem] = told.problems
        editor.announcementWasTold(told)
    }
    if let row = rows.first {
        editor.fieldWasLeft(.experiencePeriod, row: row.id)
        let _: FieldProblem.Code? = editor.problem(of: .experiencePeriod, row: row.id)
    }
    let _: FieldInput = EditorField.email.input
    let _: EditorField? = EditorField.title.nextDetail
    switch FieldEntry("a", after: "", in: .title) {
    case .text(let text): _ = text
    case .returnKey(let next): let _: EditorField? = next
    }
    var entries = FieldEntries()
    let _: FieldEntry = entries.entry("a", after: "", in: .title)
    editor.addRow(to: .skills)
    let _: RowID? = editor.addedRow
    editor.rowWasShown()
    let added: RowID = editor.content.skills[0].id
    editor.removeRow(in: .skills, id: added)
    editor.confirmRemoval()
    editor.cancelRemoval()
    let _: Bool = editor.canMoveRow(in: .skills, id: added, by: -1)
    let _: Bool = editor.canReorderRows(in: .skills)
    let _: Bool = editor.reordersRows
    editor.moveRow(in: .skills, id: added, by: 1)
    editor.moveRows(in: .skills, from: IndexSet(integer: 0), to: 1)
    editor.layoutChanged(isNarrow: true)
    let _: Bool = editor.showsOnAPage(.experiences)
    let _: Bool = editor.showsMoveHint(in: .experiences)
    editor.openEntry(in: .skills, id: added)
    if let entry: EditorEntry = editor.openedEntry {
        let _: EditorSection = entry.section
        let _: RowID = entry.row
    }
    let _: Bool = editor.asksToRemove(row: added, onItsPage: true)
    editor.closeEntry()
    await editor.load()
    await editor.saveNow()
    await editor.reload()
    await editor.saveAsCopy()
    let tag: String? = nil
    await editor.setDocumentLanguage(tag)
    let parts: Set<LookPart> = [.design]
    await editor.changeLook(to: EditorLook(design: "classic", palette: nil, fonts: nil), parts: parts)
    let _: ExportSnapshot? = editor.exportSnapshot()
}

/// The ids of rows that a view's `ForEach` lists by their ids.
func ids<Row: Identifiable>(_ rows: [Row]) -> [RowID] where Row.ID == RowID {
    rows.map(\.id)
}

/// Every value a status can take, with a field or a section where it has one. The switches break when a case is added,
/// so that it is added here too.
func everySaveStatus() -> [SaveStatus] {
    let all: [SaveStatus] = [.saved, .pending, .saving, .notEnoughContent, .tooLarge, .conflict, .deletedElsewhere, .failed]
        + EditorField.allCases.flatMap { [SaveStatus.textTooLong($0), .unreadable($0)] }
        + EditorSection.allCases.map(SaveStatus.tooManyEntries)
    for status in all {
        switch status {
        case .saved, .pending, .saving, .notEnoughContent, .textTooLong, .tooManyEntries, .tooLarge, .unreadable, .conflict,
             .deletedElsewhere, .failed:
            break
        }
    }
    return all
}

func everyExportStatus() -> [ExportStatus] {
    let all: [ExportStatus] = [.idle, .exporting, .done(pages: 1), .truncated(pages: 1, required: 2), .languageNeeded,
                               .notReady, .unsupportedLanguage, .invalid, .incomplete(missing: 1),
                               .textNotVisible(lines: 1), .failed]
    for status in all {
        switch status {
        case .idle, .exporting, .done, .truncated, .languageNeeded, .notReady, .unsupportedLanguage, .invalid, .incomplete,
             .textNotVisible, .failed:
            break
        }
    }
    return all
}

/// The strings anywhere inside `value`.
func strings(in value: Any) -> [String] {
    if let text = value as? String { return [text] }
    return Mirror(reflecting: value).children.flatMap { strings(in: $0.value) }
}

@MainActor
@Suite("Editor public surface")
struct PublicSurfaceTests {

    @Test("the public surface holds no domain type: this file uses all of it importing only the presentation")
    func noDomainTypeInThePublicAPI() async {
        let editor = Editing().editor(.blank)

        await useEveryPublicMember(of: editor)

        #expect(editor.opening == .open)
    }

    @Test("statuses are codes: none carries a text")
    func statusesCarryNoText() {
        let opening: [OpeningStatus] = [.opening, .open, .missing, .failed]
        let values: [Any] = everySaveStatus() + everyExportStatus() + opening + FieldInput.allCases

        #expect(values.flatMap { strings(in: $0) }.isEmpty)
        #expect(Set(everySaveStatus()).count == everySaveStatus().count)
    }
}
