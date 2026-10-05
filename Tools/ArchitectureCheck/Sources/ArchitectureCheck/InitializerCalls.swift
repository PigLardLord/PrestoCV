import SwiftSyntax

extension InitializerDeclSyntax {
    /// Whether a call can mean this initialiser, judged by labels alone: the labels of the arguments are those of the
    /// parameters in order, a parameter with a default value may be left out, and a variadic parameter takes any number of
    /// arguments, none included.
    func canBeCalled(by call: FunctionCallExprSyntax) -> Bool {
        Self.accepts(ArraySlice(signature.parameterClause.parameters), ArraySlice(call.arguments.map { $0.label?.text }))
    }

    /// Whether any parameter takes any number of arguments. Such an initialiser is never a data initialiser.
    var isVariadic: Bool { signature.parameterClause.parameters.contains { $0.ellipsis != nil } }

    private static func accepts(_ parameters: ArraySlice<FunctionParameterSyntax>, _ labels: ArraySlice<String?>) -> Bool {
        guard let parameter = parameters.first else { return labels.isEmpty }
        let rest = parameters.dropFirst()
        return takes(parameter, rest, labels) || (parameter.canBeLeftOut && accepts(rest, labels))
    }

    /// The parameter takes the first argument, and when it is variadic the unlabeled ones that follow.
    private static func takes(_ parameter: FunctionParameterSyntax, _ rest: ArraySlice<FunctionParameterSyntax>,
                              _ labels: ArraySlice<String?>) -> Bool {
        guard labels.first == .some(parameter.callLabel) else { return false }
        let after = labels.dropFirst()
        guard parameter.ellipsis != nil else { return accepts(rest, after) }
        return (0...after.prefix { $0 == nil }.count).contains { accepts(rest, after.dropFirst($0)) }
    }
}

extension FunctionParameterSyntax {
    /// The label of the argument for the parameter; nil when it takes none.
    var callLabel: String? { firstName.text == "_" ? nil : firstName.text }

    /// A parameter with a default value, or a variadic one, takes no argument when the call has none for it.
    var canBeLeftOut: Bool { defaultValue != nil || ellipsis != nil }
}
