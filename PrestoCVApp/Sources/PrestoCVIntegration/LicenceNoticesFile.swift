import Foundation
import PrestoCVWorkflowPorts

/// The `LicenceNoticesReading` adapter over the notices file the app bundles (#504): each licence's text once, under
/// `licences`, and the `notices` in the order the screen lists them, each naming its licence by id. The composition
/// gives the bytes of the file; reading it is its job, decoding it is this adapter's.
public struct LicenceNoticesFile: LicenceNoticesReading {

    public enum Failure: Error, Equatable {
        /// The bytes are not a notices file.
        case unreadable
        /// A notice names a licence the file does not hold, by that id.
        case unknownLicence(String)
        /// The file holds two notices with the same id, by that id.
        case duplicateNotice(String)
        /// The file holds two licences with the same id, by that id.
        case duplicateLicence(String)
    }

    private let contents: @Sendable () async throws -> Data

    /// `contents` reads the file each time the screen asks; its errors, a cancellation included, pass through unchanged.
    public init(contents: @escaping @Sendable () async throws -> Data) {
        self.contents = contents
    }

    public func notices() async throws -> [LicenceNotice] {
        let data = try await contents()
        let file: NoticesFile
        do {
            file = try JSONDecoder().decode(NoticesFile.self, from: data)
        } catch {
            throw Failure.unreadable
        }
        var licences: [String: NoticesFile.LicenceText] = [:]
        for licence in file.licences {
            guard licences.updateValue(licence, forKey: licence.id) == nil else { throw Failure.duplicateLicence(licence.id) }
        }
        var noticeIDs: Set<String> = []
        for notice in file.notices {
            guard noticeIDs.insert(notice.id).inserted else { throw Failure.duplicateNotice(notice.id) }
        }
        return try file.notices.map { notice in
            guard let licence = licences[notice.licence] else { throw Failure.unknownLicence(notice.licence) }
            return LicenceNotice(id: notice.id, title: notice.title, isThirdParty: notice.thirdParty, text: notice.text,
                                 licence: Licence(id: licence.id, name: licence.name, text: licence.text))
        }
    }
}

/// The file as it is written.
private struct NoticesFile: Decodable {
    struct LicenceText: Decodable {
        let id: String
        let name: String
        let text: String
    }

    struct Notice: Decodable {
        let id: String
        let title: String
        let licence: String
        let thirdParty: Bool
        let text: String
    }

    let licences: [LicenceText]
    let notices: [Notice]
}
