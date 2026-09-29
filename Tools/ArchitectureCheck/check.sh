#!/usr/bin/env bash
# Runs the architecture checker on the whole repository with the project's rules (ADR 0006).
# CI, the pre-commit hook and the ticket loop all call this script, so the invocation lives in one place.
# Extra arguments are passed through, e.g. --against <base-baseline.json> or --write-baseline.
set -euo pipefail
ROOT="${ARCHITECTURE_CHECK_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
TOOL="$(cd "$(dirname "$0")" && pwd)"
# The build directory can be shared (ARCHITECTURE_CHECK_SCRATCH), so a checker built from another copy of the
# sources, such as the pre-commit hook's index checkout, reuses the compiled SwiftSyntax.
SCRATCH="${ARCHITECTURE_CHECK_SCRATCH:-$TOOL/.build}"
swift build -c release --package-path "$TOOL" --scratch-path "$SCRATCH" >&2
# The rules and the baseline come from the tree being checked, so an index checkout judges the staged rules.
"$SCRATCH/release/ArchitectureCheck" "$ROOT" \
  --rules "$ROOT/Tools/ArchitectureCheck/rules.json" --baseline "$ROOT/Tools/ArchitectureCheck/baseline.json" \
  --modules "$ROOT/docs/architecture/modules.md" --adr-dir "$ROOT/docs/architecture/adr" \
  --packages PrestoCVCore,CVPDFExporter,CVGeneratorAI,PrestoCVApp,Tools/ArchitectureCheck "$@"
