#!/usr/bin/env bash
# Runs the documentation checker on the whole repository (issue #183). CI and developers call this script, so the
# invocation lives in one place. Extra arguments are passed through, e.g. --known-top-level <names.txt>.
# Inside a git checkout, the top-level names of HEAD also count as top-level (--known-top-level), so deleting or
# renaming a directory fails the check until the documents that name it follow.
set -euo pipefail
ROOT="${DOCS_CHECK_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
TOOL="$(cd "$(dirname "$0")" && pwd)"
# The build directory can live elsewhere (DOCS_CHECK_SCRATCH), so CI can keep it outside the checkout.
SCRATCH="${DOCS_CHECK_SCRATCH:-$TOOL/.build}"
swift build -c release --package-path "$TOOL" --scratch-path "$SCRATCH" >&2
KNOWN=()
KNOWN_FILE="$(mktemp)"
trap 'rm -f "$KNOWN_FILE"' EXIT
if git -C "$ROOT" ls-tree --name-only HEAD > "$KNOWN_FILE" 2> /dev/null; then
  KNOWN=(--known-top-level "$KNOWN_FILE")
fi
# The planned-paths list comes from the tree being checked.
"$SCRATCH/release/DocsCheck" "$ROOT" --planned "$ROOT/Tools/DocsCheck/planned.json" ${KNOWN[@]+"${KNOWN[@]}"} "$@"
