import SwiftUI

/// How many pages the PDF has, under it. Without a PDF the line keeps its height, so the lines below do not move when
/// one arrives.
struct PageCountLine: View {
    let pages: Int?

    var body: some View {
        if let pages {
            WholeWordsText("export.pages \(pages)")
                .footerTextStyle()
                .accessibilityIdentifier("export.pages")
        } else {
            Text(verbatim: " ")
                .footerTextStyle()
                .accessibilityHidden(true)
        }
    }
}
