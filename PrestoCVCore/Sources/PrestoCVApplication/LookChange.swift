import PrestoCVDomain

/// What a person changed in the look of a CV's PDF, in its export sheet: the parts they chose, and the look the sheet
/// showed once they had, whole.
///
/// Only the chosen parts are the person's choice. The others are what the sheet showed, and for an id the app does not
/// know that is a default, not what the CV holds. So whoever applies the change takes the chosen parts from `shown` and
/// leaves every other part of the CV's look as it is, an id the app does not know included. A CV that keeps no look yet
/// takes all of `shown`: the sheet showed it a look (the design chosen last on the device, or the defaults), and the CV
/// must keep what the person saw.
public struct LookChange: Sendable, Equatable {
    /// A part of a look.
    public enum Part: Sendable, Hashable, CaseIterable {
        case design, palette, fonts
    }

    /// The look the sheet showed once the change was made.
    public let shown: DesignChoice
    /// The parts the person chose.
    public let parts: Set<Part>

    public init(shown: DesignChoice, parts: Set<Part>) {
        self.shown = shown
        self.parts = parts
    }

    /// This change and then `later`: the parts chosen in either. Each part chosen takes the value of its latest choice, and
    /// the others the value `later` showed. Two changes made before either is stored are stored as this one.
    public func followed(by later: LookChange) -> LookChange {
        func latest<Value>(of part: Part, earlier: Value, later laterValue: Value) -> Value {
            parts.contains(part) && !later.parts.contains(part) ? earlier : laterValue
        }
        let design = latest(of: .design, earlier: shown.design, later: later.shown.design)
        let palette = latest(of: .palette, earlier: shown.palette, later: later.shown.palette)
        let fonts = latest(of: .fonts, earlier: shown.fonts, later: later.shown.fonts)
        return LookChange(
            shown: DesignChoice(design: design, palette: palette, fonts: fonts) ?? later.shown,
            parts: parts.union(later.parts)
        )
    }
}
