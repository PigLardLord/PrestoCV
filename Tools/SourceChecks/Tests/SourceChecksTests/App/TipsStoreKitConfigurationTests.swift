import Foundation
import Testing

// MARK: - The StoreKit configuration of the tip jar

/// The simulator sells the tips from a StoreKit configuration file when the app runs from Xcode (ADR 0040). It must
/// sell what the adapter asks the store for, at the prices of #213, and only the run action may name it: the UI tests
/// answer through `-PrestoCVNextTips`, and a test-only file must never reach a Release bundle, so it lives outside the
/// app's folders.
@Suite("The StoreKit configuration of the tip jar")
struct TipsStoreKitConfigurationTests {

    private static let configuration = "TestPlans/StoreKit/Tips.storekit"
    private static let adapter = "PrestoCVApp/Sources/PrestoCVTipsStoreKit/StoreKitTips+Offers.swift"
    private static let scheme = "PrestoCV.xcodeproj/xcshareddata/xcschemes/PrestoCV.xcscheme"

    private struct Configuration: Decodable {
        struct Product: Decodable {
            let productID: String
            let displayPrice: String
            let type: String
        }
        struct Settings: Decodable {
            let storefront: String

            enum CodingKeys: String, CodingKey { case storefront = "_storefront" }
        }
        let products: [Product]
        let settings: Settings
        let subscriptionGroups: [[String: String]]
        let nonRenewingSubscriptions: [[String: String]]
    }

    private static func read() throws -> Configuration {
        try JSONDecoder().decode(Configuration.self, from: Data(try Repository.text(configuration).utf8))
    }

    /// The product identifiers the adapter asks the store for, as its source writes them.
    private static func askedFor() throws -> [String] {
        let text = try Repository.text(adapter)
        let pattern = try Regex(#""(com\.PigLardLord\.prestocv\.tip\.[a-z]+)""#)
        return text.matches(of: pattern).compactMap { $0.output[1].substring.map(String.init) }
    }

    @Test("the file sells the three tips the adapter asks for, as consumables at €1.99, €4.99 and €9.99")
    func sellsTheThreeTips() throws {
        let file = try Self.read()
        let prices = Dictionary(uniqueKeysWithValues: file.products.map { ($0.productID, $0.displayPrice) })

        #expect(try Self.askedFor().sorted() == prices.keys.sorted())
        #expect(prices == [
            "com.PigLardLord.prestocv.tip.small": "1.99",
            "com.PigLardLord.prestocv.tip.medium": "4.99",
            "com.PigLardLord.prestocv.tip.large": "9.99",
        ])
        #expect(file.products.map(\.type) == ["Consumable", "Consumable", "Consumable"])
        #expect(file.subscriptionGroups.isEmpty && file.nonRenewingSubscriptions.isEmpty)
        #expect(file.settings.storefront == "DEU", "A storefront that pays in euros, so the prices read as #213 gives them")
    }

    @Test("only the run action of the app's scheme names the file; no test action, test plan or project does")
    func onlyTheRunActionNamesIt() throws {
        let naming = try Repository.presentFiles()
            .filter { path in [".xcscheme", ".xctestplan", ".pbxproj"].contains { path.hasSuffix($0) } }
            .filter { try Repository.text($0).contains(".storekit") }
        #expect(naming == [Self.scheme])

        let text = try Repository.text(Self.scheme)
        let launch = try #require(text.range(of: "<LaunchAction")).lowerBound
        let launchEnd = try #require(text.range(of: "</LaunchAction>")).upperBound
        let references = text.ranges(of: "<StoreKitConfigurationFileReference")
        #expect(references.count == 1)
        #expect(references.allSatisfy { (launch..<launchEnd).contains($0.lowerBound) })
        #expect(text.contains(#"identifier = "../../\#(Self.configuration)""#))
    }
}
