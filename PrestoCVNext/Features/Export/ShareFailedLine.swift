import PrestoCVPresentation
import SwiftUI

/// The line that tells a share of the PDF could not go through, and that Share can be tapped again. It shows until the
/// next try, a share that goes through or the next export.
struct ShareFailedLine: View {
    let failure: ShareFailure?

    var body: some View {
        if let failure {
            Label {
                WholeWordsText(failure.words)
            } icon: {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }
            .footerTextStyle()
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("export.share.failed")
        }
    }
}

extension ShareFailure {
    /// The words that tell the share failed.
    var words: LocalizedStringResource { "export.share.failed" }
}
