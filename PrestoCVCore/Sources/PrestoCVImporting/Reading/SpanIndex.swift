/// Many spans of the text, and which of them hold a span: asked by its place, in the time of finding the place and of
/// naming the spans that hold it, not of reading all of them (R8). A text of fifty thousand lines asks it of every
/// passage that no reader placed, and a search of all the lines for each passage is the square of them.
struct SpanIndex {
    /// The lower bounds of the spans, in order.
    private let lowers: [Int]
    /// The position in the list given of the span at each place.
    private let originals: [Int]
    /// The greatest upper bound among the spans up to each place.
    private let reach: [Int]
    /// The greatest upper bound under each node of a binary tree over the places, rounded up to a power of two.
    private let tree: [Int]
    private let leaves: Int

    init(_ spans: [SourceSpan]) {
        let places = spans.indices.sorted { (spans[$0].lowerBound, $0) < (spans[$1].lowerBound, $1) }
        lowers = places.map { spans[$0].lowerBound }
        originals = places
        var reach: [Int] = []
        reach.reserveCapacity(places.count)
        for place in places { reach.append(max(reach.last ?? Int.min, spans[place].upperBound)) }
        self.reach = reach
        var leaves = 1
        while leaves < places.count { leaves *= 2 }
        var tree = [Int](repeating: Int.min, count: 2 * leaves)
        for (index, place) in places.enumerated() { tree[leaves + index] = spans[place].upperBound }
        for node in stride(from: leaves - 1, through: 1, by: -1) { tree[node] = max(tree[2 * node], tree[2 * node + 1]) }
        self.tree = tree
        self.leaves = leaves
    }

    /// Whether a span holds the span: it starts no later and ends no earlier.
    func holds(_ span: SourceSpan) -> Bool {
        let end = placesStarting(atOrBefore: span.lowerBound)
        return end > 0 && reach[end - 1] >= span.upperBound
    }

    /// The position in the list given of the first span that holds the span.
    func firstHolding(_ span: SourceSpan) -> Int? {
        let end = placesStarting(atOrBefore: span.lowerBound)
        guard end > 0, reach[end - 1] >= span.upperBound else { return nil }
        var first: Int?
        // Down the tree to the places before `end` whose spans end late enough: a node whose spans end too early holds none
        var pending = [(node: 1, low: 0, high: leaves)]
        while let (node, low, high) = pending.popLast() {
            guard low < end, tree[node] >= span.upperBound else { continue }
            if high - low == 1 {
                first = min(first ?? originals[low], originals[low])
            } else {
                let middle = (low + high) / 2
                pending.append((2 * node + 1, middle, high))
                pending.append((2 * node, low, middle))
            }
        }
        return first
    }

    /// How many spans start at or before the bound.
    private func placesStarting(atOrBefore bound: Int) -> Int {
        var low = 0
        var high = lowers.count
        while low < high {
            let middle = (low + high) / 2
            if lowers[middle] <= bound { low = middle + 1 } else { high = middle }
        }
        return low
    }
}
