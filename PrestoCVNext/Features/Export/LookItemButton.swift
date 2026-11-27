import PrestoCVPresentation
import SwiftUI

/// One item of the look picker (#407): its sample over its name, ringed and ticked when it is the one the PDF is made
/// with. At the accessibility text sizes it is a row instead, the sample beside the name and the tick at the end, so the
/// name has the whole width. A tap gives the item back; what it does is the sheet's.
struct LookItemButton: View {
    let item: LookPickerModel.Item
    let pick: () -> Void
    @Environment(\.dynamicTypeSize) private var textSize

    var body: some View {
        Button(action: pick) {
            label
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(LookName.of(item)))
        .accessibilityAddTraits(item.isSelected ? .isSelected : [])
        .accessibilityIdentifier("look.\(item.part).\(LookName.identifier(item))")
    }

    private var label: some View {
        Group {
            if textSize.isAccessibilitySize {
                HStack(spacing: Spacing.medium) {
                    ringed
                        .frame(width: LookThumbnail.width)
                    WholeWordsText(LookName.of(item))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if item.isSelected {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                    }
                }
                .frame(minHeight: TapTarget.minimumHeight)
            } else {
                VStack(spacing: Spacing.small) {
                    ringed
                    WholeWordsText(LookName.of(item))
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: TapTarget.minimumHeight)
            }
        }
        .contentShape(Rectangle())
    }

    /// The sample, with room for the ring around it, and the ring and the tick when the item is chosen
    private var ringed: some View {
        LookSample(item: item)
            .padding(SelectionRing.gap + SelectionRing.width)
            .overlay {
                if item.isSelected {
                    RoundedRectangle(cornerRadius: ringRadius)
                        .strokeBorder(.tint, lineWidth: SelectionRing.width)
                }
            }
            .overlay(alignment: .topTrailing) {
                if item.isSelected && !textSize.isAccessibilitySize {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white, .tint)
                        .accessibilityHidden(true)
                }
            }
    }

    /// A colour's ring is round, as its sample; the others follow the corners of a control
    private var ringRadius: CGFloat {
        item.part == .palette
            ? Swatch.diameter / 2 + SelectionRing.gap + SelectionRing.width
            : CornerRadius.control
    }
}
