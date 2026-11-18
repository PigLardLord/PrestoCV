import PrestoCVPresentation
import SwiftUI

/// Where the export stands, under the PDF: that it runs, or why there is no PDF or what the PDF lacks. A status with
/// nothing to say shows nothing; the fields the CV lacks are the list's below (`MissingFieldsView`).
struct ExportStatusView: View {
    let status: ExportStatus

    var body: some View {
        if let words = status.words {
            HStack(spacing: Spacing.small) {
                if case .exporting = status { ProgressView() }
                WholeWordsText(words)
            }
            .footerTextStyle()
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("export.status")
        }
    }
}

extension ExportStatus {
    /// The words of the status, nil when it has none to say: before the export, when the PDF is made in full (the page
    /// count says so), and when the CV lacks a field (the list says which).
    var words: LocalizedStringResource? {
        switch self {
        case .idle, .done, .notReady: nil
        case .exporting: "export.loading"
        case .truncated(let pages, let required): "export.error.too_many_pages \(required) \(pages)"
        case .unsupportedLanguage: "export.status.unsupported_language"
        case .invalid: "export.status.invalid"
        case .incomplete(let missing): "export.status.incomplete \(missing)"
        case .textNotVisible(let lines): "export.status.text_not_visible \(lines)"
        case .failed: "export.error.failed"
        }
    }
}
