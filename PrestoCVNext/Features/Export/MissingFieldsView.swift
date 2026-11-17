import PrestoCVPresentation
import SwiftUI

/// What the CV lacks, one line per field in the order of the form: first the fields without which there is no PDF,
/// then those a recruiter looks for. The icon tells the two apart, and the words say it as well.
struct MissingFieldsView: View {
    let missing: ExportMissing

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            ForEach(missing.blockers, id: \.self) { field in
                line(field.words, symbol: "exclamationmark.triangle")
                    .accessibilityIdentifier("export.missing.blocker.\(field)")
            }
            ForEach(missing.warnings, id: \.self) { field in
                line(field.words, symbol: "exclamationmark.circle")
                    .accessibilityIdentifier("export.missing.warning.\(field)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func line(_ words: LocalizedStringResource, symbol: String) -> some View {
        Label {
            WholeWordsText(words)
        } icon: {
            Image(systemName: symbol)
        }
        .footerTextStyle()
        .fixedSize(horizontal: false, vertical: true)
    }
}

extension ExportMissing.Field {
    /// What the CV lacks without the field, and why it matters.
    var words: LocalizedStringResource {
        switch self {
        case .name: "export.readiness.name_required"
        case .email: "export.readiness.no_email"
        case .phone: "export.readiness.no_phone"
        }
    }
}
