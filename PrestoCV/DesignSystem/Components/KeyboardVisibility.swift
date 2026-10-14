import SwiftUI
import UIKit

/// Whether the on-screen keyboard is up, for screens that give the space back to the form while someone types.
@MainActor
final class KeyboardVisibility: ObservableObject {
    @Published private(set) var isVisible = false

    private let notificationCenter: NotificationCenter
    private var observers: [NSObjectProtocol] = []

    init(notificationCenter: NotificationCenter = .default) {
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
}

extension UIApplication {
    /// Closes the keyboard, whichever field has it.
    func dismissKeyboard() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
