#if canImport(FoundationModels)
import Foundation
import FoundationModels

/// Certification entry
@Generable
public struct Certification: Codable, Equatable, Sendable {
    @Guide(description: "Certification name exactly as written")
    public let name: String

    @Guide(description: "Issuing organization, only if the person said it; otherwise null")
    public let issuer: String?

    @Guide(description: "Date obtained exactly as written, only if the person said it; otherwise null")
    public let date: String?

    @Guide(description: "Verification address, only if the person gave it; otherwise null")
    public let url: String?

    public init(
        name: String,
        issuer: String? = nil,
        date: String? = nil,
        url: String? = nil
    ) {
        self.name = name
        self.issuer = issuer
        self.date = date
        self.url = url
    }
}
#endif
