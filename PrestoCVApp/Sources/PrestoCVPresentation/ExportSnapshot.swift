internal import PrestoCVDomain

/// The CV as the editor shows it at one moment, stored or not, for an export. Only this target reads what it holds.
public struct ExportSnapshot: Sendable {
    let cv: CV

    init(cv: CV) { self.cv = cv }
}
