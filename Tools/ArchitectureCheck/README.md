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
swift build -c release --package-path Tools/ArchitectureCheck && Tools/ArchitectureCheck/selftest.sh
```

The first build takes a few minutes, because it compiles SwiftSyntax. `selftest.sh` runs the cases of the core checks and then those of the size, shape and comment detectors, kept in `selftest-measures.sh`.

## Rules and detectors

A rule is cited by its name from `rules.md` (`DIP`, `PureCore`, `CleanErrors`, …), never by a number. In `rules.json`:

- **`rules`** maps each rule to the detectors that enforce it. A detector can serve two rules: `localization` is `PureCore` and `LocalisationAtEdges`, `printing` is `PureCore` and `NoDeadCode`, and a finding is reported under each.
- **a target's `rules`** names the rules whose **detectors** run on that target. A rule held by the compiler, by tests or by review applies to every production target whatever this list says. An adapter is not listed under `PureCore` or `PlatformAdapters`: it may read the clock, and it may hold platform code. A rule name that `rules` does not define is an error, so a typo cannot disable a detector.
- **`DependencyRule`** also covers the import allow-list of every target (detector `import`), and **`HumbleViews`** the `requiredImportAccess` constraint (detector `importAccess`). Neither needs to be listed.
- **`swift5Mode` and `unsafeFlags`** (`StrictConcurrency`) read package manifests and run on manifest targets only; the other detectors read sources and never run on a manifest.

A finding reads `<file>:<line>: <rule>: <detector>: <detail>`, and its baseline entry starts `<file>|<rule>|<detector>|`.

## Size, shape and comment detectors

They enforce `CleanFunctions`, `CleanTypes`, `ISP` and `CleanComments` on production targets, as [ADR 0021](../../docs/architecture/adr/0021-solid-and-clean-rules.md) (c) measures them. A target that lists none of these rules is not measured: tests, test support, tools, manifests and legacy targets list none. They have no baseline; a finding is fixed.

| Detector | Rule | Finding when |
|---|---|---|
| `functionLength` | `CleanFunctions` | a body has more than 20 lines of code |
| `parameterCount` | `CleanFunctions` | a function or initialiser has more than 3 parameters |
| `nestingDepth` | `CleanFunctions` | a function nests more than 2 levels |
| `cyclomaticComplexity` | `CleanFunctions` | a function has a complexity above 5 |
| `typeLength` | `CleanTypes` | a type declaration or an extension has more than 200 lines of code |
| `fileLength` | `CleanTypes` | a file has more than 300 lines of code |
| `protocolSize` | `ISP` | a protocol declares more than 5 requirements |
| `ruleNumberCitation` | `CleanComments` | a comment cites a rule by the number it had before ADR 0021 |

**What counts.** A line is code when a token other than a brace touches it, so blank, comment-only and brace-only lines do not count. A token that spans lines, such as a line of a multi-line string, makes each of them code. A line that holds a compiler directive (`#if`, `#else`, `#endif`) is code, and every `#if` branch is counted, active or not.

**Bodies.** A body is the statements of a function, initialiser, deinitialiser, accessor, shorthand getter (a computed property or subscript) or closure.
- A closure is measured on its own and its lines are not counted again in the body that holds it. A nested function is measured on its own and also counts in the body that holds it, like a nested type in its type.
- The header of a nested function or closure, the line that holds its name or call, counts in the body that holds it.

**Nesting.** `if`, `guard`, `switch`, `for`, `while`, `repeat`, `do` and a closure are a level each. `else if` continues the chain of its `if`, a `case` and a `catch` are no level, and neither is `defer`. A `guard` whose `else` is a single `return`, `throw`, `break` or `continue` is no level. A closure inside a function is a level of it. A closure that no function holds (a property initialiser) and a nested function are measured as functions of their own.

**Complexity.** One, plus one for each `if` (so each `else if`), `guard`, `while`, `for`, `repeat`, `catch`, `&&`, `||`, `??` and ternary, and one for each `switch`, whatever its cases. The decisions inside a closure count in the function that holds it; a nested function has its own count.

**Parameters.** The parameters of a function or initialiser, protocol requirements included, not those of a closure. A data initialiser is exempt: every statement is `self.x = x`, naming a property after its parameter, each parameter assigned once; or the only statement is `self.init(...)` and every argument is one of the parameters, each passed once.

**Types.** Struct, class, enum, actor, protocol and extension, counted from their member list. A nested type counts in its type and in itself.

**Protocol requirements.** Functions, variables (one per binding), subscripts, initialisers and associated types, in every `#if` branch. Inherited requirements and `typealias` are not counted.

**Citations.** The letter R followed by a number from 1 to 14 and an optional `m`, in line, block and documentation comments. A string that holds one is not a comment.

## Pre-commit hook

`pre-commit.sh` checks a checkout of the index, which is what is being committed, so a violation that is only in the working tree does not block the commit. It runs only when the commit touches Swift files, manifests, the checker or `docs/architecture/`. A rename counts as a deletion plus an addition. The staged checker is the one that runs, and its build shares `Tools/ArchitectureCheck/.build`, so SwiftSyntax is not rebuilt. A path given to `--modules` or `--adr-dir` that cannot be read is an error, never a silent pass. To install it as a drop-in of the repository's git hooks:

```bash
mkdir -p .githooks/pre-commit.d
printf '#!/usr/bin/env bash\nexec "$(git rev-parse --show-toplevel)/Tools/ArchitectureCheck/pre-commit.sh"\n' > .githooks/pre-commit.d/architecture-check
chmod +x .githooks/pre-commit.d/architecture-check
```

## Changing the rules

- **A new target:** add it to `rules.json` and to `docs/architecture/modules.md` in the same pull request, and remove it from `notYetImplemented`.
- **A permanent exception:** an entry in `exceptions` that cites an ADR.
- **A temporary one:** a baseline entry. The baseline may only shrink.
- **Legacy targets** are exempt until they are deleted (ADR 0012).
- **`Prototypes/` is excluded.**
- **Module qualifiers do not hide a name:** `Swift.fatalError` and `Foundation.Date()` are checked like `fatalError` and `Date()`.
- **The language mode is checked twice.** The syntax catches any spelling below 6, in every `#if` branch, including a tools version below 6. `--packages` also checks the effective mode that SwiftPM computes.
- **`--packages` depends on the host.** `swift package dump-package` evaluates each manifest for the host it runs on. Run it on Linux and on macOS: Apple-only manifest branches are visible only on macOS.
