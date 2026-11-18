import PrestoCVPresentation
import SwiftUI

/// The names of the look picker in the app's language (#407). A choice the app offers is named by the code it comes
/// with, which is its key in the string catalog (the owner's D2: the names of the installed designs, until a design
/// catalog brings its own); the design's own, a kept choice and the groups have keys of their own. The composition's
/// LookNamesTests checks that the codes the launch offers and the catalog's design, fonts and palette keys are the
/// same set.
enum LookName {
    /// The name of an item. A kept choice is one the app no longer offers: the PDF keeps it, and the person can choose
    /// another.
    static func of(_ item: LookPickerModel.Item) -> LocalizedStringResource {
        switch item.kind {
        case .offered(let choice): offered(choice.nameCode)
        case .designsOwn: "look.designsOwn"
        case .kept: "look.kept"
        }
    }

    /// The name of a choice the app offers: the catalog's text under the choice's code.
    static func offered(_ code: String) -> LocalizedStringResource {
        LocalizedStringResource(String.LocalizationValue(code))
    }

    /// The title of a group.
    static func group(_ part: LookPart) -> LocalizedStringResource {
        switch part {
        case .design: "look.group.design"
        case .fonts: "look.group.fonts"
        case .palette: "look.group.palette"
        }
    }

    /// The chosen item of each group, named in `locale` and joined in the groups' order: "Professional, Serif, Ocean".
    static func chosen(_ picker: LookPickerModel, in locale: Locale) -> String {
        picker.chosen.map { item in
            var name = of(item)
            name.locale = locale
            return String(localized: name)
        }
        .joined(separator: ", ")
    }

    /// The part of an accessibility identifier that names an item within its group.
    static func identifier(_ item: LookPickerModel.Item) -> String {
        switch item.id {
        case .offered(let id): id
        case .designsOwn: "designsOwn"
        case .kept: "kept"
        }
    }
}
