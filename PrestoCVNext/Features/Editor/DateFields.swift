import PrestoCVPresentation
import SwiftUI

/// The period of a job or a study: its start, whether it goes on, and its end, which shows only while it does not. A
/// note under it says why the period is not stored, once the editor names a problem; VoiceOver reads the note with each
/// of its controls. Its identifiers are the field's, followed by `.start`, `.current` and `.end`: a date's month menu is a
/// button and its year a text field.
struct PeriodField: View {
    @Binding var period: PeriodParts
    let field: EditorField
    /// What the switch says: a job and a study go on in different words.
    let current: LocalizedStringResource
    let problem: FieldProblem.Code?
    let row: RowID
    let focus: FocusState<RowFocus?>.Binding
    /// Told after the person picks a month: the pick is their last word on that date.
    let picked: () -> Void

    var body: some View {
        let note = noteWords(of: problem, unreadable: "editor.note.period")
        VStack(alignment: .leading, spacing: Spacing.medium) {
            DateField(
                date: $period.start, month: "editor.period.startMonth", year: "editor.period.startYear", focus: focus,
                name: RowFocus(row: row, field: field), picked: picked
            )
            .accessibilityIdentifier("editor.field.\(field).start")
            Toggle(isOn: $period.isCurrent) { Text(current) }
                .frame(minHeight: TapTarget.minimumHeight)
                .accessibilityIdentifier("editor.field.\(field).current")
            if period.asksForEnd {
                DateField(
                    date: $period.end, month: "editor.period.endMonth", year: "editor.period.endYear", focus: focus,
                    name: RowFocus(row: row, field: field, isEnd: true), picked: picked
                )
                .accessibilityIdentifier("editor.field.\(field).end")
            }
            if let note {
                FieldNote(note)
            }
        }
        .groupNote(note)
    }
}

/// The date a certification was issued, with the note under it once the editor names a problem. Its identifier is the
/// field's: the month menu is a button and the year a text field.
struct IssuedField: View {
    @Binding var date: DateParts
    let problem: FieldProblem.Code?
    let row: RowID
    let focus: FocusState<RowFocus?>.Binding
    /// Told after the person picks a month: the pick is their last word on that date.
    let picked: () -> Void

    var body: some View {
        let note = noteWords(of: problem, unreadable: "editor.note.issued")
        VStack(alignment: .leading, spacing: Spacing.small) {
            DateField(
                date: $date, month: "editor.field.month", year: "editor.field.year", focus: focus,
                name: RowFocus(row: row, field: .certificationIssued), picked: picked
            )
            if let note {
                FieldNote(note)
            }
        }
        .groupNote(note)
        .accessibilityIdentifier("editor.field.certificationIssued")
    }
}

/// A date: a menu of the months, "no month" first, and the year, typed on the number pad. The months are named in the
/// person's language, in the Gregorian calendar the CV keeps; month and year stand in the order of the person's locale,
/// side by side, and one under the other at the accessibility sizes.
private struct DateField: View {
    @Binding var date: DateParts
    let month: LocalizedStringResource
    let year: LocalizedStringResource
    let focus: FocusState<RowFocus?>.Binding
    let name: RowFocus
    /// Told after the person picks a month, never when the editor changes the date itself.
    let picked: () -> Void
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var textSize

    var body: some View {
        let layout = textSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.medium))
            : AnyLayout(HStackLayout(alignment: .top, spacing: Spacing.medium))
        layout {
            if MonthOrder.monthBeforeYear(in: locale) {
                monthMenu
                yearField
            } else {
                yearField
                monthMenu
            }
        }
    }

    private var monthMenu: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            FieldLabel(month)
            Picker(selection: pickedMonth) {
                Text("editor.date.noMonth").tag(Int?.none)
                ForEach(EditorChoices.months, id: \.self) { number in
                    Text(verbatim: monthNames[number - 1]).tag(Int?.some(number))
                }
            } label: {
                Text(month)
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(minHeight: TapTarget.minimumHeight)
        }
    }

    /// The month as the person picks it: the menu closes on the pick, so the pick leaves the date, and the editor may name
    /// a problem with it.
    private var pickedMonth: Binding<Int?> {
        Binding {
            date.month
        } set: { month in
            date.month = month
            picked()
        }
    }

    private var yearField: some View {
        LabeledField(year, text: $date.year, focus: focus, as: name)
            .fieldInput(.year)
    }

    /// The names of the months, January first, in the person's language.
    private var monthNames: [String] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        return calendar.standaloneMonthSymbols
    }
}

/// The words of the note under a field for the problem the editor names with its text (R13); nil when it names none.
/// `unreadable` says what the field needs to be read.
func noteWords(of problem: FieldProblem.Code?, unreadable: LocalizedStringResource) -> LocalizedStringResource? {
    switch problem {
    case .unreadable: unreadable
    case .endBeforeStart: "editor.note.endBeforeStart"
    case nil: nil
    }
}

private extension View {
    /// The note of a group of controls, which VoiceOver reads with each of them as custom content of high importance (see
    /// `LabeledField`). The group is no element of its own, so SwiftUI gives the note to each control; it has a key of its
    /// own, so that the empty note of the year's field does not take its place.
    func groupNote(_ note: LocalizedStringResource?) -> some View {
        accessibilityCustomContent(
            AccessibilityCustomContentKey("field.note", id: "field.groupNote"), note.map { Text($0) }, importance: .high
        )
    }
}
