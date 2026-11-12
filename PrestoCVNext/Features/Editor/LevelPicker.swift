import PrestoCVPresentation
import SwiftUI

/// The level of a skill, as a menu: none, or one of the levels the editor offers, worded "3 of 5".
struct LevelPicker: View {
    @Binding var level: Int?

    var body: some View {
        Picker(selection: $level) {
            Text("editor.choice.none").tag(Int?.none)
            ForEach(EditorChoices.skillLevels, id: \.self) { level in
                Text("editor.level \(level) \(EditorChoices.skillLevels.count)").tag(Int?.some(level))
            }
        } label: {
            Text("editor.field.level")
        }
        .pickerStyle(.menu)
        .frame(minHeight: TapTarget.minimumHeight)
    }
}
