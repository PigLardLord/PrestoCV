# Architecture checker

It enforces the rules in `docs/architecture/rules.md` (ADR 0006, ADR 0021). It parses every Swift file with SwiftSyntax and checks three things:
- each file is mapped to a target, and uses only the imports and constructs that target allows;
- `rules.json` and `docs/architecture/modules.md` agree;
- the dependencies declared in the package manifests are allowed.

## Running it

From the repository root:

```bash
Tools/ArchitectureCheck/check.sh                        # the whole repository, with the project's rules
Tools/ArchitectureCheck/check.sh --against base.json    # also fail if the baseline grew compared with base.json
Tools/ArchitectureCheck/check.sh --search-steps 1000    # lower the budget of the search for data initialisers, for a test
swift build -c release --package-path Tools/ArchitectureCheck && Tools/ArchitectureCheck/selftest.sh
```

The first build takes a few minutes, because it compiles SwiftSyntax. `selftest.sh` runs the cases of the core checks and then those of the size, shape and comment detectors, kept in `selftest-measures.sh`.

## Rules and detectors

A rule is cited by its name from `rules.md` (`DIP`, `PureCore`, `CleanErrors`, …), never by a number. In `rules.json`:

- **`rules`** maps each rule to the detectors that enforce it. A detector can serve two rules: `localization` is `PureCore` and `LocalisationAtEdges`, `printing` is `PureCore` and `NoDeadCode`, and a finding is reported under each.
- **`productionRules`** lists the rules whose detectors run on every production target, by kind, listed or not: `ISP`, `CleanFunctions`, `CleanTypes` and `CleanComments`. A new target cannot forget them. A rule name that `rules` does not define is an error here too.
- **a target's `rules`** names the rules whose **detectors** run on that target, besides the production rules. A rule held by the compiler, by tests or by review applies to every production target whatever this list says. An adapter is not listed under `PureCore` or `PlatformAdapters`: it may read the clock, and it may hold platform code. A rule name that `rules` does not define is an error, and so is a detector name that the checker does not implement, so a typo cannot disable a detector.
- **a target's `kind`** is one of `production` (the default when it is absent), `test`, `tool`, `manifest`, `legacy` and `excluded`. Any other value, a misspelt `production` included, fails the run with the kinds that exist, because the size, shape and comment detectors run on production targets only.
- **`DependencyRule`** also covers the import allow-list of every target (detector `import`), and **`HumbleViews`** the `requiredImportAccess` constraint (detector `importAccess`), a map from a module to `internal`; any other word, a misspelt `internal` included, fails the run like a misspelt kind. Neither needs to be listed.
- **`swift5Mode` and `unsafeFlags`** (`StrictConcurrency`) read package manifests and run on manifest targets only; the other detectors read sources and never run on a manifest.

A finding reads `<file>:<line>: <rule>: <detector>: <detail>`, and its baseline entry starts `<file>|<rule>|<detector>|`.

## Size, shape and comment detectors

They enforce `CleanFunctions`, `CleanTypes`, `ISP` and `CleanComments` on production targets, as [ADR 0021](../../docs/architecture/adr/0021-solid-and-clean-rules.md) (c) measures them. They run on every production target by kind (`productionRules` in `rules.json`), whether or not the target lists them. Tests, test support, tools, manifests and legacy targets are not measured. They have no baseline: a finding is fixed, and the checker refuses a baseline entry of theirs.

| Detector | Rule | Finding when |
|---|---|---|
| `functionLength` | `CleanFunctions` | a body has more than 20 lines of code |
| `parameterCount` | `CleanFunctions` | a function or initialiser has more than 3 parameters |
| `nestingDepth` | `CleanFunctions` | a function nests more than 2 levels |
| `cyclomaticComplexity` | `CleanFunctions` | a function has a complexity above 5 |
| `typeLength` | `CleanTypes` | a type declaration or an extension has more than 200 lines of code |
| `fileLength` | `CleanTypes` | a file has more than 300 lines of code |
| `protocolSize` | `ISP` | a protocol declares more than 5 requirements |
| `ruleNumberCitation` | `CleanComments` | a comment or a document cites a rule by the number it had before ADR 0021 |

**What counts.** A line is code when a token other than a brace touches it, so blank, comment-only and brace-only lines do not count. A token that spans lines, such as a line of a multi-line string, makes each of them code. A line that holds a compiler directive (`#if`, `#else`, `#endif`) is code, and every `#if` branch is counted, active or not.

**Bodies.** A body is the statements of a function, initialiser, deinitialiser, accessor, shorthand getter (a computed property or subscript) or closure.
- A closure and a nested function are each measured on their own, and their lines are not counted again in the body that holds them.
- The header of a nested function or closure, the line that holds its name or call, counts in the body that holds it.

