# 0006. Enforce the architecture with target boundaries, a syntax-based checker and a shrinking baseline

- **Status:** Accepted
- **Date:** 2026-09-28
- **Amended by:** [ADR 0024](0024-run-apple-ci-and-releases-on-xcode-cloud.md) and [ADR 0029](0029-check-pull-requests-on-the-mac-mini.md): where CI runs (Decision, "Where it runs")
- **Related:** [ADR 0001](0001-architecture-before-bug-fixing.md), [ADR 0012](0012-legacy-targets-during-migration.md), [rules](../rules.md), [modules](../modules.md), issue #28

## Context

The current structure followed conventions that nothing checked, and it eroded. The compiler alone cannot hold the new rules:

- **SwiftPM lets a target import its dependencies' dependencies.** Verified with Swift 6.3.3 on Linux, within a package and across packages, even with `--explicit-target-dependency-import-check error`.
- **Many rules concern constructs, not modules.** Examples: `Date.now` in the domain, `@unchecked Sendable`, `try?`, `#if os` outside adapters, a manifest in Swift 5 mode.
- **A text-based checker is not good enough.** A first prototype lexed Swift with regexes. Reviews found:
  - regex literals (`/"/`, `#/x/*/#`) that hid the rest of a file;
  - more than twenty legal spellings it missed;
  - a baseline keyed by file and pattern, which allowed unlimited repeats.

The git guards read their policy from `.agents/harness/guards.json`, which counts `docs/` as non-code. Binding documents under `docs/architecture/` can therefore be committed straight to `main`.

## Decision

1. **Compiler.**
   - Every package uses Swift tools 6.x and the Swift 6 language mode. The Xcode app target uses `SWIFT_VERSION = 6` with complete concurrency checking.
   - Target dependencies follow [modules.md](../modules.md).
   - Presentation imports the domain with `internal import`.
2. **`Tools/ArchitectureCheck`.** A SwiftPM tool built on **SwiftSyntax** (swift-syntax 603.x), which runs on macOS and Linux.
   - **Inventory.** Every `.swift` file belongs to exactly one target, by path. Unmapped files, paths claimed twice and symbolic links in the source tree are errors.
   - **Imports.** It reads every `ImportDeclSyntax`, whatever its attributes or access modifier, and checks it against the target's allow-list.
   - **Named detectors** (`rules.json` maps each rule to a list of them):
     - `exportedImport`
     - `wallClock`, `randomIdentity`, `ambientEnvironment`, `localization`, `printing`
     - `singleton`, `infrastructureConstruction`
     - `swallowedError`, `escapeHatch`, `platformCondition`, `testDouble`
     - for manifests: `swift5Mode`, `unsafeFlags`
     - per target, `requiredImportAccess`: the listed modules must be imported `internal` or narrower. It keeps R5's compiler guarantee from being undone by changing `internal import` back to `import` or `public import`.

     Every `#if` branch is visited, including branches inactive on the host.
   - **Target kinds:** `production` (the default), `test`, `tool`, `manifest`, `legacy` ([ADR 0012](0012-legacy-targets-during-migration.md)) and `excluded` (the validation prototype).
   - **Exceptions.** An exception is permanent and names a path, a detector and an ADR. The checker fails if the ADR does not exist. Baseline entries are temporary.
   - **`--modules modules.md`.** Rules and documentation must agree in both directions. Every documented target has a rule or is listed in `notYetImplemented`. No rule allows an import the documentation does not.
   - **`--packages`.** Every dependency declared in a `Package.swift` (read with `swift package dump-package`) must be an allowed import.
     - `dump-package` evaluates the manifest for the host it runs on, so a dependency declared in an Apple-only branch (`#if !os(Linux)`, [ADR 0012](0012-legacy-targets-during-migration.md)) is only visible on macOS.
     - The check therefore runs on both hosts (see **Where it runs**).
     - A regression fixture declares a forbidden dependency only in the Apple branch, and must fail in the macOS job (review round 4).
3. **Baseline.**
   - Each entry is **one occurrence**, keyed as `file | rule | detector | fingerprint#ordinal`.
     - The fingerprint hashes the construct's tokens without trivia. Moving, re-spacing or commenting a line does not change it; a different construct does.
     - The ordinal distinguishes identical occurrences in one file.
   - The **tree check** fails on any occurrence missing from the baseline, and on any baseline entry that no longer occurs.
   - The **monotonicity check** (`--against <base baseline>`, CI only) fails if the pull request's baseline contains an entry the merge base's does not.
   - `--write-baseline` refuses to run while there are other problems.
   - The goal is an empty baseline before the first release.
