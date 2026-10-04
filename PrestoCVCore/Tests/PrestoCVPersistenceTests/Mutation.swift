import Testing
import Foundation

/// One change to a pinned file that must make it corrupt. It fails when the pinned file no longer holds what it changes, so
/// a case cannot pass because it changed nothing.
struct Mutation: CustomTestStringConvertible, Sendable {
    let name: String, from: String, to: String
    var testDescription: String { name }

    func apply(to golden: String) throws -> String {
        guard golden.contains(from) else { throw Failure(description: "the pinned file no longer holds \(from)") }
        return golden.replacingOccurrences(of: from, with: to)
    }

    struct Failure: Error, CustomStringConvertible { let description: String }
}
