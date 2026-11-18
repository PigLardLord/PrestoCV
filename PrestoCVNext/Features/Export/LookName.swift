import PrestoCVPresentation
import SwiftUI

/// The names of the look picker in the app's language (#407). A choice the app offers is named by the code it comes
/// with, which is its key in the string catalog; the design's own, a kept choice and the groups have keys of their own.
enum LookName {
    /// The names of the choices the app offers, each looked up by its code.
    private static let offered: [LocalizedStringResource] = [
        "design.minimal", "design.modern", "design.professional",
        "fonts.system", "fonts.serif", "fonts.rounded",
        "palette.ink", "palette.slate", "palette.ocean", "palette.plum"
    ]

    /// The name of an offered choice's code, or nil for a code the app has no name for.
    static func named(_ code: String) -> LocalizedStringResource? {
        offered.first { $0.key == code }
    }

    /// The name of an item. A choice the app has no name for reads as one from an earlier version: the PDF keeps it,
    /// and the person can choose another.
    static func of(_ item: LookPickerModel.Item) -> LocalizedStringResource {
        switch item.kind {
        case .offered(let choice): named(choice.nameCode) ?? "look.kept"
        case .designsOwn: "look.designsOwn"
        case .kept: "look.kept"
        }
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
