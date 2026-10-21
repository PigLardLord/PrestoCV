import SwiftUI
import UIKit

/// Whether the on-screen keyboard is up, for screens that give the space back to the form while someone types.
@MainActor
final class KeyboardVisibility: ObservableObject {
    @Published private(set) var isVisible = false

    private let notificationCenter: NotificationCenter
    private var observers: [NSObjectProtocol] = []

    init(notificationCenter: NotificationCenter) {
        self.notificationCenter = notificationCenter
        let show = notificationCenter.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.isVisible = true }
        }
        let hide = notificationCenter.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.isVisible = false }
        }
        observers = [show, hide]
    }

    deinit {
        observers.forEach(notificationCenter.removeObserver)
    }
}

extension View {
    /// Hides the tab bar of the tab this view is the content of while `condition` holds.
    func hidesTabBar(while condition: Bool) -> some View {
        toolbar(condition ? .hidden : .visible, for: .tabBar)
    }

    /// Adds a Done button above the keyboard that closes it. A text view has no Return key that does.
    func keyboardDoneButton() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("common.done".localized) {
                    UIApplication.shared.dismissKeyboard()
                }
            }
        }
    }

    /// Leaves room at the end of a scrolling form for the Done button that floats above the keyboard. A field that
    /// takes the focus is scrolled above the keyboard, and with this room above the Done button too, so that what is
    /// typed goes into a field the person sees.
    func keepsClearOfTheKeyboardDoneButton() -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: keyboardDoneButtonClearance)
        }
    }
}

/// The height of the Done button over the keyboard, with the gap above it.
private let keyboardDoneButtonClearance: CGFloat = 56

extension UIApplication {
    /// Closes the keyboard, whichever field has it.
    func dismissKeyboard() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
