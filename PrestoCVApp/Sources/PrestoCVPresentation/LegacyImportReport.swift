internal import PrestoCVApplication

/// Where the import report is. `removed` closes the sheet: the view announces it.
public enum LegacyReportState: Equatable, Sendable {
    case hidden, review, removing, removed
    /// The old copies were removed but this many stay on the device.
    case keptSome(Int)
}

/// A detail of a CV of the released app that the report names, in the order it lists them: one the new app has no place
/// for, or one the CV keeps as written for the person to check.
public enum LegacyDetail: CaseIterable, Hashable, Sendable {
    case look, email, phone, website, skillLevel, certificationYear, certificationLink, profile, documentLanguage
    /// A date the import could not read for certain.
    case period

    init(_ drop: LegacyDrop) {
        switch drop {
        case .look: self = .look
        case .email: self = .email
        case .phone: self = .phone
        case .website: self = .website
        case .skillLevel: self = .skillLevel
        case .certificationYear: self = .certificationYear
        case .certificationLink: self = .certificationLink
        case .profile: self = .profile
        case .documentLanguage: self = .documentLanguage
        }
    }

    init(_ check: LegacyCheck) {
        switch check {
        case .period: self = .period
        }
    }

    /// Each detail once, in the report's order.
    static func ordered(_ details: [LegacyDetail]) -> [LegacyDetail] {
        let named = Set(details)
        return allCases.filter(named.contains)
    }
}

/// A CV the import report names, by the label the list shows for it, with the details of one group: those it lost, or
/// those it keeps for the person to check.
public struct LegacyReportRow: Identifiable, Hashable, Sendable {
    public let id: CVReference
    public let label: String
    public let details: [LegacyDetail]
}

/// Why old CVs are missing from the app, as the person can act on it.
public enum NotImportedCause: Hashable, Sendable {
    /// The file is damaged: it stays on the device.
    case damaged
    /// The app could not save the CV: it tries again at the next launch.
    case notSaved

    init(_ leftOut: LegacyLeftOut) {
        switch leftOut {
        case .damaged: self = .damaged
        case .notSaved: self = .notSaved
        }
    }
}

public struct NotImportedCount: Hashable, Sendable {
    public let cause: NotImportedCause
    public let count: Int
}

/// The notice on the list while old CVs are missing from the app.
public enum LegacyImportNotice: Equatable, Sendable {
    /// This many old CVs were not imported; their files stay and the next launch reads them again.
    case notImported(Int)
    /// The import did not run, so how many it left out is unknown; it runs again at the next launch.
    case didNotRun
}
