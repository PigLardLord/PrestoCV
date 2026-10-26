import Foundation

/// Where the app runs, as the AI entry tells it apart. Every Mac that runs the app can run Apple Intelligence, and its
/// settings are in System Settings.
enum AIPlatform: Equatable, CaseIterable {
    case iPhoneOrIPad
    /// The iPad app, on a Mac with Apple silicon.
    case mac

    /// The platform of this process.
    static var current: AIPlatform {
        ProcessInfo.processInfo.isiOSAppOnMac ? .mac : .iPhoneOrIPad
    }
}
