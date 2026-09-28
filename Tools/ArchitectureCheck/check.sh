#!/usr/bin/env bash
# Runs the architecture checker on the whole repository with the project's rules (ADR 0006).
# CI, the pre-commit hook and the ticket loop all call this script, so the invocation lives in one place.
# Extra arguments are passed through, e.g. --against <base-baseline.json> or --write-baseline.
set -euo pipefail
ROOT="${ARCHITECTURE_CHECK_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
TOOL="$(cd "$(dirname "$0")" && pwd)"
swift build -c release --package-path "$TOOL" >&2
# The rules and the baseline come from the tree being checked, so a hook that checks an index checkout
# judges the staged rules. The binary is built from this script's own copy, which keeps the build cache.
"$TOOL/.build/release/ArchitectureCheck" "$ROOT" \
  --rules "$ROOT/Tools/ArchitectureCheck/rules.json" --baseline "$ROOT/Tools/ArchitectureCheck/baseline.json" \
  --modules "$ROOT/docs/architecture/modules.md" --adr-dir "$ROOT/docs/architecture/adr" \
  --packages PrestoCVCore,CVPDFExporter,CVGeneratorAI,Tools/ArchitectureCheck "$@"
