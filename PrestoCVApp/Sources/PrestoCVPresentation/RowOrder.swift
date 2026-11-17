import Foundation

/// The new order of a section's rows after a move, as the places the rows had: `[2, 0, 1]` puts the third row first.
/// Nil means that no row changes place.
enum RowOrder {

    /// The row at `index` of `count` rows moved `offset` places, up for a negative offset; nil when the offset is 0, or
    /// when the row or its new place is not among the rows.
    static func moving(_ index: Int, by offset: Int, among count: Int) -> [Int]? {
        let places = Array(0..<count)
        guard offset != 0, places.indices.contains(index), (-index..<count - index).contains(offset) else {
            return nil
        }
        var order = places
        order.remove(at: index)
        order.insert(index, at: index + offset)
        return order
    }

    /// The rows at `offsets` moved, in their order, before the row that stood at `destination` (`count` puts them
    /// last), as a list's drag reports a move; nil when no row changes place, or when an offset or the destination is
    /// not among the rows.
    static func moving(_ offsets: IndexSet, to destination: Int, among count: Int) -> [Int]? {
        let places = Array(0..<count)
        guard !offsets.isEmpty, offsets.allSatisfy(places.indices.contains), (0...count).contains(destination) else {
            return nil
        }
        var order = places.filter { !offsets.contains($0) }
        order.insert(contentsOf: offsets, at: destination - offsets.filter { $0 < destination }.count)
        return order == places ? nil : order
    }

    /// `rows` in `order`; `rows` as they are when `order` does not hold each of their places once.
    static func arranged<Row>(_ rows: [Row], in order: [Int]) -> [Row] {
        guard order.count == rows.count, Set(order) == Set(rows.indices) else { return rows }
        return order.map { rows[$0] }
    }
}

extension EditorContent {

    /// The ids of the section's rows, in order.
    func rowIDs(in section: EditorSection) -> [RowID] {
        switch section {
        case .experiences: experiences.map(\.id)
        case .education: education.map(\.id)
        case .skills: skills.map(\.id)
        case .languages: languages.map(\.id)
        case .certifications: certifications.map(\.id)
        case .profiles: profiles.map(\.id)
        case .interests: interests.map(\.id)
        }
    }

    /// Puts the section's rows in `order`, the places they had (`RowOrder`).
    mutating func arrange(_ section: EditorSection, in order: [Int]) {
        switch section {
        case .experiences: experiences = RowOrder.arranged(experiences, in: order)
        case .education: education = RowOrder.arranged(education, in: order)
        case .skills: skills = RowOrder.arranged(skills, in: order)
        case .languages: languages = RowOrder.arranged(languages, in: order)
        case .certifications: certifications = RowOrder.arranged(certifications, in: order)
        case .profiles: profiles = RowOrder.arranged(profiles, in: order)
        case .interests: interests = RowOrder.arranged(interests, in: order)
        }
    }
}
