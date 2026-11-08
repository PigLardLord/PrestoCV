import CVRenderingWebKitSupport

/// Why the app could not be assembled: one code for the one error screen the app shows (R13).
public enum CompositionFailure: String, Error, Equatable, Sendable, CaseIterable {
    case storeUnavailable
    case contentRulesUnavailable
    case launchFixturesRejected

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

    #if DEBUG
    init(_ failure: LaunchFixtures.Failure) {
        self = .launchFixturesRejected
    }
    #endif
}
