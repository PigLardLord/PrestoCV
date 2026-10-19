import Foundation
import PrestoCVCore

/// An example CV as the sheet of examples lists it.
struct ExampleChoice: Identifiable, Equatable {
    let sample: CVModel
    /// The job the example is for, or "Untitled CV" when it names none
    let title: String
    /// What the example says of its person
    let summary: String

    var id: UUID { sample.id }
}
