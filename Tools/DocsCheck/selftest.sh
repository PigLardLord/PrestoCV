#!/usr/bin/env bash
# Self-test of the documentation checker: for each check, a planted stale document makes it fail, and the fixed
# document passes. Every case builds a small repository in a temporary directory.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# The same build directory check.sh uses (DOCS_CHECK_SCRATCH), so CI can keep it outside the checkout.
CHECK="${DOCS_CHECK_SCRATCH:-$HERE/.build}/release/DocsCheck"
pass=0; fail=0; ROOTS=()
OUT="$(mktemp)"
trap 'rm -rf "${ROOTS[@]}" "$OUT"' EXIT

# A repository the checker accepts. Each case then plants one stale document, or fixes it.
setup() {
  ROOT="$(mktemp -d)"; ROOTS+=("$ROOT")
  put README.md $'# Project\n\nSee the [guide](docs/guide.md).'
  put docs/guide.md $'# Guide\n\n## Usage\n\nBack to the [readme](../README.md#project).'
}
# put <path> <contents>: writes a file of the repository, replacing it.
put() { mkdir -p "$ROOT/$(dirname "$1")"; printf '%s\n' "$2" > "$ROOT/$1"; }
run() { "$CHECK" "$ROOT" "$@" > "$OUT" 2>&1; echo $?; }
expect() {
  local name="$1" want="$2" pat="$3"; shift 3
  local got; got=$(run "$@")
  if [[ "$got" == "$want" ]] && { [[ -z "$pat" ]] || grep -qE -- "$pat" "$OUT"; }; then pass=$((pass+1)); echo "ok   $name"
  else fail=$((fail+1)); echo "FAIL $name (exit $got, want $want)"; sed 's/^/     /' "$OUT"; fi
}
# stale <name> <pattern>: the repository as planted fails with a finding that matches the pattern.
stale() { expect "stale: $1" 1 "$2"; }
fixed() { expect "fixed: $1" 0 ""; }

# --- the repository the cases start from is accepted
setup; expect "a consistent repository passes" 0 "checked 2 documents: 0 findings"

# --- 1. links
setup; put README.md $'# Project\n\nSee the [guide](docs/missing.md).'
stale "a link to a file that does not exist" "^README.md:3: link-target-missing:"
put docs/missing.md '# Missing'; fixed "the file exists"
setup; put docs/guide.md $'# Guide\n\n[tools](../Tools/)'
stale "a link to a directory that does not exist" "^docs/guide.md:3: link-target-missing:"
mkdir -p "$ROOT/Tools"; fixed "the directory exists"
setup; put docs/guide.md $'# Guide\n\n## Usage\n\nSee [usage](#installation).'
stale "an anchor that is not a heading of the file" "^docs/guide.md:5: link-anchor-missing:"
put docs/guide.md $'# Guide\n\n## Installation\n\nSee [usage](#installation).'; fixed "the heading exists"
setup; put README.md $'# Project\n\nSee the [guide](docs/guide.md#set-up).'
stale "an anchor into another file that is not one of its headings" "^README.md:3: link-anchor-missing:"
put docs/guide.md $'# Guide\n\n## Set `up`!\n\n## Set up'; put README.md $'# Project\n\n[a](docs/guide.md#set-up) [b](docs/guide.md#set-up-1)'; fixed "headings with punctuation and a repeat"
setup; put README.md $'# Project\n\n[gone](https://example.invalid/gone.md) [mail](mailto:nobody@example.invalid)'
fixed "links to other sites are not followed"
setup; put Package/README.md $'[gone](gone.md)'; put Package/.build/checkouts/dep/README.md $'[gone](gone.md)'
stale "a README in a package" "^Package/README.md:1: link-target-missing:"
rm "$ROOT/Package/README.md"; fixed "the README in .build is not read"
setup; ROOT="$ROOT/missing"; expect "a root that does not exist is an error, not a pass" 2 "^error:"

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
