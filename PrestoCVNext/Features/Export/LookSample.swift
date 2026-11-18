import PrestoCVPresentation
import SwiftUI

/// What an item of the look picker is drawn with (#407): a design its page, a palette its two colours, fonts the letters
/// "Aa" in their face. A choice with no sample, or one the CV keeps from an earlier version, is drawn by its part: a
/// plain page, the letters in the system's face, or a dashed circle. VoiceOver skips the sample: the item's name says it.
struct LookSample: View {
    let item: LookPickerModel.Item
    @ScaledMetric(relativeTo: .title2) private var letterSize: CGFloat = 24

    var body: some View {
        drawing
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var drawing: some View {
        switch item.kind {
        case .offered(let choice): sample(choice.sample)
        case .designsOwn(let sample): self.sample(sample)
        case .kept: byPart
        }
    }

    @ViewBuilder
    private func sample(_ sample: LookChoice.Sample) -> some View {
        switch sample {
        case .none: byPart
        case .page(let png): page(PagePicture.image(png: png))
        case .colors(let primary, let background): swatch(primary: primary, background: background)
        case .typeface(let typeface): letters(in: typeface)
        }
    }

    /// A choice the app cannot draw as the PDF does, drawn by its part
    @ViewBuilder
    private var byPart: some View {
        switch item.part {
        case .design: page(nil)
        case .fonts: letters(in: .system)
        case .palette:
            Circle()
                .strokeBorder(.secondary, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .frame(width: Swatch.diameter, height: Swatch.diameter)
        }
    }

    /// A page in the shape of A4: the design's picture, or a plain page with a document symbol when there is none
    private func page(_ picture: Image?) -> some View {
        RoundedRectangle(cornerRadius: CornerRadius.page)
            .fill(.white)
            .overlay {
                if let picture {
                    picture
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: "doc")
                        .font(.title2)
                        .foregroundStyle(.gray)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.page))
            .overlay {
                RoundedRectangle(cornerRadius: CornerRadius.page)
                    .strokeBorder(.secondary, lineWidth: 0.5)
            }
            .aspectRatio(PageShape.a4, contentMode: .fit)
    }

    /// A circle split in two: the palette's main colour, and its background
    private func swatch(primary: LookChoice.RGB, background: LookChoice.RGB) -> some View {
        HStack(spacing: 0) {
            color(primary)
            color(background)
        }
        .frame(width: Swatch.diameter, height: Swatch.diameter)
        .clipShape(Circle())
        .overlay {
            Circle()
                .strokeBorder(.secondary, lineWidth: 1)
        }
    }

    private func color(_ rgb: LookChoice.RGB) -> Color {
        Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }

    /// "Aa" in the face of a font scheme, at a size that follows the person's text size
    private func letters(in typeface: LookChoice.Typeface) -> some View {
        Text(verbatim: "Aa")
            .font(.system(size: letterSize, weight: .semibold, design: design(of: typeface)))
            .frame(minWidth: Swatch.diameter, minHeight: Swatch.diameter)
    }

    private func design(of typeface: LookChoice.Typeface) -> Font.Design {
        switch typeface {
        case .system: .default
        case .serif: .serif
        case .rounded: .rounded
        }
    }
}
