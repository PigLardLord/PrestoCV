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
  put docs/architecture/adr/README.md $'# ADRs\n\n| # | Decision | Status |\n|---|---|---|\n| [0001](0001-first.md) | First | Accepted |'
  put docs/architecture/adr/0001-first.md $'# 0001. First\n\n- **Status:** Accepted'
  put AGENTS.md "$AGENTS_RULE"
  put .github/pull_request_template.md "$TEMPLATE"
}
AGENTS_RULE=$'# Guidelines\n\n- **Documentation changes with the code in the same pull request.** The template asks which documents change.'
TEMPLATE=$'## Purpose\n\n## Documents updated\n\nWhich documents does this change update?'

ADR=docs/architecture/adr
# adr_index <row>...: the ADR index with the given rows.
adr_index() { local text=$'# ADRs\n\n| # | Decision | Status |\n|---|---|---|'; for row in "$@"; do text+=$'\n'"$row"; done; put $ADR/README.md "$text"; }
# put <path> <contents>: writes a file of the repository, replacing it.
put() { mkdir -p "$ROOT/$(dirname "$1")"; printf '%s\n' "$2" > "$ROOT/$1"; }
# A run that does not end within a minute fails (exit 124) where the host has timeout(1).
BOUND=(); if command -v timeout > /dev/null; then BOUND=(timeout 60); fi
run() { "${BOUND[@]}" "$CHECK" "$ROOT" "$@" > "$OUT" 2>&1; echo $?; }
expect() {
  local name="$1" want="$2" pat="$3"; shift 3
  local got; got=$(run "$@")
  if [[ "$got" == "$want" ]] && { [[ -z "$pat" ]] || grep -qE -- "$pat" "$OUT"; }; then pass=$((pass+1)); echo "ok   $name"
  else fail=$((fail+1)); echo "FAIL $name (exit $got, want $want)"; sed 's/^/     /' "$OUT"; fi
}
# stale <name> <pattern>: the repository as planted fails with a finding that matches the pattern.
stale() { local name="$1" pat="$2"; shift 2; expect "stale: $name" 1 "$pat" "$@"; }
fixed() { local name="$1"; shift; expect "fixed: $name" 0 "" "$@"; }

# --- the repository the cases start from is accepted
setup; expect "a consistent repository passes" 0 "checked 5 documents: 0 findings"

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
setup; put README.md $'# Project\n\nA link in a code span, `[gone](gone.md)`, or in a block, is not a link:\n\n```\n[gone](gone.md)\n```'
fixed "a link in a code span or in a fenced block is not a link"
setup; put README.md "$(printf '# Project\n\n## %s' "$(head -c 200000 /dev/zero | tr '\0' 'a')")"
stale "a 200,000-character heading" "^README.md:3: heading-too-long:"
put README.md $'# Project\n\n## Short'; fixed "a short heading"
setup; put README.md "$(printf '# Project\n\n## %s' "$(head -c 100000 /dev/zero | tr '\0' '[')")"
stale "100,000 brackets in a heading" "^README.md:3: heading-too-long:"
setup; put README.md "$(printf '# Project\n\n## %s' "$(head -c 300 /dev/zero | tr '\0' '[')x$(head -c 300 /dev/zero | tr '\0' ']')")"
stale "link labels nested 300 deep" "^README.md:3: heading-too-nested:"
setup; put README.md "$(head -c 200000 /dev/zero | tr '\0' ']' | sed 's/\]/](/g')"
stale "100,000 link openers on one line are read in linear time, and the finding is one short line" "^README.md:1: link-target-missing: .{1,300}$"
setup; put README.md $'# Project\n\nA comment hides what is stale: <!-- [gone](gone.md) `Tools/gone.sh` -->\n<!--\n[gone](gone.md)\n-->'; mkdir -p "$ROOT/Tools"
fixed "a link and a path in an HTML comment are not read"
setup; put README.md $'# Project\n\n<a name="top"></a>\n\nBack to [the top](#top).'
fixed "an explicit HTML anchor is a target"
put README.md $'# Project\n\n<a name="top"></a>\n\nBack to [the top](#start).'
stale "a link to an anchor that no heading or tag defines" "^README.md:5: link-anchor-missing:"
setup; mkdir -p "$ROOT/Tools/Pkg/docs"; put Tools/Pkg/README.md $'# Pkg\n\nSee `docs/beside.md`.'; put Tools/Pkg/docs/beside.md '# Beside'
fixed "a path that exists beside its document, not at the root"
rm "$ROOT/Tools/Pkg/docs/beside.md"
stale "a path that exists neither at the root nor beside its document" "^Tools/Pkg/README.md:3: path-missing:"
setup; put Shared/root.txt ''; put Tools/Pkg/Shared/y.txt ''; put Tools/Pkg/Tools/README.md $'# Tools\n\nSee `Shared/y.txt`.'
fixed "a path that exists from a directory above its document"
put Tools/Pkg/Tools/README.md $'# Tools\n\nSee `Shared/z.txt`.'
stale "a path that exists from none of them" "^Tools/Pkg/Tools/README.md:3: path-missing:"
setup; put README.md $'# Project\n\nThe server is in `Server/Package.swift`, see `Server/README.md`.'
stale "files named in a directory that does not exist" "^README.md:3: path-missing: .Server/Package.swift. does not exist"
put Server/Package.swift ''; put Server/README.md '# Server'; fixed "the directory and its files exist"
setup; put README.md $'# Project\n\nSee `other-repo:core/Tailor.js`, `example.com/index.html` and `other/image.png`.'
fixed "a prefixed path, a host name and a file of another kind are not paths"
setup; put Package/README.md $'[gone](gone.md)'; put Package/.build/checkouts/dep/README.md $'[gone](gone.md)'
stale "a README in a package" "^Package/README.md:1: link-target-missing:"
rm "$ROOT/Package/README.md"; fixed "the README in .build is not read"
setup; ROOT="$ROOT/missing"; expect "a root that does not exist is an error, not a pass" 2 "^error: cannot read .*/missing$"

