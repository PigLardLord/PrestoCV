# Architecture checker

It enforces the rules in `docs/architecture/rules.md` (ADR 0006). It parses every Swift file with SwiftSyntax and checks three things:
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

The first build takes a few minutes, because it compiles SwiftSyntax.

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
