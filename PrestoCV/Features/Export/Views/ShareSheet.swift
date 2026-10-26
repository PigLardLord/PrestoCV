import SwiftUI
import UIKit
import LinkPresentation

extension View {
    /// Presents the system's share sheet for the PDF of `share` while it is set, from this view: where the sheet is a
    /// popover, it points at this view. When the sheet closes, the share ends, `share` is cleared and `onEnd` tells how
    /// the share ended.
    /// - Parameter onEnd: The raw value of the activity the PDF went to, if any, and whether the share went through
    func shareSheet(for share: Binding<PDFShare?>, onEnd: @escaping (String?, Bool) -> Void) -> some View {
        background(ShareSheetPresenter(share: share, onEnd: onEnd))
    }
}

/// An empty view controller behind the view, which presents the share sheet from where the view is
private struct ShareSheetPresenter: UIViewControllerRepresentable {
    @Binding var share: PDFShare?
    let onEnd: (String?, Bool) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ host: UIViewController, context: Context) {
        guard let share, host.presentedViewController == nil else { return }

        let sheet = UIActivityViewController(activityItems: [PDFShareItem(pdf: share.pdf)], applicationActivities: nil)
        sheet.popoverPresentationController?.sourceView = host.view
        sheet.popoverPresentationController?.sourceRect = host.view.bounds
        // The handler holds the share, so the file stays for as long as the share sheet can read it
        sheet.completionWithItemsHandler = { activityType, completed, _, _ in
            share.end()
            self.share = nil
            onEnd(activityType?.rawValue, completed)
        }
        host.present(sheet, animated: true)
    }
}

/// The PDF as the share sheet offers it: the file, with its name and a picture of its first page at the top of the
/// sheet, where a file alone would show a generic icon
private final class PDFShareItem: NSObject, UIActivityItemSource {
    private let pdf: ExportedPDF

    init(pdf: ExportedPDF) {
        self.pdf = pdf
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        pdf.url
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        pdf.url
    }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = pdf.fileName
        if let thumbnail = pdf.thumbnail.flatMap(UIImage.init(data:)) {
            metadata.iconProvider = NSItemProvider(object: thumbnail)
        }
        return metadata
    }
}
