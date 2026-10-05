import SwiftSyntax

/// The nesting and the decisions of one function so far (ADR 0021 (c)): what `BodyShapeVisitor` collects while it
/// walks the function, and the findings it ends in.
struct FunctionShape {
    let body: Body
    private(set) var complexity = 1
    private var depth = 0
    private var deepest = 0
    private var firstTooDeepLine: Int?

    init(of body: Body) { self.body = body }

    mutating func decide(_ decisions: Int) { complexity += decisions }

    mutating func enterLevel(at line: Int) {
        depth += 1
        deepest = max(deepest, depth)
        if depth > Limits.nesting, firstTooDeepLine == nil { firstTooDeepLine = line }
    }

    mutating func exitLevel() { depth -= 1 }

    /// A finding for the complexity, one for the nesting, or neither.
    var hits: [Hit] { [complexityHit, nestingHit].compactMap { $0 } }

    private var complexityHit: Hit? {
        guard complexity > Limits.complexity else { return nil }
        return Hit(measured: "cyclomaticComplexity", "\(body.name) has a cyclomatic complexity of \(complexity), at most \(Limits.complexity)",
                   line: body.line)
    }

    /// Points at the first construct that goes over the limit.
    private var nestingHit: Hit? {
        guard let line = firstTooDeepLine else { return nil }
        return Hit(measured: "nestingDepth", "\(body.name) nests \(deepest) levels deep, at most \(Limits.nesting)", line: line)
    }
}
