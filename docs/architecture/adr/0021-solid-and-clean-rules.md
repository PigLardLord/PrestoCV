# 0021. The rules are SOLID and Clean, named by principle and measured where they can be

- **Status:** Accepted
- **Date:** 2026-10-05
- **Related:** [ADR 0001](0001-architecture-before-bug-fixing.md), [ADR 0006](0006-enforce-architecture-mechanically.md), [ADR 0012](0012-legacy-targets-during-migration.md), [rules.md](../rules.md), issue #228

## Context

- The architecture rules were fourteen numbered rules, R1 to R14. They covered structure: dependencies, layers, errors, untrusted input, concurrency, persistence, localisation.
- **A number says nothing to its reader.** Code, docs and the checker cited "R8" or "(R2)", and the meaning lived only in the headings of `rules.md`.
- **Nothing governed the code itself.** No rule asked for small functions, clear names, comments that explain why, or code that is not duplicated, and no review was briefed to judge it. Reading the open pull requests, the owner found a lot of code that is hard to read and maintain, although every review had passed it.
- The owner decided on 2026-10-05:
  - the rules are **SOLID** and **Clean** (Clean Architecture and Clean Code);
  - the rules that are neither but specific to this project stay, **named by topic**;
  - every rule is cited by **its principle's name**, never by a number;
  - **strict thresholds**: functions of at most 20 lines, at most 3 parameters, nesting of at most 2 levels, cyclomatic complexity of at most 5; types of at most 200 lines; files of at most 300 lines;
  - **comments** explain why, never what; public API keeps full doc comments;
  - **no baseline**: the open pull requests and `main` are brought to the rules before anything else merges.

## Decision

**The owner's decisions** are the bullets above. The rest of this section is this ADR's own, made to carry them out.

- **(a) `rules.md` has four groups.** Each rule has a name, what it requires, why, and what enforces it:
  - **SOLID:** `SRP`, `OCP`, `LSP`, `ISP`, `DIP`.
  - **Clean Architecture:** `DependencyRule`, `PureCore`, `HumbleViews`, `RichDomain`.
  - **Clean Code:** `CleanNames`, `CleanFunctions`, `CleanTypes`, `CleanComments`, `CleanErrors`, `CleanTests`, `NoDuplication`, `NoDeadCode`.
  - **This project's rules, named by topic:** `ValidatingBoundary`, `StrictConcurrency`, `PlatformAdapters`, `PersistedSchema`, `LocalisationAtEdges`.
- **(b) Where the former rules went.** Each former rule keeps its content under the name of the principle it serves:

  | Former | Now |
  |---|---|
  | R1 | `DependencyRule` |
  | R2 | `PureCore` |
  | R3 | `DIP` (ports belong to the consumer) and `ISP` (ports are small; the cap of five requirements is new) |
  | R4 | `DIP` (one composition root) |
  | R5 | `HumbleViews` |
  | R6 | `RichDomain`; "a rule exists once" is `NoDuplication` |
  | R7 | `CleanErrors` |
  | R8 | `ValidatingBoundary` |
  | R9 | `StrictConcurrency` |
  | R10 | `CleanTests`; "every adapter passes its port's contract" is `LSP` |
  | R11 | `PlatformAdapters` |
  | R12 | `PersistedSchema` |
  | R13 | `LocalisationAtEdges` |
  | R14 | `NoDeadCode` |

  The merged ADRs 0001 to 0012 keep their numbers, because a merged ADR does not change; `rules.md` carries this table for their readers.
