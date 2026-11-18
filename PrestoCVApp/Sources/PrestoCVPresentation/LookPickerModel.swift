import Foundation

/// The look picker as the view shows it: one group per part of the look, its items in order, which one is chosen and
/// what each is drawn with (#407). The view lays it out and gives a tap back as the item; it decides nothing.
public struct LookPickerModel: Hashable, Sendable {
    /// The design first, then the fonts, then the colours.
    public let groups: [Group]

    /// The chosen item of each group, in the groups' order: what the row that opens the picker names.
    public var chosen: [Item] { groups.compactMap { $0.items.first(where: \.isSelected) } }

    /// The items of one part of the look.
    public struct Group: Hashable, Sendable {
        public let part: LookPart
        public let items: [Item]

        /// The CV keeps a choice of this part that the app no longer offers: the view says so with the group.
        public var keepsAnEarlierLook: Bool { items.contains(where: \.isKept) }
    }

    /// One item of a group, and whether it is the one the PDF is made with.
    public struct Item: Hashable, Sendable, Identifiable {
        public let part: LookPart
        public let kind: Kind
        public let isSelected: Bool

        /// What the item is.
        public enum Kind: Hashable, Sendable {
            /// A choice the app offers.
            case offered(LookChoice)
            /// The palette or fonts the design sets a CV in when the CV keeps none, drawn as the PDF sets them.
            case designsOwn(LookChoice.Sample)
            /// The choice the CV keeps from an earlier version of the app, which no longer offers it.
            case kept
        }

        /// The identity of an item within its group.
        public enum ID: Hashable, Sendable {
            case offered(String)
            case designsOwn
            case kept
        }

        public var id: ID {
            switch kind {
            case .offered(let choice): .offered(choice.id)
            case .designsOwn: .designsOwn
            case .kept: .kept
            }
        }

        /// The item is the choice the app no longer offers.
        public var isKept: Bool { kind == .kept }
    }

    /// The picker for `shown`, the look the PDF is made with. A part the CV keeps none of has the design's own chosen;
    /// a part whose id the app does not offer has one more item, last and chosen, as the PDF keeps it.
    init(choices: LookChoices, shown: EditorLook) {
        groups = [
            Group(part: .design, items: Self.items(.design, choices.designs, shown: shown.design, designsOwn: nil)),
            Group(part: .fonts, items: Self.items(
                .fonts, choices.fontSchemes, shown: shown.fonts, designsOwn: choices.ownFontsSample(of: shown.design)
            )),
            Group(part: .palette, items: Self.items(
                .palette, choices.palettes, shown: shown.palette, designsOwn: choices.ownPaletteSample(of: shown.design)
            ))
        ]
    }

    /// The items of a part: the design's own first when the part has one, the offered choices in the app's order, and
    /// the kept choice last when the shown id is not among them.
    private static func items(
        _ part: LookPart, _ offered: [LookChoice], shown: String?, designsOwn: LookChoice.Sample?
    ) -> [Item] {
        let own = designsOwn.map { [Item(part: part, kind: .designsOwn($0), isSelected: shown == nil)] } ?? []
        let choices = offered.map { Item(part: part, kind: .offered($0), isSelected: $0.id == shown) }
        let kept = shown.flatMap { id in offered.contains { $0.id == id } ? nil : Item(part: part, kind: .kept, isSelected: true) }
        return own + choices + (kept.map { [$0] } ?? [])
    }
}
