import SwiftSyntax

extension InitializerDeclSyntax {
    /// Whether a call can mean this initialiser, judged by labels alone: the labels of the arguments are those of the
    /// parameters in order, a parameter with a default value may be left out, and a variadic parameter takes any number of
    /// arguments, none included.
    func canBeCalled(by call: FunctionCallExprSyntax) -> Bool {
        LabelFit(parameters: Array(signature.parameterClause.parameters), labels: call.arguments.map { $0.label?.text }).fits
    }

    /// What matching the labels of a call against this initialiser costs: one step for each parameter and argument pair.
    func matchingCost(of call: FunctionCallExprSyntax) -> Int {
        signature.parameterClause.parameters.count * (call.arguments.count + 1)
    }

    /// Whether any parameter takes any number of arguments. Such an initialiser is never a data initialiser.
    var isVariadic: Bool { signature.parameterClause.parameters.contains { $0.ellipsis != nil } }
}

/// Whether the labels of the arguments of a call fit the parameters of an initialiser, in order. It is a table, parameters
/// by arguments, filled once, so that many defaulted or variadic parameters cost no more than their number times the number
/// of arguments.
private struct LabelFit {
    let parameters: [FunctionParameterSyntax]
    let labels: [String?]
    /// For each position among the arguments: how many unlabeled arguments follow one after another from there, which a
    /// variadic parameter takes after the first one it is given.
    private let unlabeledRuns: [Int]

    init(parameters: [FunctionParameterSyntax], labels: [String?]) {
        self.parameters = parameters
        self.labels = labels
        var runs = [Int](repeating: 0, count: labels.count + 1)
        for position in labels.indices.reversed() where labels[position] == nil { runs[position] = runs[position + 1] + 1 }
        unlabeledRuns = runs
    }

    var fits: Bool {
        var next = (0...labels.count).map { $0 == labels.count }   // no parameter left: only a call with no argument left fits
        for parameter in parameters.reversed() { next = row(for: parameter, after: next) }
        return next[0]
    }

    /// For each position among the arguments: whether this parameter and the ones after it fit the arguments from there.
    private func row(for parameter: FunctionParameterSyntax, after next: [Bool]) -> [Bool] {
        (0...labels.count).map { position in
            (parameter.canBeLeftOut && next[position]) || takes(parameter, at: position, after: next)
        }
    }

    private func takes(_ parameter: FunctionParameterSyntax, at position: Int, after next: [Bool]) -> Bool {
        guard position < labels.count, labels[position] == parameter.callLabel else { return false }
        guard parameter.ellipsis != nil else { return next[position + 1] }
        return (0...unlabeledRuns[position + 1]).contains { next[position + 1 + $0] }
    }
}

extension FunctionParameterSyntax {
    /// The label of the argument for the parameter; nil when it takes none.
    var callLabel: String? { firstName.text == "_" ? nil : firstName.text }

    /// A parameter with a default value, or a variadic one, takes no argument when the call has none for it.
    var canBeLeftOut: Bool { defaultValue != nil || ellipsis != nil }
}
