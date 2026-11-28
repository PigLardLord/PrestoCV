#!/usr/bin/env bash
# Runs the checks of the Linux CI job, the same way, on a computer or in CI (ADR 0026):
# the toolchain against .swift-version, the architecture check (against the base's baseline when a ref is given,
# ADR 0006), its self-test, the source checks (which also compare the store listing's pending locales with the base's), and the build and tests of the new targets (ADR 0012).
# Usage: Tools/check-linux.sh [<base ref>], e.g. Tools/check-linux.sh origin/main
# On a Mac, ci_scripts/ci_post_xcodebuild.sh runs these checks and the Apple ones.
set -uo pipefail
if [ "$(uname -s)" != Linux ]; then
  echo "check-linux: error: this is the Linux job; on a Mac, the checks run in ci_scripts/ci_post_xcodebuild.sh" >&2
  exit 2
fi
# The CI container runs in the C locale, and Swift Build 6.4 cannot read a translated `ld` banner
# (swiftlang/swift-build#1934), so a computer set to another language runs the checks in the C locale too.
export LC_ALL=C
# Swift's tools leave folders in the temporary folder, and some tests leave theirs: the run keeps its
# temporary files in a folder of its own and removes it at the end.
if ! run_tmp="$(mktemp -d)"; then
  echo "check-linux: error: cannot create a temporary folder in '${TMPDIR:-/tmp}'" >&2
  exit 1
fi
trap 'rm -rf "$run_tmp"' EXIT
export TMPDIR="$run_tmp"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
Tools/check-toolchain.sh || exit 1
# Some steps run swift from other folders (the checker's `swift package dump-package`, the self-test's scratch
# packages), where a toolchain manager would not see .swift-version: the pinned toolchain goes first on the PATH.
resources="$(swift -print-target-info | sed -nE 's/.*"runtimeResourcePath": "(.*)\/lib\/swift".*/\1/p')"
if [ ! -x "$resources/bin/swift" ]; then
  echo "check-linux: error: no swift in '$resources/bin', the folder 'swift -print-target-info' names" >&2
  exit 1
fi
export PATH="$resources/bin:$PATH"

against=()
if [ $# -gt 0 ]; then
  if ! git rev-parse --verify --quiet "$1^{commit}" > /dev/null; then
    echo "check-linux: error: '$1' is not a commit" >&2
    exit 2
  fi
  base_baseline="$run_tmp/base-baseline.json"
  git show "$1:Tools/ArchitectureCheck/baseline.json" > "$base_baseline" 2> /dev/null || echo '[]' > "$base_baseline"
  against=(--against "$base_baseline")
  # The source checks hold the store listing's pendingLocales to the base's list, which may only shrink (read with git show).
  export PRESTOCV_TARGET_REF="$1"
fi

ran=0
failed=0
step() {
  ran=$((ran + 1))
  [ -z "${GITHUB_ACTIONS:-}" ] || echo "::group::$*"
  echo "+ $*"
  "$@"
  local rc=$?
  [ -z "${GITHUB_ACTIONS:-}" ] || echo "::endgroup::"
  if [ $rc -ne 0 ]; then
    failed=$((failed + 1))
    if [ -n "${GITHUB_ACTIONS:-}" ]; then echo "::error::check-linux: FAILED: $*"; else echo "check-linux: FAILED: $*" >&2; fi
  fi
}

step Tools/ArchitectureCheck/check.sh "${against[@]}"
step Tools/ArchitectureCheck/selftest.sh
step swift test --package-path Tools/SourceChecks
step swift build --package-path CVGeneratorAI
for package in DiagnosticLogging DiagnosticTrace PrestoCVCore CVPDFExporter PrestoCVApp; do
  step swift test --package-path "$package"
done

echo "check-linux: ran $ran steps, $failed failed"
[ "$failed" -eq 0 ]