- **(c) How the thresholds are measured.**
  - **What counts:** a line counts when it holds code. Blank lines, comment lines and lines that hold only a brace do not count. A token that spans lines makes each of them code, so every line of a multi-line string counts, blank ones included. A line that holds `#if`, `#else` or `#endif` counts, and every `#if` branch is counted, active on the checking host or not.
  - **Function length:** the lines of a function's, initialiser's, accessor's or closure's body. A closure or a nested function is measured on its own, and not counted again in the function that holds it; the line that holds its header or its call still counts in the holder.
  - **Parameters:** the parameters of a function or an initialiser. A **data initialiser** is exempt: it describes a data structure, not a behaviour (Clean Code's distinction between data structures and objects), and its validation goes in the type's own small functions. An initialiser is a data initialiser when all of these hold:
    - **it only stores or only delegates.** Either each statement assigns a parameter to the stored property of the same name, each parameter once, or gives another stored property a literal or a constant. Or its one statement is `self.init(...)`, passing its parameters unchanged beside literals or constants, and every initialiser of the same type in the file that the call's argument labels can reach is a data initialiser in its turn. A delegation that comes back to itself is not exempt;
    - **it has no variadic parameter.** A variadic parameter fits any number of arguments, so a call that a variadic overload can take is not exempt either;
    - **its default values are literals or constants,** and so are those of the initialiser it delegates to;
    - **the stored properties of its type start quietly, whether the initialiser assigns them or not:** with no initial value, or with a literal or a constant. Swift runs an initial value at the start of every designated initialiser, before the body, so the assignment that replaces it comes too late. A `lazy` property is the exception: it runs its initial value when first used, not in the initialiser;
    - **it does not belong to a class with an inheritance clause,** because a superclass's initialiser runs without being written, and syntax cannot tell a superclass from a protocol.

    A property is **stored** when the type, or an extension of it in the same file, declares it without accessors or with only `willSet` or `didSet`, which a type's own initialiser does not run, and without any attribute: a property wrapper runs code to start and on every assignment, and syntax cannot tell a wrapper from another attribute. A computed property runs code, and a `static` one belongs to no instance.

    **Resolution stops at the file.** A type is found by its full path, such as `Outer.Inner`, and an extension names the path it extends; a path that no single declaration answers finds nothing. An initialiser whose properties or callee cannot be found in its file is not exempt. An overload that another file declares is not seen: a known limit, for which review is the backstop. The search is bounded by counted work, and a file that spends the budget gets a finding.
  - **Nesting:** the depth of `if`, `guard`, `switch`, `for`, `while`, `repeat`, `do` and closures inside a function body. A `guard` whose `else` holds one `return`, `throw`, `break` or `continue` and nothing else counts as no level. A `catch` clause sits at the level of its `do`, and `else if` continues the chain of its `if`. A closure is a level of the function that holds it, while a nested function starts again at its own body.
  - **Cyclomatic complexity:** one, plus one for each `if`, `guard`, `while`, `for`, `repeat`, `catch`, `&&`, `||`, `??` and ternary, and one for each condition after the first in a condition list (`if a, b`, `guard let x, y`), which is an `&&` written with a comma. The decisions inside a closure count in the function that holds it, and a nested function has its own count. The condition of a compile-time `#if` is no decision. A `switch` counts **once**, however many cases it has: a switch that maps the cases of a closed enumeration is the shape Clean Code asks for, buried once behind a function. A mapping `switch` that is longer than the function length is split by group of cases, or becomes a data table where the compiler's exhaustiveness check is not needed.
  - **Types and files:** a type's declaration and each extension are measured separately, on the lines of their member list, so the line of the declaration itself does not count. A nested type is measured on its own and not counted again in its type. The file bounds them together.
  - **Where:** the thresholds apply to every production target by kind, listed in `rules.json` or not, so that a new target cannot forget them. They are the production targets the checker already holds to the rules: domain, application, integration, presentation, workflow ports, adapters and the composition root. Tests, test support and tools are held to Clean Code by review, with no thresholds. Legacy targets stay exempt until they are deleted ([ADR 0012](0012-legacy-targets-during-migration.md)).
  - **Interface segregation:** a protocol a production target declares has at most five requirements.
- **(d) What enforces each rule.**
  - **The checker** names its findings by rule. It gains the detectors `functionLength`, `parameterCount`, `nestingDepth`, `cyclomaticComplexity`, `typeLength`, `fileLength` and `protocolSize`, each with a self-test, and `ruleNumberCitation`, which refuses a former rule number cited in a comment of a production source and in a document.
  - **Review** holds what no tool can see: names, a single responsibility, open/closed, comments that restate code, and duplication. Every review, dimension or final gate, goes through the checklist at the end of `rules.md`.
- **(e) No baseline.** A finding of the new detectors is not baselined: the checker refuses a baseline entry of any of them, and `--write-baseline` leaves their findings out. The pull request that adds them brings `main`'s production code to the rules, and every open pull request is brought to them before it merges. An exception stays what [ADR 0006](0006-enforce-architecture-mechanically.md) made it: an entry in `rules.json` that cites an ADR.
- **(f) Citations.** Docs, code comments and commit messages cite a rule by its name, such as `ValidatingBoundary` or `SRP`. The checker's `ruleNumberCitation` refuses a former number in a comment of a production source and in `docs/**/*.md`, `AGENTS.md` and every `README.md`, except in the merged ADRs 0001 to 0012, in this ADR and in the table of former numbers of `rules.md`.

## Consequences

- **What becomes possible:**
  - a citation says what it means where it is read;
  - the size and shape of the code are checked on every commit, as its dependencies already are;
  - a reviewer has one checklist for what the tools cannot see.
- **Costs:**
  - the code on `main` and in every open pull request is restructured before more is merged: parsers, readers, gates and the loop are well over the thresholds today;
  - a strict function length makes more, smaller functions and more names to choose; `CleanNames` is what keeps that readable;
  - the checker grows eight detectors, and its own code is held to Clean Code by review;
  - the former numbers survive in the merged ADRs, read through the table in `rules.md`.
- **Validation:**
  - every new detector has a self-test that fails on a planted violation and passes on the fixed version;
  - the checker reports no finding on `main` once the pull request of #228 lands, and on each open pull request before it merges.

## Alternatives considered

- **Keep the numbers and add names beside them.** Rejected by the owner: names only.
- **Moderate or loose thresholds** (functions of 40 or 60 lines). Rejected by the owner: strict.
- **Baseline what already exists.** Rejected by the owner: everything is brought to the rules now.
- **No comments at all.** Rejected by the owner: public API keeps full doc comments.
- **Count a `switch` once per case** in the complexity. Rejected: it would penalise the exhaustive mapping of an enumeration, which is what the code should do, and push it into dictionaries the compiler cannot check.
