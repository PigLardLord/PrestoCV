import CVRendering

/// #558: how a printed layout differs from its reference. Lines are told apart by their text; a page is 0 first.
public enum LayoutDifference: Sendable, Equatable {
    /// The PDF has another number of pages.
    case pageCount(reference: Int, found: Int)
    /// A line of the reference that the PDF does not have.
    case missing(page: Int, text: String)
    /// A line of the PDF that the reference does not have.
    case extra(page: Int, text: String)
    /// A line that is on another page.
    case otherPage(text: String, reference: Int, found: Int)
    /// A line whose box moved or changed size by more than the tolerance, by how much, in points.
    case moved(page: Int, text: String, dx: Double, dy: Double, dwidth: Double, dheight: Double)
}

/// #558: compares a printed layout with a reference, line by line in order.
public enum LayoutComparison {
    /// How far a line may move from its reference, in points, as #558 proposes it. iPhone, iPad and macOS print further
    /// apart than this, so the checks that compare a print with a reference wait for the owner's choice of tolerance.
    public static let tolerance = 0.5

    /// Every difference of `found` from `reference`: the page count, then each line, in the reference's order.
    public static func differences(_ found: PDFLayout, from reference: PDFLayout, tolerance: Double = tolerance) -> [LayoutDifference] {
        var differences: [LayoutDifference] = []
        if found.pages.count != reference.pages.count {
            differences.append(.pageCount(reference: reference.pages.count, found: found.pages.count))
        }
        for step in alignment(reference.lines.map(\.text), found.lines.map(\.text)) {
            switch step {
            case .missing(let index):
                differences.append(.missing(page: reference.lines[index].pageIndex, text: reference.lines[index].text))
            case .extra(let index):
                differences.append(.extra(page: found.lines[index].pageIndex, text: found.lines[index].text))
            case .same(let referenceIndex, let foundIndex):
                differences += difference(found.lines[foundIndex], from: reference.lines[referenceIndex], tolerance: tolerance)
            }
        }
        return differences
    }

    private static func difference(_ found: PDFTextLine, from reference: PDFTextLine, tolerance: Double) -> [LayoutDifference] {
        guard found.pageIndex == reference.pageIndex else {
            return [.otherPage(text: reference.text, reference: reference.pageIndex, found: found.pageIndex)]
        }
        let dx = found.box.x - reference.box.x, dy = found.box.y - reference.box.y
        let dwidth = found.box.width - reference.box.width, dheight = found.box.height - reference.box.height
        guard [dx, dy, dwidth, dheight].contains(where: { abs($0) > tolerance }) else { return [] }
        return [.moved(page: reference.pageIndex, text: reference.text, dx: dx, dy: dy, dwidth: dwidth, dheight: dheight)]
    }

    private enum Step: Equatable {
        case same(Int, Int), missing(Int), extra(Int)
    }

    /// The longest common subsequence of the two texts, in order, with the lines outside it as missing or extra: so a
    /// line that is missing does not make every line after it differ. Where both sides have a line outside it, the
    /// reference's comes first.
    private static func alignment(_ reference: [String], _ found: [String]) -> [Step] {
        // common[i][j]: the length of the longest common subsequence of reference[i...] and found[j...].
        var common = Array(repeating: Array(repeating: 0, count: found.count + 1), count: reference.count + 1)
        for i in stride(from: reference.count - 1, through: 0, by: -1) {
            for j in stride(from: found.count - 1, through: 0, by: -1) {
                common[i][j] = reference[i] == found[j] ? common[i + 1][j + 1] + 1 : max(common[i + 1][j], common[i][j + 1])
            }
        }
        var steps: [Step] = [], i = 0, j = 0
        while i < reference.count || j < found.count {
            if i < reference.count, j < found.count, reference[i] == found[j] {
                steps.append(.same(i, j)); i += 1; j += 1
            } else if j == found.count || (i < reference.count && common[i + 1][j] >= common[i][j + 1]) {
                steps.append(.missing(i)); i += 1
            } else {
                steps.append(.extra(j)); j += 1
            }
        }
        return steps
    }
}

extension LayoutDifference: CustomStringConvertible {
    /// The difference as a failing test shows it, its pages counted from 1 and its points rounded to 0.01.
    public var description: String {
        switch self {
        case .pageCount(let reference, let found):
            "\(reference) pages in the reference, \(found) found"
        case .missing(let page, let text):
            "page \(page + 1): \"\(text)\" is missing"
        case .extra(let page, let text):
            "page \(page + 1): \"\(text)\" is extra"
        case .otherPage(let text, let reference, let found):
            "\"\(text)\" is on page \(found + 1), on page \(reference + 1) in the reference"
        case .moved(let page, let text, let dx, let dy, let dwidth, let dheight):
            "page \(page + 1): \"\(text)\" moved by x \(Self.signed(dx)), y \(Self.signed(dy)), width \(Self.signed(dwidth)), "
                + "height \(Self.signed(dheight))"
        }
    }

    private static func signed(_ value: Double) -> String {
        let text = LayoutReference.number(value)
        return text.hasPrefix("-") ? text : "+" + text
    }
}
