# 0012. Keep legacy targets out of Linux builds and out of the rules until deleted

- **Status:** Accepted
- **Date:** 2026-09-28
- **Related:** [ADR 0001](0001-architecture-before-bug-fixing.md), [ADR 0006](0006-enforce-architecture-mechanically.md), R9, R11, [README migration strategy](../README.md#migration-strategy)

## Context

The new targets are added inside the existing packages (`PrestoCVCore`, `CVPDFExporter`, `CVGeneratorAI`) and replace the old code step by step. Three facts get in the way of "every step is green on iOS, macOS and Linux":

- **The old code does not build on Linux.** `PrestoCVCore` uses `String(localized:)` in the domain. `CVPDFExporter` depends on it, and also imports CryptoKit.
- **One failing target breaks the whole package.** `swift build` of a package fails on Linux if any one of its targets cannot compile there ([ADR 0003](0003-one-pdf-renderer-per-platform.md#validation)).
- **The old code breaks the new rules everywhere.** It is in Swift 5 mode and violates most rules. Holding it to R1–R14 until it is deleted would only produce noise.

## Decision

- **Declared only on Apple hosts.** Each package manifest declares its legacy targets inside `#if !os(Linux)`, with `.swiftLanguageMode(.v5)`. On Linux the package contains only the new targets, which build and test normally. Verified on 2026-09-27 with Swift 6.3.3: a package whose legacy target imports UIKit and CryptoKit builds and tests on Linux when that target is declared this way.
- **Exempt from the rules.** In the checker's `rules.json`, legacy targets have `"kind": "legacy"`. Their files must still be mapped, which the inventory checks, but they are exempt from every rule. New targets cannot import them, because no allow-list names them. In a manifest, the exemption covers only the declaration of a legacy target that the manifest owns.
  - A target belongs to the nearest `Package.swift` above its path, so a parent package never owns a nested package's targets.
  - The checker assigns each manifest finding to the `.target(name:)` call that contains it.
  - Target names in `rules.json` must be unique. So `.swiftLanguageMode(.v5)` passes inside a legacy target, but fails on a new target of the same manifest, and so does a package-wide `swiftLanguageModes:` setting. There is no manifest-wide exception (review round 4).
- **No mixing.** A new target never depends on a legacy target, and a legacy target is never modified except to delete it or to keep the app building.
- **Old and new coexist until the app switches.** The old exporter keeps `PrestoCVCoreAdapter` until the app switches to the new export workflow (migration step 5). The new exporter targets never depend on `PrestoCVCore`.
- **Deleted, with no leftovers.** When a context is migrated, its legacy targets, their `#if !os(Linux)` block and their `rules.json` entries are deleted in the same pull request. The goal is no legacy entries before the first release.

## Consequences

- Linux CI covers exactly the new code, from the first migration step.
- macOS CI still builds and tests the legacy targets, so the app keeps working during the migration.
- The manifests carry a temporary `#if !os(Linux)` block. It is visible, and it disappears with the last legacy target.

## Alternatives considered

- **New packages beside the old ones.** They would need different package identities (for example `PrestoCVCore2`), and every name would change again at cut-over.
- **Make the old code build on Linux first.** That means repairing code scheduled for deletion.
- **A Linux job that builds an explicit target list.** `swift test` builds every test target, so legacy tests would still have to compile.

## Validation

The Linux build was verified with a throwaway package: one new target plus one legacy target importing UIKit and CryptoKit inside `#if !os(Linux)`. `swift build` and `swift test` succeed on Swift 6.3.3 (Linux). The checker's `legacy` kind is implemented in the prototype checker.
