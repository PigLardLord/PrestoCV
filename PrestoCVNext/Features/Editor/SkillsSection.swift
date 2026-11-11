import PrestoCVPresentation
import SwiftUI

/// The skills, each with its level from a menu. They stay in the form on every screen.
struct SkillsSection: View {
    @Bindable var editor: EditorViewModel
    let focus: FocusState<RowFocus?>.Binding

    var body: some View {
        RowsSection(
            editor: editor, section: .skills, rows: editor.content.skills, name: \.rowName, summary: \.summary,
            focus: focus
        ) { row, fields in
            let skill = $editor.content.skills[row: row.id, or: row]
            fields.line("editor.field.skill", skill.name, .skillName)
            LevelPicker(level: skill.level)
                .accessibilityIdentifier("editor.field.skillLevel")
        }
    }
}