# --- 2. named paths
setup; put README.md $'# Project\n\nRun `Tools/check.sh` to check.'; mkdir -p "$ROOT/Tools"; put Tools/run.sh '#!/bin/sh'
stale "a path in backticks that does not exist" "^README.md:3: path-missing:"
put Tools/check.sh '#!/bin/sh'; fixed "the file exists"
setup; mkdir -p "$ROOT/Tools"; put README.md $'# Project\n\nThe tools are in `Tools/old/`, see `Tools/run.sh:12`.'; put Tools/run.sh ''
stale "a directory in backticks that does not exist" "^README.md:3: path-missing: .Tools/old. does not exist"
mkdir -p "$ROOT/Tools/old"; fixed "the directory exists"
setup; mkdir -p "$ROOT/Tools"; put README.md $'# Project\n\n`Tools/<name>/x.sh` `Tools/*.sh` `Tools/{a,b}.sh` `Tools/...` `~/Tools/x` `/Tools/x` `Other/x` `Tools/.build/y`\n```\nTools/gone.sh\n```'
fixed "placeholders, globs, paths under ~ or /, other names, build products and fenced code are skipped"
setup; mkdir -p "$ROOT/Tools"; put README.md $'# Project\n\nThe `Tools/future.sh` script will check it.'
stale "a planned file that is not declared" "^README.md:3: path-missing:"
put planned.json $'[\n  {"path": "Tools/future.sh", "ticket": 99}\n]'; fixed "the path is declared as planned" --planned "$ROOT/planned.json"
put Tools/future.sh '#!/bin/sh'
stale "a declared path that exists" "^planned.json:2: planned-path-exists:" --planned "$ROOT/planned.json"
put planned.json '[]'; fixed "its entry is removed" --planned "$ROOT/planned.json"
setup; mkdir -p "$ROOT/Tools"; put planned.json $'[\n  {"path": "Tools/future.sh", "ticket": 99}\n]'
stale "a declared path that no document names" "^planned.json:2: planned-path-unused:" --planned "$ROOT/planned.json"
put planned.json $'[{"path": "Tools/future.sh"}]'
stale "a planned entry without its ticket" "^planned.json:1: planned-file-invalid:" --planned "$ROOT/planned.json"
setup; expect "a planned file that cannot be read is an error, not a pass" 2 "^error: cannot read planned.json$" --planned "$ROOT/planned.json"

