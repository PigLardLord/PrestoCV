import CVRendering
import CVRenderingWebKitSupport

/// Why the app could not be assembled: one code for the one error screen the app shows (R13).
public enum CompositionFailure: String, Error, Equatable, Sendable, CaseIterable {
    case storeUnavailable
    case contentRulesUnavailable
    case launchFixturesRejected
    /// The headings the export prints could not be read
    case headingsUnavailable

    init(_ failure: AppPaths.Failure) {
        switch failure {
        case .storeUnavailable: self = .storeUnavailable
        }
    }

    init(_ failure: SecureWebViewConfiguration.Failure) {
        switch failure {
        case .contentRulesUnavailable: self = .contentRulesUnavailable
        }
    }

    init(_ failure: HeadingsCatalog.Failure) {
        self = .headingsUnavailable
    }

    #if DEBUG
    init(_ failure: LaunchFixtures.Failure) {
        self = .launchFixturesRejected
    }
    #endif
}
