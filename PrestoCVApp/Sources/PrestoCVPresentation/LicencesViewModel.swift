import Observation
import PrestoCVWorkflowPorts

/// The Licences screen (#504): the notices the app ships, each with the name of its licence, read through
/// `LicenceNoticesReading` when the screen asks for them, never at init.
@MainActor
@Observable
public final class LicencesViewModel {

    public private(set) var state: LicencesState = .loading
    private var notices: [LicenceNotice] = []
    @ObservationIgnored private let reading: any LicenceNoticesReading
    @ObservationIgnored private var latestLoad = 0

    public init(reading: any LicenceNoticesReading) {
        self.reading = reading
    }

    public var rows: [LicenceRow] {
        notices.map { LicenceRow(id: $0.id, title: $0.title, licenceName: $0.licence.name) }
    }

    /// `noOthers` once the notices are read and none is about the work of others: the screen then says so under the rows.
    public var othersState: LicencesOthers? {
        state == .loaded && !notices.contains(where: \.isThirdParty) ? .noOthers : nil
    }

    /// The notice and the text of its licence, each in paragraphs; nil for an id the screen does not list.
    public func detail(of id: String) -> LicenceDetail? {
        notices.first { $0.id == id }.map {
            LicenceDetail(title: $0.title, noticeParagraphs: Self.paragraphs(of: $0.text),
                          licenceParagraphs: Self.paragraphs(of: $0.licence.text))
        }
    }

    /// Reads the notices; a read that fails is `failed` and a new call tries again. Only the latest call changes the
    /// screen: a read that ends after a newer call started, with rows, an error or a cancellation, changes nothing.
    public func load() async {
        latestLoad += 1
        let thisLoad = latestLoad
        state = .loading
        do {
            let read = try await reading.notices()
            guard thisLoad == latestLoad else { return }
            notices = read
            state = .loaded
        } catch is CancellationError {
            return
        } catch {
            guard thisLoad == latestLoad else { return }
            notices = []
            state = .failed
        }
    }

    /// The lines between blank lines, each paragraph's own line breaks kept.
    private static func paragraphs(of text: String) -> [String] {
        text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
            .split { $0.allSatisfy(\.isWhitespace) }
            .map { $0.joined(separator: "\n") }
    }
}

public enum LicencesState: Hashable, Sendable { case loading, loaded, failed }

public enum LicencesOthers: Hashable, Sendable { case noOthers }

public struct LicenceRow: Hashable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let licenceName: String
}

public struct LicenceDetail: Hashable, Sendable {
    public let title: String
    public let noticeParagraphs: [String]
    public let licenceParagraphs: [String]
}