# --- 3. ADR status and index
setup; put $ADR/0001-first.md $'# 0001. First\n\n- **Date:** 2026-01-01'
stale "an ADR without a status" "^$ADR/0001-first.md:1: adr-status-missing:"
put $ADR/0001-first.md $'# 0001. First\n\n- **Status:** Accepted\n- **Date:** 2026-01-01'; fixed "the ADR has a status"
setup; put $ADR/0001-first.md $'# 0001. First\n\n- **Status:** Draft'; adr_index '| [0001](0001-first.md) | First | Draft |'
stale "a status the ADR README does not define" "^$ADR/0001-first.md:3: adr-status-unknown:"
put $ADR/0001-first.md $'# 0001. First\n\n- **Status:** Proposed'; adr_index '| [0001](0001-first.md) | First | Proposed |'; fixed "a defined status"
setup; put $ADR/0001-first.md $'# 0001. First\n\n- **Status:** Superseded by 0002'; adr_index '| [0001](0001-first.md) | First | Superseded by 0002 |'
put $ADR/0002-second.md $'# 0002. Second\n\n- **Status:** Accepted'
stale "a superseded ADR that names its replacement without a link" "^$ADR/0001-first.md:3: adr-superseded-without-link:"
put $ADR/0001-first.md $'# 0001. First\n\n- **Status:** Superseded by [0002](0002-second.md)'
adr_index '| [0001](0001-first.md) | First | Superseded by [0002](0002-second.md) |' '| [0002](0002-second.md) | Second | Accepted |'; fixed "the replacement is linked"
rm "$ROOT/$ADR/0002-second.md"; adr_index '| [0001](0001-first.md) | First | Superseded by [0002](0002-second.md) |'
stale "a superseded ADR whose replacement does not exist" "^$ADR/0001-first.md:3: adr-successor-missing:"
setup; put $ADR/0002-second.md $'# 0002. Second\n\n- **Status:** Accepted'
stale "an ADR that the index does not list" "^$ADR/0002-second.md:1: adr-not-indexed:"
adr_index '| [0001](0001-first.md) | First | Accepted |' '| [0002](0002-second.md) | Second | Accepted |'; fixed "the index lists it"
adr_index '| [0001](0001-first.md) | First | Accepted |' '| [0002](0002-second.md) | Second | Proposed |'
stale "an index row with another status than its ADR" "^$ADR/README.md:6: adr-index-status-differs:"
adr_index '| [0001](0001-first.md) | First | Accepted |' '| [0002](0002-second.md) | Second | Accepted |' '| [0003](0003-third.md) | Third | Accepted |'
stale "an index row for an ADR that has no file" "^$ADR/README.md:7: adr-index-unknown:"
setup; rm -r "$ROOT/$ADR"
stale "no ADR directory is an error, not a pass" "^$ADR:1: adr-directory-missing:"

# --- 4. the rule is stated
setup; put AGENTS.md $'# Guidelines\n\n- Documentation is welcome.'
stale "AGENTS.md does not state the rule" "^AGENTS.md:1: rule-not-stated:"
put AGENTS.md "$AGENTS_RULE"; fixed "AGENTS.md states the rule"
setup; put AGENTS.md $'# Guidelines\n\nDocumentation changes with the code, in a later pull request.'
stale "AGENTS.md states a different rule" "^AGENTS.md:1: rule-not-stated:"
setup; rm "$ROOT/AGENTS.md"
stale "no AGENTS.md" "^AGENTS.md:1: rule-not-stated:"
setup; rm "$ROOT/.github/pull_request_template.md"
stale "no pull request template" "^.github/pull_request_template.md:1: template-missing:"
put .github/pull_request_template.md "$TEMPLATE"; fixed "the template exists"
setup; put .github/pull_request_template.md $'## Purpose\n\n## Validation'
stale "a template that does not ask which documents the change updates" "^.github/pull_request_template.md:1: template-does-not-ask:"
put .github/pull_request_template.md $'## Purpose\n\n### Documents updated\n\nWhich?'; fixed "the template asks"

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
