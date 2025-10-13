#if canImport(FoundationModels)
import Foundation
import FoundationModels

/// Certification entry
@Generable
public struct Certification: Codable, Equatable, Sendable {
    @Guide(description: "Certification name (e.g., 'AWS Certified Solutions Architect', 'PMP')")
    public let name: String

    @Guide(description: "Issuing organization (e.g., 'Amazon Web Services', 'PMI')")
    public let issuer: String

    @Guide(description: "Date obtained (e.g., '2023', 'June 2022')")
    public let date: String

    @Guide(description: "Expiry date if applicable")
    public let expiryDate: String?

    @Guide(description: "Credential ID if mentioned")
    public let credentialId: String?

    @Guide(description: "Verification URL if mentioned")
    public let url: String?

    public init(
        name: String,
        issuer: String,
        date: String,
        expiryDate: String? = nil,
        credentialId: String? = nil,
        url: String? = nil
    ) {
        self.name = name
        self.issuer = issuer
        self.date = date
        self.expiryDate = expiryDate
        self.credentialId = credentialId
        self.url = url
    }
}
#endif
