import Foundation

/// What the look picker offers, as app values: ids, the codes the view words (R13) and what the view draws each choice
/// with. The design catalog is the real source (step 3-4); a view model only reads what it is given.
/// The app opens while the bundled designs are still being checked (#566): the options can grow, and their status says
/// whether more designs can join.
public protocol LookOptionsProviding: Sendable {
    /// The options now.
    func options() -> LookOptions
    /// The options now, then again each time they change: a design that joins, or the end of the check.
    func changes() -> AsyncStream<LookOptions>
    /// Checks the designs again when the default design did not pass (`unavailable`); does nothing otherwise.
    func retry()
}

/// How far the check of the bundled designs is (#566), as a code the view words (R13).
public enum LookOptionsStatus: Hashable, Sendable {
    /// The designs are being checked: more can join the options.
    case checking
    /// Every design has its verdict, and the default design passed.
    case ready
    /// The default design did not pass, or the store cannot give it: no PDF can be made until a check passes.
    case unavailable
}

/// One choice of a picker: the id a CV keeps, the code of its name, which the view words, and what the view draws it
/// with.
public struct LookOption: Hashable, Sendable {
    public let id: String
    public let nameCode: String
    public let sample: LookSample

    public init(id: String, nameCode: String, sample: LookSample = .none) {
        self.id = id
        self.nameCode = nameCode
        self.sample = sample
    }
}

/// What a picker draws a choice with, so that the person sees it before choosing it (#407).
public enum LookSample: Hashable, Sendable {
    /// Nothing to draw: the view shows the name alone.
    case none
    /// A design: a picture of a page it made, as PNG bytes the catalog keeps with it.
    case page(png: Data)
    /// A palette: the colour of its headings and links, and the colour of its page.
    case colors(primary: LookColor, background: LookColor)
    /// A font scheme: the kind of typeface it sets the text in.
    case typeface(LookTypeface)
}

/// A colour as a view draws it: red, green and blue, each from 0 to 1.
public struct LookColor: Hashable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}

/// The kinds of typeface the font schemes set the text in; the view draws a sample of each with the platform's own
/// face of that kind.
public enum LookTypeface: Hashable, Sendable {
    case system
    case serif
    case rounded
}

/// The palette and fonts a design sets a CV in when the CV keeps none of its own, by their ids.
public struct DesignOwnLook: Hashable, Sendable {
    public let palette: String
    public let fonts: String

    public init(palette: String, fonts: String) {
        self.palette = palette
        self.fonts = fonts
    }
}

/// The designs, palettes and font schemes a picker shows, the palette and fonts each design sets a CV in when it keeps
/// none, and the look the picker shows for a CV that keeps no look at all.
public struct LookOptions: Hashable, Sendable {
    public let designs: [LookOption]
    public let palettes: [LookOption]
    public let fontSchemes: [LookOption]
    public let defaultDesign: String
    /// The own palette and fonts of each design, by the design's id.
    public let ownLooks: [String: DesignOwnLook]
    /// Whether more designs can join.
    public let status: LookOptionsStatus

    /// The palette of the default design: none when the options know no own look for it.
    public var defaultPalette: String? { ownLooks[defaultDesign]?.palette }
    /// The fonts of the default design: none when the options know no own look for it.
    public var defaultFonts: String? { ownLooks[defaultDesign]?.fonts }

    public init(
        designs: [LookOption], palettes: [LookOption], fontSchemes: [LookOption],
        defaultDesign: String, ownLooks: [String: DesignOwnLook], status: LookOptionsStatus
    ) {
        self.designs = designs
        self.palettes = palettes
        self.fontSchemes = fontSchemes
        self.defaultDesign = defaultDesign
        self.ownLooks = ownLooks
        self.status = status
    }
}