**Nesting.** `if`, `guard`, `switch`, `for`, `while`, `repeat`, `do` and a closure are a level each. `else if` continues the chain of its `if`, a `case` and a `catch` are no level, and neither is `defer`. A `guard` whose `else` is a single `return`, `throw`, `break` or `continue` is no level. A closure inside a function is a level of it. A closure that no function holds (a property initialiser) and a nested function are measured as functions of their own.

**Complexity.** One, plus one for each `if` (so each `else if`), `guard`, `while`, `for`, `repeat`, `catch`, `&&`, `||`, `??` and ternary, and one for each `switch`, whatever its cases. A condition list adds one for each condition after the first (`if a, b`, `guard let x, case .y = z`), like an `&&`; the elements of a list are optional bindings, patterns and boolean conditions. The condition of a compile-time `#if` is settled when the code is compiled, so its `&&` and `||` are no decisions; the code in its branches counts as usual. The decisions inside a closure count in the function that holds it; a nested function has its own count.

**Parameters.** The parameters of a function or initialiser, protocol requirements included, not those of a closure. A **data initialiser** is exempt, as ADR 0021 (c) defines it. Its body is one of two shapes, and nothing else:
- **Assignments.** Each statement is `self.x = x`, naming a property after its parameter, each parameter once, or gives another property a literal or a constant: `self.revision = 0` or `revision = 0`. A property is assigned once.
  - **Each is a stored instance property** that the file declares for the type, in its body or in a `#if` branch of it: a `let` or `var` with no accessors, or with only `willSet` or `didSet`, because a type's own observers do not run in its initialisers, and with no attribute at all. A property wrapper runs code on every assignment and a macro can rewrite the property, and syntax cannot tell either from `@MainActor` or any other attribute, so any attribute on the property makes it not stored; an attribute on the type or on the initialiser does not. A computed property runs code, a `static` or `class` one is no instance's, and a property inherited from another type, or declared by a type that another file declares, cannot be found: the initialiser is not exempt.
  - **A type is found by its full path.** `Outer.Inner` for a type nested in `Outer`, and an extension names the path it extends (`extension Outer.Inner`), whichever of the two comes first. The path must be answered by exactly one declaration in the file: none, or two, as when the branches of a `#if` both declare it, finds nothing and the initialiser is not exempt. A type declared inside a function is found by itself. Two types of one name in different scopes are two types, and a property is stored only if no declaration of that path makes it computed.
- **Delegation.** The only statement is `self.init(...)`, with no trailing closure, and each argument is a parameter passed unchanged, each parameter once, or a literal or a constant.
  - **The callee is found in the file.** It is an initialiser of the same type, in its declaration or in an extension of it in the file, whose parameter labels the arguments fit in order, a parameter with a default value being left out when the call has no argument for it. A variadic parameter fits any number of arguments, none included, and an initialiser with one is never a data initialiser, so a call that a variadic overload can take is not exempt, whatever else it can mean. A call that fits no initialiser of the file is not exempt either: the initialiser it reaches may compute.
  - **The search is bounded by counted work.** An initialiser is looked at only when it takes more than three parameters, each one is examined once and its answer kept, a delegation that comes back to one being examined is a cycle, and the labels of a call are matched against the parameters in one table. The steps are counted, and a file whose search spends a million of them (`--search-steps n` changes the budget; it takes a whole number above zero, and anything else fails the run) reports a finding of `parameterCount` that says so, and exempts nothing that the search had not reached.
  - **Resolution stops at the file.** An overload, an extension or a property that another file of the module declares is not seen, so a delegation can mean an initialiser that the checker never looked at; the extension that declares it is not resolved either, and its initialisers are not exempt. This is a known limit, and review is the backstop for it. The synthesised memberwise initialiser is not declared, so it is not found.
  - **The callee is a data initialiser in its turn,** by the same two shapes, and so is every one that the call can fit. The search keeps the initialisers it is following, so a delegation that comes back to one of them, directly or through others, ends and is not exempt.

**Classes.** An initialiser of a class that has an inheritance clause is never a data initialiser, whatever its body: a superclass's initialiser runs without being written, and syntax cannot tell a superclass from a protocol such as `Sendable`. That holds for the convenience initialisers and for those declared in an extension of the class, and for a nested class. A struct, an enum, an actor and a class with no inheritance clause have nothing to run, and a conformance declared in an extension does not count.

