import PrestoCVPresentation
import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

extension View {
    /// Shows the system's share sheet for `share` while it is set, pointing at this view where the sheet is a popover.
    /// The share sheet ends the share when it closes, and the export sheet then lets it go. A share is shown once: a
    /// view update with the same share shows nothing new.
    ///
    /// A Debug build launched for the UI tests shows a stand-in instead (`sharesWithStandIn`): the system's share sheet
    /// runs in another process, which the tests cannot read.
    func sharePresentation(_ share: PDFShare?) -> some View {
        modifier(SharePresentation(share: share))
    }
}

private struct SharePresentation: ViewModifier {
    let share: PDFShare?
    #if DEBUG
    @Environment(\.sharesWithStandIn) private var sharesWithStandIn
    #endif

    func body(content: Content) -> some View {
        #if DEBUG
        if sharesWithStandIn {
            content.sheet(item: standIn) { ShareStandIn(share: $0) }
        } else {
            content.background(SystemShareSheet(share: share))
        }
        #else
        content.background(SystemShareSheet(share: share))
        #endif
    }

    #if DEBUG
    /// The stand-in closed by a swipe is a share closed without going through; after a choice, the share has already
    /// ended, and this end does nothing.
    private var standIn: Binding<PDFShare?> {
        Binding(get: { share }, set: { shown in
            if shown == nil { share?.end(.cancelled) }
        })
    }
    #endif
}

// MARK: - iOS

#if os(iOS)
/// An empty view behind the view: the share sheet is presented over whatever the window shows on top, and points at
/// this view where it is a popover. The view itself owns no view controller, so it works in a bar too, where SwiftUI
/// may keep a representable's controller out of the presentation chain.
private struct SystemShareSheet: UIViewRepresentable {
    let share: PDFShare?

    func makeCoordinator() -> ShownShare { ShownShare() }

    func makeUIView(context: Context) -> UIView {
        UIView()
    }

    func updateUIView(_ anchor: UIView, context: Context) {
        guard let share, context.coordinator.shown !== share else { return }
        context.coordinator.shown = share
        guard let presenter = Self.topmost(over: anchor), !presenter.isBeingDismissed else {
            // Nothing can be shown from here now: the share ends as failed, after this update, so that its file goes,
            // the sheet says so and Share can be tapped again
            Task { share.end(.failed) }
            return
        }
        let sheet = UIActivityViewController(activityItems: [share.url], applicationActivities: nil)
        sheet.popoverPresentationController?.sourceView = anchor
        sheet.popoverPresentationController?.sourceRect = anchor.bounds
        // The handler holds the share, so the file stays for as long as the share sheet can read it. UIKit does not
        // say on which thread it calls the handler, so the end goes to the main actor, where the share lives
        sheet.completionWithItemsHandler = { activity, completed, _, error in
            let result = ShareResult(activity: activity?.rawValue, completed: completed, failed: error != nil)
            Task { @MainActor in share.end(result) }
        }
        presenter.present(sheet, animated: true)
    }

    /// The view controller the window shows on top, which is the one a new presentation must start from; nil when the
    /// view is in no window.
    private static func topmost(over anchor: UIView) -> UIViewController? {
        var top = anchor.window?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

/// The share the presenter has shown last; weak, so that it never keeps a share, or its file, alive.
@MainActor
private final class ShownShare {
    weak var shown: PDFShare?
}
#else

// MARK: - macOS

/// An empty view behind the view, from which the share picker opens.
private struct SystemShareSheet: NSViewRepresentable {
    let share: PDFShare?

    func makeCoordinator() -> SharePicker { SharePicker() }

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ view: NSView, context: Context) {
        guard let share, context.coordinator.shown !== share else { return }
        context.coordinator.show(share, from: view)
    }
}

/// Opens the share picker for one share at a time, and ends the share it opened last when it opens a new one.
@MainActor
private final class SharePicker {
    /// The share shown last; weak, so that it never keeps a share, or its file, alive.
    weak var shown: PDFShare?
    /// The delegate of the share shown last; weak, as `ShareEnd` keeps each delegate until its share ends.
    private weak var delegate: ShareEnd?

    func show(_ share: PDFShare, from view: NSView) {
        delegate?.end(.cancelled)
        shown = share
        let delegate = ShareEnd(share: share)
        self.delegate = delegate
        let picker = NSSharingServicePicker(items: [share.url])
        picker.delegate = delegate
        picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
    }
}

/// Ends one share when its picker, or the service the picker opened, is done. It holds the share until then, so the
/// file stays for as long as the service can read it. AppKit does not mark its delegate calls as made on the main
/// actor, so each end goes there; one delegate per share means that a late call never ends a share opened after it.
@MainActor
private final class ShareEnd: NSObject, NSSharingServicePickerDelegate, NSSharingServiceDelegate {
    /// The delegates of the shares that have not ended. The picker and the service hold their delegate weakly, and the
    /// view that opened the picker goes with the export sheet, which the person can close while a service, such as
    /// AirDrop or Messages, still reads the file: this set keeps each delegate, with its share and file, until the
    /// share ends. A service that never reports an end keeps its file until the next launch removes it.
    private static var open: Set<ShareEnd> = []
    private var share: PDFShare?

    init(share: PDFShare) {
        self.share = share
        super.init()
        Self.open.insert(self)
    }

    func end(_ result: ShareResult) {
        share?.end(result)
        share = nil
        Self.open.remove(self)
    }

    nonisolated func sharingServicePicker(_ picker: NSSharingServicePicker, didChoose service: NSSharingService?) {
        // A chosen service reports its own end
        guard service == nil else { return }
        Task { @MainActor in self.end(.cancelled) }
    }

    nonisolated func sharingServicePicker(
        _ picker: NSSharingServicePicker, delegateFor sharingService: NSSharingService
    ) -> (any NSSharingServiceDelegate)? {
        self
    }

    nonisolated func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) {
        Task { @MainActor in self.end(.sent) }
    }

    nonisolated func sharingService(
        _ sharingService: NSSharingService, didFailToShareItems items: [Any], error: any Error
    ) {
        Task { @MainActor in self.end(.failed) }
    }
}
#endif

// MARK: - The stand-in of the UI tests

#if DEBUG
extension EnvironmentValues {
    /// True when shares show the stand-in instead of the system's share sheet: set at the root of a Debug build that
    /// was launched with the UI tests' argument for it.
    @Entry var sharesWithStandIn = false
}

/// What the UI tests see in place of the system's share sheet: the name of the file, and the ways a share sheet ends.
/// Its texts are for the tests, in no catalog.
private struct ShareStandIn: View {
    let share: PDFShare

    var body: some View {
        List {
            Text(verbatim: share.fileName)
                .accessibilityIdentifier("share.standIn.fileName")
            Button { share.end(.saved) } label: { Text(verbatim: "Save") }
                .accessibilityIdentifier("share.standIn.save")
            Button { share.end(.sent) } label: { Text(verbatim: "Send") }
                .accessibilityIdentifier("share.standIn.send")
            Button { share.end(.other) } label: { Text(verbatim: "Print") }
                .accessibilityIdentifier("share.standIn.other")
            Button { share.end(.failed) } label: { Text(verbatim: "Fail") }
                .accessibilityIdentifier("share.standIn.fail")
            Button(role: .cancel) { share.end(.cancelled) } label: { Text(verbatim: "Cancel") }
                .accessibilityIdentifier("share.standIn.cancel")
        }
    }
}
#endif
