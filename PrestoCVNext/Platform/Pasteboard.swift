#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Puts the text on the system's clipboard in place of what it held, as the person's own copy.
@MainActor
func copyToPasteboard(_ text: String) {
    #if os(iOS)
    UIPasteboard.general.string = text
    #elseif os(macOS)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
    #endif
}
