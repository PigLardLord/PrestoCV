import Foundation
import PrestoCVWorkflowPorts

/// One choice of the picker: the id a CV keeps, the code of its name, which the view words (R13), and what the view
/// draws it with (#407).
public struct LookChoice: Hashable, Sendable {
    public let id: String
    public let nameCode: String
    public let sample: Sample

    /// What the view draws a choice with, so that the person sees it before choosing it.
    public enum Sample: Hashable, Sendable {
        /// No picture of its own, such as a design without one: the view draws a plain page.
        case none
        /// A picture of a page in the design, as PNG data.
        case page(png: Data)
        /// The palette's main colour over its background.
        case colors(primary: RGB, background: RGB)
        /// The kind of typeface the fonts are set in.
        case typeface(Typeface)
    }

    /// A colour, by its red, green and blue, each from 0 to 1.
    public struct RGB: Hashable, Sendable {
        public let red: Double
        public let green: Double
        public let blue: Double
    }

    /// The kinds of typeface a font scheme sets the CV in.
    public enum Typeface: Hashable, Sendable {
        case system
        case serif
        case rounded
    }
}

/// The designs, palettes and font schemes the picker shows.
public struct LookChoices: Hashable, Sendable {
    public let designs: [LookChoice]
    public let palettes: [LookChoice]
    public let fontSchemes: [LookChoice]
    private let defaultDesign: String
    private let ownLooks: [String: DesignOwnLook]

    init(_ options: LookOptions) {
        designs = options.designs.map(LookChoice.init)
        palettes = options.palettes.map(LookChoice.init)
        fontSchemes = options.fontSchemes.map(LookChoice.init)
        defaultDesign = options.defaultDesign
        ownLooks = options.ownLooks
    }

    /// The sample of the palette `design` sets a CV in when the CV keeps none; nothing to draw when it is not offered.
    func ownPaletteSample(of design: String) -> LookChoice.Sample {
        sample(of: ownLook(of: design)?.palette, in: palettes)
    }

    /// The sample of the fonts `design` sets a CV in when the CV keeps none; nothing to draw when they are not offered.
    func ownFontsSample(of design: String) -> LookChoice.Sample {
        sample(of: ownLook(of: design)?.fonts, in: fontSchemes)
    }

    /// The own look of `design`: a design the app does not have is exported with the default one, so it is the
    /// default design's.
    private func ownLook(of design: String) -> DesignOwnLook? {
        ownLooks[design] ?? ownLooks[defaultDesign]
    }

    private func sample(of id: String?, in choices: [LookChoice]) -> LookChoice.Sample {
        choices.first { $0.id == id }?.sample ?? .none
    }
}

// MARK: - From the port

// The view imports this module alone, so the port's samples are given to it as this module's own values.
extension LookChoice {
    init(_ option: LookOption) { self.init(id: option.id, nameCode: option.nameCode, sample: Sample(option.sample)) }
}

extension LookChoice.Sample {
    init(_ sample: LookSample) {
        switch sample {
        case .none: self = .none
        case .page(let png): self = .page(png: png)
        case .colors(let primary, let background):
            self = .colors(primary: LookChoice.RGB(primary), background: LookChoice.RGB(background))
        case .typeface(let typeface): self = .typeface(LookChoice.Typeface(typeface))
        }
    }
}

extension LookChoice.RGB {
    init(_ color: LookColor) { self.init(red: color.red, green: color.green, blue: color.blue) }
}

extension LookChoice.Typeface {
    init(_ typeface: LookTypeface) {
        switch typeface {
        case .system: self = .system
        case .serif: self = .serif
        case .rounded: self = .rounded
        }
    }
}
