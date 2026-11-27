import Foundation
import Observation
import PrestoCVWorkflowPorts

/// The Settings sheet (#405): its groups in order and the rows of each, as codes the view words (R13). Every value comes
/// from the composition, so the sheet reads no bundle and no system setting itself (R17).
@MainActor
@Observable
public final class SettingsViewModel {

    /// The groups in order. Diagnostics comes last, and only while the trace of a test build records (`appear()`).
    public var groups: [SettingsGroup] {
        isDiagnosticsOffered ? fixedGroups + [SettingsGroup(kind: .diagnostics, rows: [.diagnostics])] : fixedGroups
    }
    /// Shown under the support row as written, also when it makes no mail link.
    public let supportAddress: String
    public let appName: String
    private let fixedGroups: [SettingsGroup]
    private var isDiagnosticsOffered = false
    private var hasAsked = false
    @ObservationIgnored private let diagnostics: any DiagnosticsReading

    /// A link the composition could not make (nil) leaves its row out, as an address that makes no mail link does, and
    /// Legal with no row is left out; Support stays, for the address.
    public init(
        supportAddress: String, privacyPolicy: URL?, sourceCode: URL?, version: String, build: String, appName: String,
        diagnostics: any DiagnosticsReading
    ) {
        self.diagnostics = diagnostics
        self.supportAddress = supportAddress
        self.appName = appName
        let source = sourceCode.map { [SettingsRow.sourceCode($0)] } ?? []
        fixedGroups = [
            SettingsGroup(kind: .support, rows: Self.mailLink(to: supportAddress).map { [.contactSupport($0)] } ?? []),
            SettingsGroup(kind: .tips, rows: [.tips]),
            privacyPolicy.map { SettingsGroup(kind: .legal, rows: [.privacyPolicy($0)]) },
            SettingsGroup(kind: .openSource, rows: [.openSourceStatement, .licences] + source),
            SettingsGroup(kind: .about, rows: [.version(version), .build(build)]),
        ].compactMap { $0 }
    }

    /// Asks once whether the Diagnostics row is offered, when the sheet appears. It fails closed: until the answer comes,
    /// and for every build that may not record, the row is not there. A later call asks nothing.
    public func appear() async {
        guard !hasAsked else { return }
        hasAsked = true
        isDiagnosticsOffered = await diagnostics.isAvailable()
    }

    /// A mail to the address with no subject and no body, so that nothing about the person or the device goes with it.
    private static func mailLink(to address: String) -> URL? {
        var link = URLComponents()
        link.scheme = "mailto"
        link.path = address
        return link.url
    }
}

/// One group of the sheet: what it is about and its rows, in order.
public struct SettingsGroup: Hashable, Sendable {
    public enum Kind: Hashable, Sendable { case support, tips, legal, openSource, about, diagnostics }

    public let kind: Kind
    public let rows: [SettingsRow]
}

/// A row of the sheet. A link opens outside the app; `licences` opens the Licences screen and `openSourceStatement` is
/// a text with no action. `tips` opens the tip jar. `diagnostics` opens the Diagnostics screen of a test build.
public enum SettingsRow: Hashable, Sendable {
    case contactSupport(URL)
    case privacyPolicy(URL)
    case openSourceStatement
    case licences
    case tips
    case sourceCode(URL)
    case version(String)
    case build(String)
    case diagnostics
}
