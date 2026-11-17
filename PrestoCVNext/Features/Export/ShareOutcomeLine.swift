import PrestoCVPresentation
import SwiftUI

/// The line that confirms a share of the PDF went through: saved, or sent. A share closed without going through, and an
/// export with no share yet, show nothing.
struct ShareOutcomeLine: View {
    let outcome: ShareOutcome?

    var body: some View {
        if let outcome {
            Label {
                WholeWordsText(outcome.words)
            } icon: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.tint)
            }
            .footerTextStyle()
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("export.confirmation")
        }
    }
}

extension ShareOutcome {
    /// The words that confirm the share.
    var words: LocalizedStringResource {
        switch self {
        case .saved: "export.confirmation.saved"
        case .sent: "export.confirmation.sent"
        }
    }
}
