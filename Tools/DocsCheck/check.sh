#!/usr/bin/env bash
# Runs the documentation checker on the whole repository (issue #183). CI and developers call this script, so the
# invocation lives in one place. Extra arguments are passed through.
set -euo pipefail
ROOT="${DOCS_CHECK_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
TOOL="$(cd "$(dirname "$0")" && pwd)"
# The build directory can live elsewhere (DOCS_CHECK_SCRATCH), so CI can keep it outside the checkout.
SCRATCH="${DOCS_CHECK_SCRATCH:-$TOOL/.build}"
swift build -c release --package-path "$TOOL" --scratch-path "$SCRATCH" >&2
# The planned-paths list comes from the tree being checked.
"$SCRATCH/release/DocsCheck" "$ROOT" --planned "$ROOT/Tools/DocsCheck/planned.json" "$@"
