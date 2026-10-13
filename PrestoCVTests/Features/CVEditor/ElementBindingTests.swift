import Testing
import SwiftUI
@testable import PrestoCV

// MARK: - Bounds-checked Binding Tests

/// Holds the array a test binds to, so that the binding's closures capture a reference.
private final class Names: @unchecked Sendable {
    var values: [String]

    init(_ values: [String]) {
        self.values = values
    }

    var binding: Binding<[String]> {
        Binding(get: { self.values }, set: { self.values = $0 })
    }
}

@MainActor
@Suite("Binding(element:of:) Tests - a row outlives its item")
struct ElementBindingTests {

    @Test("It reads and writes the element at its index")
    func readsAndWritesTheElement() {
        let names = Names(["Swift", "Kotlin"])

        let second = Binding(element: 1, of: names.binding)
        second.wrappedValue = "Rust"

        #expect(second.wrappedValue == "Rust")
        #expect(names.values == ["Swift", "Rust"])
    }

    @Test("It keeps showing the last value once its element is removed")
    func keepsShowingTheValueAfterRemoval() {
        let names = Names(["Swift", "Kotlin"])
        let second = Binding(element: 1, of: names.binding)

        names.values.removeLast()

        #expect(second.wrappedValue == "Kotlin", "A row still on screen must not crash the app")
    }

    @Test("It ignores writes once its element is removed")
    func ignoresWritesAfterRemoval() {
        let names = Names(["Swift", "Kotlin"])
        let second = Binding(element: 1, of: names.binding)

        names.values.removeLast()
        second.wrappedValue = "Rust"

        #expect(names.values == ["Swift"])
    }
}
