import PrestoCVPresentation
import SwiftUI

/// The level of a language, as a menu: none, or one of the levels the editor offers by their codes, which this view
/// words (R13).
struct ProficiencyPicker: View {
    @Binding var proficiency: String

    var body: some View {
        Picker(selection: $proficiency) {
            Text("editor.choice.none").tag("")
            ForEach(EditorChoices.proficiencies, id: \.self) { code in
                words(of: code).tag(code)
            }
        } label: {
            Text("editor.field.proficiency")
        }
        .pickerStyle(.menu)
        .frame(minHeight: TapTarget.minimumHeight)
    }

    /// The words of a level by its code; a code the editor does not offer shows as it is.
    private func words(of code: String) -> Text {
        switch code {
        case "a1": Text("editor.proficiency.a1")
        case "a2": Text("editor.proficiency.a2")
        case "b1": Text("editor.proficiency.b1")
        case "b2": Text("editor.proficiency.b2")
        case "c1": Text("editor.proficiency.c1")
        case "c2": Text("editor.proficiency.c2")
        case "native": Text("editor.proficiency.native")
        default: Text(verbatim: code)
        }
    }
}
