import Testing
import Foundation

// MARK: - Who confirms a share

/// The export sheet confirms a share only when it can back the confirmation: a save to Files, or a send by mail, by
/// message or by AirDrop. `ShareResult(activity:completed:failed:)` decides it from what the platform reports, and the
/// app's package tests it (`ExportShareFileTests`). The code that shows the system's share sheet only reports how the
/// sheet ended: a Release build never ends a share as saved or sent on its own. The macOS share picker once did, and
/// confirmed every service that went through, a copy or a note as well, as a send.
@Suite("Share confirmation - only the share result confirms a share")
struct ShareConfirmationTests {

    /// The code that shows the system's share sheet.
    private static let platform = "PrestoCVNext/Platform/"

    /// A share ended as saved or sent by its caller: `.saved` or `.sent` handed to a call, such as `end(.sent)`.
    private static let confirmation = try! NSRegularExpression(pattern: #"[(,:]\s*(?:ShareResult)?\.(?:saved|sent)\b"#)

    @Test("A Release build confirms a share only through the share result")
    func onlyTheShareResultConfirms() {
        let lines = ReleaseHygieneTests.shippedLines().filter { $0.file.hasPrefix(Self.platform) && !$0.isDebugOnly }
        let reports = lines.filter { $0.code.contains("ShareResult(activity:") }
        let confirming = lines.filter { line in
            Self.confirmation.firstMatch(in: line.code, range: NSRange(line.code.startIndex..., in: line.code)) != nil
        }

        #expect(!reports.isEmpty, "The scan no longer finds where the platform reports how a share ended")
        let places = confirming.map { "\($0.file):\($0.number)" }
        #expect(confirming.isEmpty, "A share confirmed by the platform: \(places)")
    }
}
