import PrestoCVPresentation
import SwiftUI

/// The export of the open CV: its PDF as the person will send it, how many pages it has, where the export stands, and
/// what the CV lacks. A tap on the pages, or their corner button, shows the PDF on the whole screen. It renders the
/// sheet's model and forwards Close and the taps; the export itself is the model's (R5).
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
        .fullScreenPresentation(item: fullPDF) { full in
            FullPDFView(full: full, done: { sheet.closeFullPDF() })
        }
        .presentationSizing(.page)
    }

    /// The PDF on the whole screen; a swipe that closes it tells the model.
    private var fullPDF: Binding<FullPDF?> {
        Binding(get: { sheet.fullPDF }, set: { full in if full == nil { sheet.closeFullPDF() } })
    }

    /// The PDF's pages, or an empty page while there is none. VoiceOver skips both: the page count and the status say
    /// what the person needs, and the PDF's text is the CV they wrote. The corner button is the way VoiceOver reaches
    /// the PDF on the whole screen, where its text is read.
    @ViewBuilder
    private var preview: some View {
        if let document = sheet.document, let id = sheet.documentID {
            PDFPages(pdf: document.pdf, id: id, isForTheEyeOnly: true)
                .onTapGesture { sheet.showFullPDF() }
                .accessibilityHidden(true)
                .aspectRatio(PageShape.a4, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.control))
                .shadow(color: .black.opacity(0.15), radius: 12, y: 8)
                .overlay(alignment: .bottomTrailing) { openButton(pages: document.pages) }
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

    /// The round button in the corner of the pages that shows the PDF on the whole screen. Its symbol stays small over
    /// the page, and its tap target is the full size; at the accessibility text sizes a long press shows it large.
    private func openButton(pages: Int) -> some View {
        Button {
            sheet.showFullPDF()
        } label: {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.footnote.weight(.semibold))
                .frame(width: OverlayButton.diameter, height: OverlayButton.diameter)
                .background(.regularMaterial, in: Circle())
                .frame(width: TapTarget.minimumHeight, height: TapTarget.minimumHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("export.preview.open \(pages)"))
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityShowsLargeContentViewer()
        .padding(Spacing.small)
    }
}
