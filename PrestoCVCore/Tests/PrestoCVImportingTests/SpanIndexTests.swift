import Testing
@testable import PrestoCVImporting

/// Which of many spans hold a span is found by its place, in the time of finding the place: a text of fifty thousand
/// lines asks it of every passage that no reader placed, and a search of all the lines for each is the square of them
/// (R8).
@Suite("Finding the spans that hold a span")
struct SpanIndexTests {

    private func brute(_ spans: [SourceSpan], holding span: SourceSpan) -> Int? {
        spans.firstIndex { $0.contains(span) }
    }

    @Test("The first span that holds a span is the first in the order given, whatever the spans and however they nest")
    func agreesWithTheSearchOfAll() {
        var generator = SplitMix(seed: 20_261_026)
        for _ in 0..<300 {
            let spans = (0..<Int(generator.next() % 30)).map { _ -> SourceSpan in
                let start = Int(generator.next() % 60)
                return SourceSpan(start, start + Int(generator.next() % 12))
            }
            let index = SpanIndex(spans)
            for _ in 0..<60 {
                let start = Int(generator.next() % 70)
                let span = SourceSpan(start, start + Int(generator.next() % 6))
                if index.firstHolding(span) != brute(spans, holding: span) || index.holds(span) != (brute(spans, holding: span) != nil) {
                    Issue.record("\(spans) holding \(span): \(String(describing: index.firstHolding(span))), not \(String(describing: brute(spans, holding: span)))")
                    return
                }
            }
        }
    }

    @Test("Many lines and many questions about them are a search of the lines for each question only in the order of their logarithm")
    func isNotASearchOfAll() {
        // 40,000 lines of ten characters, and a question about a passage of each
        expectLinear("questions", whole: 40_000, cost: { count in
            let spans = (0..<count).map { SourceSpan($0 * 11, $0 * 11 + 10) }
            var found = 0
            let seconds = cpuSeconds {
                let index = SpanIndex(spans)
                for line in spans.indices.reversed() {
                    if index.firstHolding(SourceSpan(line * 11 + 2, line * 11 + 6)) == line { found += 1 }
                }
            }
            #expect(found == spans.count)
            return seconds
        })
    }

    @Test("A span that holds all the others does not make each question a search of them")
    func nestingIsNotASearchOfAll() {
        // 40,000 lines, and after them the span of the whole text: the passage of each line is in two spans
        expectLinear("nesting", whole: 40_000, cost: { count in
            let lines = (0..<count).map { SourceSpan($0 * 11, $0 * 11 + 10) }
            let spans = lines + [SourceSpan(0, count * 11)]
            var found = 0
            var held = 0
            let seconds = cpuSeconds {
                let index = SpanIndex(spans)
                for line in lines.indices {
                    let passage = SourceSpan(line * 11 + 2, line * 11 + 6)
                    if index.firstHolding(passage) == line { found += 1 }
                    if index.holds(passage) { held += 1 }
                }
            }
            #expect(found == lines.count)
            #expect(held == lines.count)
            return seconds
        })
    }
}
