import PrestoCVPresentation
import SwiftUI

/// The export of the open CV: its PDF as the person will send it, how many pages it has, where the export stands, and
/// what the CV lacks. It renders the sheet's model and forwards Close; the export itself is the model's (R5).
struct ExportSheetView: View {
    let sheet: ExportSheetViewModel
    /// Closes the sheet, which stops an export that runs.
    let close: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.medium) {
                    preview
                    PageCountLine(pages: sheet.document?.pages)
                    ExportStatusView(status: sheet.status)
                    MissingFieldsView(missing: sheet.missing)
                }
                .padding(Spacing.medium)
                .readableWidth()
            }
            .scrollBounceBehavior(.basedOnSize)
            .navigationTitle("export.sheet.title")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: close) {
                        Label("export.close", systemImage: "xmark")
                    }
                    .accessibilityIdentifier("export.close")
                }
            }
        }
        .presentationSizing(.page)
    }

    /// The PDF's pages, or an empty page while there is none. VoiceOver skips both: the page count and the status say
    /// what the person needs, and the PDF's text is the CV they wrote.
    @ViewBuilder
    private var preview: some View {
        if let document = sheet.document, let id = sheet.documentID {
            PDFPages(pdf: document.pdf, id: id, isForTheEyeOnly: true)
                .accessibilityHidden(true)
                .aspectRatio(PageShape.a4, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.control))
                .shadow(color: .black.opacity(0.15), radius: 12, y: 8)
                .containerRelativeFrame(.vertical) { height, _ in height * 0.6 }
        } else {
            RoundedRectangle(cornerRadius: CornerRadius.control)
                .fill(.background.secondary)
                .overlay {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: IconSize.state))
                        .foregroundStyle(.tertiary)
                }
                .aspectRatio(PageShape.a4, contentMode: .fit)
                .containerRelativeFrame(.vertical) { height, _ in height * 0.6 }
                .accessibilityHidden(true)
        }
    }
}