**Initial values.** No instance property of the type runs anything when an initialiser starts it, whether the initialiser assigns the property or not. A property that holds a value has no attribute, and no initial value other than a literal or a constant, by the same test as a default: `var stamp = Date()` or `let counter = sideEffect()` in a type makes the initialiser that only stores its parameters no data initialiser. Swift runs the initial value of every stored property at the start of every designated initialiser, before the body, so a property that the body assigns still ran its initial value first; the self-tests compile and run a program that shows it. An attribute counts as well, assigned or not, because a property wrapper runs code to start the property. A `lazy` property runs its initial value the first time it is used and not in the initialiser, and a `static` one when first used, so neither counts. A computed property has nothing to start. A tuple pattern with an initial value is judged like any other value, so a tuple, which is no literal here, is refused. These are the properties of the one declaration of the type, found by its path.

**Default values.** The default value of each parameter is part of the initialiser, because it runs whenever a call leaves the argument out, so it has to be a literal or a constant too, by the test below, whether the initialiser assigns or delegates. A delegation also reaches the defaults of the initialiser it calls, and that initialiser is a data initialiser only if its own are constants: `init(at: Date = Date(), …)` that only stores is not exempt.

A **literal or constant** is one of the following, judged by its spelling: the checker resolves no name of a value.
- An integer, floating-point, boolean or string literal, a string without interpolation, or `nil`, with a `-` or `+` on a number: `0`, `-1`, `1.5`, `true`, `"x"`, `nil`.
- An array or a dictionary literal whose elements are themselves literals or constants: `[]`, `[:]`, `[0, 1]`, `["a": 1]`.
- A member that is not called, such as an enum case without payload or a static constant: `.name`, `Type.name`, `Self.name`, `Module.Type.name`. Every type in the path starts with a capital letter. A name that the same file declares as a `static var` or a `class var` is refused, and so is a member named `now`, `shared`, `default`, `current`, `autoupdatingCurrent`, `main` or `standard`, whatever its type: they read the clock, the locale or a process-wide object. A member of a type declared in another file is otherwise taken on trust, so a computed `static var` there passes.
- A name that the same file declares with `let` at file level, in any `#if` branch, unless a parameter has that name. A `let` inside a type or a function is not one; reach a type's constant as `Type.name`.

Everything else is behaviour and makes the initialiser an ordinary one: a call, an operator, a conditional, an interpolation, a parameter in any other shape (used twice, transformed, inside an array), a name the file does not declare, a property reached through a value.

**Types.** Struct, class, enum, actor, protocol and extension, counted from their member list. A nested type is measured on its own and not counted again in its type; its header line counts in its type.

**Protocol requirements.** Functions, variables (one per binding), subscripts, initialisers and associated types, in every `#if` branch. Inherited requirements and `typealias` are not counted.

**Citations.** The letter R followed by a number from 1 to 14 and an optional `m`, in line, block and documentation comments of a source. A string that holds one is not a comment. The same detector reads `docs/**/*.md`, `AGENTS.md` and every `README.md`, except the merged ADRs 0001 to 0012, ADR 0021, the section "Former numbers" of `docs/architecture/rules.md` and anything under `Prototypes/`.

## Pre-commit hook

`pre-commit.sh` checks a checkout of the index, which is what is being committed, so a violation that is only in the working tree does not block the commit. It runs only when the commit touches Swift files, manifests, the checker or `docs/architecture/`. A rename counts as a deletion plus an addition. The staged checker is the one that runs, and its build shares `Tools/ArchitectureCheck/.build`, so SwiftSyntax is not rebuilt. A path given to `--modules` or `--adr-dir` that cannot be read is an error, never a silent pass. To install it as a drop-in of the repository's git hooks:

```bash
mkdir -p .githooks/pre-commit.d
printf '#!/usr/bin/env bash\nexec "$(git rev-parse --show-toplevel)/Tools/ArchitectureCheck/pre-commit.sh"\n' > .githooks/pre-commit.d/architecture-check
chmod +x .githooks/pre-commit.d/architecture-check
```

## Changing the rules

- **A new target:** add it to `rules.json` and to `docs/architecture/modules.md` in the same pull request, and remove it from `notYetImplemented`. A production target is measured by the size, shape and comment detectors from its first commit; it needs no list for that.
- **A permanent exception:** an entry in `exceptions` that cites an ADR.
- **A temporary one:** a baseline entry. The baseline may only shrink. The size, shape and comment detectors are never baselined: the checker refuses an entry of theirs, whatever its fingerprint, and `--write-baseline` leaves their findings out and says so.
- **Legacy targets** are exempt until they are deleted (ADR 0012).
- **`Prototypes/` is excluded.**
- **Module qualifiers do not hide a name:** `Swift.fatalError` and `Foundation.Date()` are checked like `fatalError` and `Date()`.
- **The language mode is checked twice.** The syntax catches any spelling below 6, in every `#if` branch, including a tools version below 6. `--packages` also checks the effective mode that SwiftPM computes.
- **`--packages` depends on the host.** `swift package dump-package` evaluates each manifest for the host it runs on. Run it on Linux and on macOS: Apple-only manifest branches are visible only on macOS.
