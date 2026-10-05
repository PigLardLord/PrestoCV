import SwiftSyntax

/// Which expressions a data initialiser may store or pass besides its parameters, and what a parameter is.
///
/// A **literal or constant** is one of:
/// - an integer, floating-point, boolean or string literal (a string without interpolation) and `nil`, a sign allowed
///   on a number: `0`, `-1`, `1.5`, `true`, `"x"`, `nil`;
/// - an array or a dictionary literal whose elements are themselves literals or constants: `[]`, `[:]`, `[0, 1]`;
/// - a member that is not called: an enum case without payload or a static constant, written `.name`, `Type.name`,
///   `Self.name` or `Module.Type.name`, where each type starts with a capital. A name the file declares as a
///   `static var` or `class var` is refused, and so is one of `ambientMembers`. The checker resolves no name, so a
///   static member of a type declared in another file is taken on trust;
/// - a name the same file declares with `let` at file level, unless a parameter has that name.
///
/// Anything else is behaviour: a call, an operator, a conditional, an interpolation, a parameter in any other shape.
struct ConstantValue {
    let constants: FileConstants
    let parameters: Set<String>

    /// Members that read the clock, the locale or a process-wide object: never constants, whatever their type.
    private static let ambientMembers: Set<String> = ["now", "shared", "default", "current", "autoupdatingCurrent", "main", "standard"]

    /// The name of the parameter that `expr` passes unchanged, if it is one.
    func parameter(_ expr: ExprSyntax) -> String? {
        guard let name = expr.as(DeclReferenceExprSyntax.self)?.baseName.text, parameters.contains(name) else { return nil }
        return name
    }

    func accepts(_ expr: ExprSyntax) -> Bool {
        switch expr.kind {
        case .integerLiteralExpr, .floatLiteralExpr, .booleanLiteralExpr, .nilLiteralExpr: true
        case .stringLiteralExpr: expr.cast(StringLiteralExprSyntax.self).segments.allSatisfy { $0.is(StringSegmentSyntax.self) }
        case .arrayExpr: expr.cast(ArrayExprSyntax.self).elements.allSatisfy { accepts($0.expression) }
        case .dictionaryExpr: acceptsEntries(of: expr.cast(DictionaryExprSyntax.self))
        case .prefixOperatorExpr: acceptsSigned(expr.cast(PrefixOperatorExprSyntax.self))
        case .declReferenceExpr: acceptsFileLet(expr.cast(DeclReferenceExprSyntax.self))
        case .memberAccessExpr: acceptsMember(expr.cast(MemberAccessExprSyntax.self))
        default: false
        }
    }

    private func acceptsEntries(of dictionary: DictionaryExprSyntax) -> Bool {
        guard case .elements(let entries) = dictionary.content else { return true }
        return entries.allSatisfy { accepts($0.key) && accepts($0.value) }
    }

    private func acceptsSigned(_ expr: PrefixOperatorExprSyntax) -> Bool {
        ["-", "+"].contains(expr.operator.text) && (expr.expression.is(IntegerLiteralExprSyntax.self) || expr.expression.is(FloatLiteralExprSyntax.self))
    }

    private func acceptsFileLet(_ reference: DeclReferenceExprSyntax) -> Bool {
        let name = reference.baseName.text
        return reference.argumentNames == nil && constants.lets.contains(name) && !parameters.contains(name)
    }

    private func acceptsMember(_ member: MemberAccessExprSyntax) -> Bool {
        guard member.declName.argumentNames == nil, isConstantName(member.declName.baseName.text) else { return false }
        return member.base.map(Self.isType) ?? true
    }

    /// A member that is not an initialiser, ambient state or a `static var` of the file.
    private func isConstantName(_ name: String) -> Bool {
        name != "init" && !Self.ambientMembers.contains(name) && !constants.mutableStatics.contains(name)
    }

    /// A type written by name: capitalised identifiers, qualified by module or enclosing types.
    private static func isType(_ expr: ExprSyntax) -> Bool {
        if let reference = expr.as(DeclReferenceExprSyntax.self) { return reference.baseName.text.first?.isUppercase == true }
        guard let member = expr.as(MemberAccessExprSyntax.self), let base = member.base else { return false }
        return member.declName.baseName.text.first?.isUppercase == true && isType(base)
    }
}
