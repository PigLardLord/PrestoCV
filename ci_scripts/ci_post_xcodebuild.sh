#!/usr/bin/env bash
# Xcode Cloud runs this after every xcodebuild action, and a failure here fails the build. The pull request check on the
# Mac mini runs it too (docs/release/xcode-cloud.md), with CI_XCODEBUILD_ACTION=build-for-testing and
# CI_PULL_REQUEST_TARGET_BRANCH=main. Every step runs and the script fails at the end, so one build shows all that is wrong.
# Each failed step is named in a line "ci_post_xcodebuild: FAILED: <step>", and the last line says how many steps ran:
# a check that reads this output needs both, because a script that ran no step fails nothing.
#   archive            checks the archive, so one that is wrong never reaches TestFlight;
#   build-for-testing  runs what ADR 0006 needs on a Mac beyond the app tests: the package tests, the architecture check
#                      and its self-test (they see the Apple-only branches of the manifests), the self-test of the archive
#                      check, and the builds of PrestoCVApp and CVPDFExporterExamples. It also runs the source checks, which
#                      read the repository: the machines that then run the test plan have only the built products.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ACTION="${CI_XCODEBUILD_ACTION:-}"
status=0
ran=0
failed=0
step() {
  echo "+ $*"
  ran=$((ran + 1))
  "$@" || { echo "ci_post_xcodebuild: FAILED: $*"; failed=$((failed + 1)); status=1; }
}

if [ "${CI_XCODEBUILD_EXIT_CODE:-0}" != 0 ]; then
  echo "ci_post_xcodebuild: xcodebuild $ACTION failed with exit code $CI_XCODEBUILD_EXIT_CODE, so there is nothing to check"
  exit 0
fi

case "$ACTION" in
  archive)
    step "$ROOT/Tools/Release/check-archive.sh" "${CI_ARCHIVE_PATH:?ci_post_xcodebuild: CI_ARCHIVE_PATH is not set}"
    ;;
  build-for-testing)
    for package in PrestoCVCore CVPDFExporter CVGeneratorAI; do
      step swift test --package-path "$ROOT/$package"
    done
    step swift test --package-path "$ROOT/Tools/SourceChecks"
    # On a pull request the baseline may only shrink, so it is compared with the target branch's. When the checkout has
    # no such branch, the comparison is with an empty baseline.
    check_args=()
    if [ -n "${CI_PULL_REQUEST_TARGET_BRANCH:-}" ]; then
      baseline="$(mktemp)"
      git -C "$ROOT" show "origin/$CI_PULL_REQUEST_TARGET_BRANCH:Tools/ArchitectureCheck/baseline.json" > "$baseline" 2>/dev/null \
        || echo "[]" > "$baseline"
      check_args=(--against "$baseline")
    fi
    step "$ROOT/Tools/ArchitectureCheck/check.sh" ${check_args[@]+"${check_args[@]}"}
    step "$ROOT/Tools/ArchitectureCheck/selftest.sh"
    # The archive check itself runs on the archive, after the merge; its self-test runs here, on every pull request.
    step "$ROOT/Tools/Release/check-archive-selftest.sh"
    # PrestoCVApp has no tests until step 5 (#88); building it checks its targets and cross-package dependencies.
    step swift build --package-path "$ROOT/PrestoCVApp"
    # The demos and the template viewer, apart from the library (R14); they use the legacy exporter, Apple hosts only.
    step swift build --package-path "$ROOT/CVPDFExporterExamples"
    ;;
  *)
    echo "ci_post_xcodebuild: action '$ACTION' has nothing to check"
    ;;
esac
echo "ci_post_xcodebuild: ${ACTION:-no action} ran $ran steps, $failed failed"
exit "$status"
