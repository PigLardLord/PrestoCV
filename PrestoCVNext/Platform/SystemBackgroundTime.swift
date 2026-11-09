import PrestoCVPresentation
#if os(iOS)
import UIKit
#endif

/// The time the system grants the app to end its work after the person left it. On iOS it is a background task of
/// `UIApplication`, given back by the first `end()` of the hold or when iOS takes the time back, whichever comes first: a
/// task iOS ends with the time still asked for would end the app. macOS does not suspend an app that leaves the
/// foreground, so its hold asks for nothing.
struct SystemBackgroundTime: BackgroundTime {
    @MainActor
    func hold() -> BackgroundHold {
        #if os(iOS)
        let application = UIApplication.shared
        let task = BackgroundTask()
        let hold = BackgroundHold { task.end(in: application) }
        task.identifier = application.beginBackgroundTask { hold.end() }
        return hold
        #else
        return BackgroundHold(end: {})
        #endif
    }
}

#if os(iOS)
/// The background task asked of `UIApplication`, ended once.
@MainActor
private final class BackgroundTask {
    var identifier = UIBackgroundTaskIdentifier.invalid

    func end(in application: UIApplication) {
        guard identifier != .invalid else { return }
        application.endBackgroundTask(identifier)
        identifier = .invalid
    }
}
#endif
