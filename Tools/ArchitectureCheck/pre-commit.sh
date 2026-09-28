#!/usr/bin/env bash
# Pre-commit architecture check (ADR 0006). It checks what is being committed, a checkout of the index in a
# temporary directory, not the working tree. So a violation that is staged blocks the commit, and one that is
# only in the working tree does not.
# It runs only when the commit touches something the checker reads: Swift files, manifests, the checker itself,
# or docs/architecture. Renames count as a deletion plus an addition, so moving a file out of a watched path still
# triggers the check. The staged checker is the one that runs; its build shares the working tree's build cache.
set -euo pipefail
REPO="$(git rev-parse --show-toplevel)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
# NUL-separated, so no path is quoted or escaped (non-ASCII names, newlines), and read from a file, so a git failure
# stops the hook instead of looking like an empty list.
git -C "$REPO" diff --cached --name-only --no-renames -z > "$TMP/paths"
RELEVANT=0
while IFS= read -r -d '' path; do
  if [[ "$path" =~ \.swift$|(^|/)Package\.swift$|^Tools/ArchitectureCheck/|^docs/architecture/ ]]; then RELEVANT=1; break; fi
done < "$TMP/paths"
[ "$RELEVANT" = 1 ] || exit 0
mkdir -p "$TMP/tree"
git -C "$REPO" checkout-index -a --prefix="$TMP/tree/"
if [ ! -x "$TMP/tree/Tools/ArchitectureCheck/check.sh" ]; then
  echo "The staged tree has no Tools/ArchitectureCheck/check.sh: the architecture check cannot run." >&2
  exit 1
fi
if ! ARCHITECTURE_CHECK_ROOT="$TMP/tree" ARCHITECTURE_CHECK_SCRATCH="$REPO/Tools/ArchitectureCheck/.build" \
     "$TMP/tree/Tools/ArchitectureCheck/check.sh"; then
  echo "Architecture check failed on the staged changes (see docs/architecture/rules.md)." >&2
  exit 1
fi
