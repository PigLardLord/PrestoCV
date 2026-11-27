import PrestoCVPresentation
import SwiftUI

/// The look of the PDF (#407): the design, then the fonts, then the colours, each a group of items with the chosen one
/// ringed. A tap goes to the sheet, which shows the choice at once, makes the PDF again and keeps the choice in the CV.
/// A line under the groups says so; a group that holds a choice from an earlier version says what choosing another does.
struct LookPicker: View {
    let sheet: ExportSheetViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.large) {
            ForEach(sheet.lookPicker.groups, id: \.part) { group in
                LookGroup(group: group) { sheet.pick($0) }
            }
            WholeWordsText("look.footer")
                .footerTextStyle()
                .accessibilityIdentifier("look.footer")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// One group of the look picker: its title, its items in a grid that takes as many as the width holds, and the line on
/// a kept choice. At the accessibility text sizes the items are rows, one under the other.
private struct LookGroup: View {
    let group: LookPickerModel.Group
    let pick: (LookPickerModel.Item) -> Void
    @Environment(\.dynamicTypeSize) private var textSize

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            WholeWordsText(LookName.group(group.part))
                .font(.subheadline.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            items
            if group.keepsAnEarlierLook {
                WholeWordsText("look.footer.kept")
                    .footerTextStyle()
                    .accessibilityIdentifier("look.footer.kept")
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var items: some View {
        if textSize.isAccessibilitySize {
            VStack(spacing: Spacing.small) {
                buttons
            }
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: tileWidth), spacing: Spacing.small)], spacing: Spacing.medium) {
                buttons
            }
        }
    }

    private var buttons: some View {
        ForEach(group.items) { item in
            LookItemButton(item: item) { pick(item) }
        }
    }

    /// Colours are round and small, so more of them fit on a line
    private var tileWidth: CGFloat {
        group.part == .palette ? LookTile.colorMinimumWidth : LookTile.minimumWidth
    }
}
