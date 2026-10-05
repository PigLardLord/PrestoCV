import SwiftSyntax

extension InitializerDeclSyntax {
    /// Whether a call can mean this initialiser, judged by labels alone: the labels of the arguments are those of the
    /// parameters in order, any parameter with a default value may be left out, and a variadic parameter rules it out.
    func canBeCalled(by call: FunctionCallExprSyntax) -> Bool {
        let parameters = signature.parameterClause.parameters
        guard !parameters.contains(where: { $0.ellipsis != nil }) else { return false }
        return Self.accepts(ArraySlice(parameters), ArraySlice(call.arguments.map { $0.label?.text }))
    }

    private static func accepts(_ parameters: ArraySlice<FunctionParameterSyntax>, _ labels: ArraySlice<String?>) -> Bool {
        guard let parameter = parameters.first else { return labels.isEmpty }
        let rest = parameters.dropFirst()
        let takesLabel = labels.first == .some(parameter.callLabel) && accepts(rest, labels.dropFirst())
        let isSkipped = parameter.defaultValue != nil && accepts(rest, labels)
        return takesLabel || isSkipped
    }
}

extension FunctionParameterSyntax {
    /// The label of the argument for the parameter; nil when it takes none.
    var callLabel: String? { firstName.text == "_" ? nil : firstName.text }
}
