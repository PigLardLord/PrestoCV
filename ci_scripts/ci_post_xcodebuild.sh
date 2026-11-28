#!/usr/bin/env bash
# Xcode Cloud runs this after every xcodebuild action, and a failure here fails the build. The pull request check on the
# Mac mini runs it too (docs/release/xcode-cloud.md), with CI_XCODEBUILD_ACTION=build-for-testing and
# CI_PULL_REQUEST_TARGET_BRANCH=main. Every step runs and the script fails at the end, so one build shows all that is wrong.
# Each failed step is named in a line "ci_post_xcodebuild: FAILED: <step>", and the last line says how many steps ran:
# a check that reads this output needs both, because a script that ran no step fails nothing.
#   archive            checks the archive, so one that is wrong never reaches TestFlight;
#   build-for-testing  checks the Swift against .swift-version (ADR 0026), then runs what ADR 0006 needs on a Mac beyond
#                      the app tests: the package tests, the architecture check
#                      and its self-test (they see the Apple-only branches of the manifests), the self-tests of the archive
#                      check and of the screenshot tools, the check of the store listing (against the target
#                      branch's list of locales still written for 1.0), the tests of PrestoCVApp, and the
#                      builds of the app for macOS and of CVPDFExporterExamples. It
#                      also runs the source checks, which read the repository: the machines that then run the test plan
#                      have only the built products.
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
    step "$ROOT/Tools/check-toolchain.sh"
    for package in DiagnosticLogging DiagnosticTrace PrestoCVCore CVPDFExporter CVGeneratorAI; do
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
    # The screenshot tool erases simulators: its guards (reserved name, one run at a time, put back on every way out) are
    # tested here on fake tools.
    step "$ROOT/Tools/Release/store-screenshots-selftest.sh"
    # The captions are paired with the six screenshots by position: the listing must hold exactly six for each locale, and
    # the composer must refuse any other number, a capture of the wrong size and a folder it would leave stale.
    # The locales still written for 1.0 may only shrink, so on a pull request their list is compared with the target
    # branch's. A checkout with no such branch compares with an empty list, as the baseline above; a target branch that
    # has no list yet has nothing to compare with.
    listing_args=()
    if [ -n "${CI_PULL_REQUEST_TARGET_BRANCH:-}" ]; then
      retired="$(mktemp)"
      target="origin/$CI_PULL_REQUEST_TARGET_BRANCH"
      if ! git -C "$ROOT" rev-parse --verify --quiet "$target^{commit}" > /dev/null; then
        echo '{"pendingLocales": []}' > "$retired"
        listing_args=(--against "$retired")
      elif git -C "$ROOT" show "$target:Tools/Release/store-listing-retired-words.json" > "$retired" 2>/dev/null; then
        listing_args=(--against "$retired")
      fi
    fi
    step "$ROOT/Tools/Release/check-store-listing.py" ${listing_args[@]+"${listing_args[@]}"}
    step "$ROOT/Tools/Release/check-store-listing-selftest.py"
    step "$ROOT/Tools/Release/compose-store-screenshots-selftest.sh"
    step swift test --package-path "$ROOT/PrestoCVApp"
    # The app is built for its second platform (docs/architecture/modules.md): the test plans run it on iOS only.
    mac_build="$(mktemp -d)"
    step xcodebuild build -project "$ROOT/PrestoCV.xcodeproj" -scheme PrestoCV -destination 'generic/platform=macOS' \
        -derivedDataPath "$mac_build" CODE_SIGNING_ALLOWED=NO -quiet
    rm -rf "$mac_build"
    # The exporter's demos, apart from the library (R14); they use the legacy exporter, Apple hosts only.
    step swift build --package-path "$ROOT/CVPDFExporterExamples"
    ;;
  *)
    echo "ci_post_xcodebuild: action '$ACTION' has nothing to check"
    ;;
esac
echo "ci_post_xcodebuild: ${ACTION:-no action} ran $ran steps, $failed failed"
exit "$status"
