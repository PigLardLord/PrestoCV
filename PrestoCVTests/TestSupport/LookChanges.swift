import struct PrestoCVApplication.LookChange
import struct PrestoCVDomain.DesignChoice

/// The change a sheet hands over when the person chooses `parts` of the look and the sheet then shows the given ids
func lookChange(
    _ parts: Set<LookChange.Part>,
    design: String = "classic",
    palette: String = "professional",
    fonts: String = "classic"
) -> LookChange {
    LookChange(shown: DesignChoice(design: design, palette: palette, fonts: fonts)!, parts: parts)
}
