import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// The picture of a page from the bytes of its PNG, such as the page a design is shown with in the look picker. SwiftUI
/// has no way to read a PNG itself, so the platform's image does it.
enum PagePicture {
    /// The picture, nil when the bytes are not one.
    static func image(png: Data) -> Image? {
        #if os(iOS)
        UIImage(data: png).map { Image(uiImage: $0) }
        #else
        NSImage(data: png).map { Image(nsImage: $0) }
        #endif
    }
}
