import PrestoCVPresentation
import SwiftUI

/// The export of the open CV: its PDF as the person will send it, how many pages it has, where the export stands, a
/// share that went through, and what the CV lacks. A tap on the pages, or their corner button, shows the PDF on the
/// whole screen; Share, in the bar, opens the system's share sheet with it. It renders the sheet's model and forwards
/// Close, Share and the taps; the export and the share are the model's (R5).
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
                    ShareOutcomeLine(outcome: sheet.shareOutcome)
                    ShareFailedLine(failure: sheet.shareFailure)
                    MissingFieldsView(missing: sheet.missing)
                }
                .padding(Spacing.medium)
                .readableWidth()
                .announce(sheet.statusToAnnounce) { $0.words }
                .announce(sheet.shareOutcome) { $0.words }
                .announce(sheet.shareFailure) { $0.words }
            }
            .scrollBounceBehavior(.basedOnSize)
            .navigationTitle("export.sheet.title")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    closeButton
                }
                ToolbarItem(placement: .primaryAction) {
                    shareButton
                }
            }
        }
        .fullScreenPresentation(item: fullPDF) { full in
            FullPDFView(full: full, done: { sheet.closeFullPDF() })
        }
        .presentationSizing(.page)
    }

    /// Close, which reads Done once a share of the PDF went through: the person has what they came for.
    private var closeButton: some View {
        Button(action: close) {
            if sheet.closesAsDone {
                Label("export.done", systemImage: "checkmark")
            } else {
                Label("export.close", systemImage: "xmark")
            }
        }
        .accessibilityIdentifier("export.close")
    }

    /// Share opens the system's share sheet with the PDF. It waits for the PDF, and says so while the export runs;
    /// without a PDF, it points to the lines under the pages, which say why.
    private var shareButton: some View {
        Button {
            sheet.share()
        } label: {
            Label("export.share", systemImage: "square.and.arrow.up")
        }
        .buttonStyle(.glassProminent)
        .disabled(sheet.shareAvailability != .ready)
        .accessibilityValue(shareValue)
        .accessibilityIdentifier("export.share")
        .sharePresentation(sheet.openShare)
    }

    /// What VoiceOver reads after Share's name: that the export runs, or that there is no PDF and why is said below.
    private var shareValue: Text {
        switch sheet.shareAvailability {
        case .preparing: Text("export.loading")
        case .unavailable: Text("export.share.unavailable")
        case .ready: Text(verbatim: "")
        }
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