4. **Where it runs.**
   - A `pre-commit.d` hook runs the checker on a checkout of the index (`git checkout-index` into a temporary directory), so it checks what is committed, not the working tree. The hooks therefore need a Swift toolchain.
   - CI runs on GitHub Actions for every pull request, with `fetch-depth: 0` for `--against`:
     - **Linux** (Swift 6.3 container): the checker with `--modules` and `--packages`, then build and test of every Linux ✓ target.
     - **macOS** (macOS 26 runner, Xcode 26): the checker with `--modules` and `--packages`, which sees the Apple-only manifest branches; package tests; `xcodebuild test` of the package schemes on the iOS simulator (iPhone 17 Pro, iOS 26.5) for the native renderer contract; the app on iOS and macOS.
     - **Amended by [ADR 0024](0024-run-apple-ci-and-releases-on-xcode-cloud.md) and [ADR 0029](0029-check-pull-requests-on-the-mac-mini.md):** the Apple checks run on the Mac mini, and since 2026-11-17 the `CI` workflow runs only when started by hand: on a pull request its Linux and Android steps run on a Linux computer and write commit statuses of their own. The text above stays as it was decided.
   - The ticket-loop harness runs the checker as its `lint` step.
5. **Governance** (proposed; this changes the maintainer's guard policy, so the maintainer decides it separately, in #69 and #70; accepting this ADR does not decide it):
   - treat `docs/architecture/` and `Tools/ArchitectureCheck/` as code in `guards.json`;
   - add CODEOWNERS for both.
6. **Review-only rules.** Some things no detector can prove: whether a view contains a business rule, whether a continuation resumes exactly once, whether a port leaks infrastructure types. These are listed as "review" in [rules.md](../rules.md), not claimed as checked.

## Consequences

- Architectural drift fails a build, rather than being found months later.
- The checker is a small tool to maintain: two files plus the swift-syntax dependency. It builds in about 2.5 minutes the first time, then in seconds.
- Every construct a detector does not know passes silently. The self-test lists what is covered, and a newly discovered evasion becomes a new case.

## Alternatives considered

- **Regex or lexer scanning.** Rejected after the first prototype failed review (see Context).
- **SwiftLint custom rules.** They cannot express per-target import allow-lists or inventory. They would also be one more tool to install in the hooks.
- **Target dependencies only.** Rejected: transitive imports leak.

## Validation

The validation prototype in `Prototypes/ADRValidation/`.

**Self-test: 95 cases, all passing.** The groups:
- **Import forms** — 10 cases:
  - `public`, `package` and `internal import`, and `package import struct X.Y`;
  - an import after a block comment, split over two lines, or after `;`;
  - `@preconcurrency`, backtick-quoted names, `@_spi(X)`, imports inside `#if`.
  - Plus `@_exported import`, banned even for allowed modules.
- **Things that are not code** — 8 cases: comments (nested too), strings, multi-line and raw strings.
- **Regex literals hide nothing** — 3 cases: `/"/`, `#/x/*/#`, `#/a//b/#`.
- **Interpolations are code** — 4 cases: plain, raw and nested, and code after a string that contains `//`.
- **R2 variants** — 12 cases, plus `Bundle.module` allowed.
- **R9 escape hatches** — 11 cases: `@unchecked Swift.Sendable`, double spaces, `fatalError ("x")`, force unwrap, `precondition` and others.
- **Other rules:**
  - R7 `try?` and empty `catch`;
  - R4 singleton and infrastructure construction;
  - 5 R11 conditions, including `#if !os(`, `#elseif os(`, `targetEnvironment`, `#available`, `@available`;
  - R14 test doubles, declared and referenced.
- **Import access (R5):** plain, `public`, `package` and `@preconcurrency public` imports are refused where `internal` is required; `internal`, `private` and `fileprivate` are accepted.
- **Manifests:**
  - Swift 5 mode and `unsafeFlags`.
  - The legacy exemption covers only the declaration of a legacy target, in the manifest that owns it. A new target, a package-wide setting, a sibling package with the same target name, and a root manifest over a nested package all fail (review rounds 4–6).
  - A duplicate target name in the rules is refused.
- **Baseline:**
  - a second identical occurrence is new;
  - a fixed occurrence is stale;
  - a replacement is both new and stale;
  - moving, re-spacing or commenting a line does not churn;
  - monotonicity against the base.
- **Exceptions:** backed by an ADR, and missing an ADR.
- **Inventory:** unmapped file, symbolic link, duplicate path; `--write-baseline` refusing.
- **`modules.md`:** in both directions, including `notYetImplemented`.
- **`--packages`:** an undeclared dependency.

**On the prototype itself:** 37 files in 28 targets, including tests, manifests and the checker.
- Changing presentation's `internal import PrestoCVDomain` to `public import` is reported as `R5 importAccess` (review round 2).
- When the renderer test support started importing `CVDesignCatalog`, both the import check and `--packages` reported it until `rules.json` and [modules.md](../modules.md) were updated.
- The first run found **14 real violations** in the prototype's own code, all under R7 and R2. They were fixed in the code, not excepted.
  - Six `try?` in the file store and the design validator became explicit mappings; two of them hid a real failure (an unreadable quarantine read as empty).
  - The heading catalogue listed files with `FileManager` and treated a corrupt table as "unsupported language".
  - `Bundle.module` was then allowed by the detector as a package's own resources, as R13 requires.
- Final state: 0 findings, empty baseline, and `--packages` consistent for all four packages.
