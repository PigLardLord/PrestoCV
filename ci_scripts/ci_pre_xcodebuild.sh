#!/usr/bin/env bash
# Xcode Cloud runs this before every xcodebuild action. It first checks that the Swift of the workflow's Xcode is the one
# .swift-version pins (ADR 0026), so a workflow on another Xcode fails at once. For an archive it then sets the marketing version from the ref: the
# tag v<version> or the branch release/<version>, where <version> is 1.2 or 1.2.3. Any other ref keeps the project's
# version. The build number is not set here: Xcode Cloud sets it. It edits only this checkout of the project file.
set -euo pipefail

"$(cd "$(dirname "$0")/.." && pwd)/Tools/check-toolchain.sh"

if [ "${CI_XCODEBUILD_ACTION:-}" != archive ]; then
  echo "ci_pre_xcodebuild: action '${CI_XCODEBUILD_ACTION:-}' is not an archive, the version stays as it is"
  exit 0
fi

PROJECT="$(cd "$(dirname "$0")/.." && pwd)/PrestoCV.xcodeproj/project.xcproj"
SETTING='"MARKETING_VERSION[^"]*"[[:space:]]*:[[:space:]]*"'
VERSION_PATTERN='^[0-9]+\.[0-9]+(\.[0-9]+)?$'
fail() { echo "ci_pre_xcodebuild: error: $1" >&2; exit 1; }
[ -f "$PROJECT" ] || fail "no project file at $PROJECT"
grep -Eq "$SETTING" "$PROJECT" || fail "no MARKETING_VERSION in $PROJECT"

REF=""; VERSION=""
if [[ "${CI_TAG:-}" == v* ]]; then
  REF="tag $CI_TAG"; VERSION="${CI_TAG#v}"
elif [[ "${CI_BRANCH:-}" == release/* ]]; then
  REF="branch $CI_BRANCH"; VERSION="${CI_BRANCH#release/}"
fi

if [ -z "$REF" ]; then
  echo "ci_pre_xcodebuild: no v<version> tag and no release/<version> branch, so the project's version stays"
else
  [[ "$VERSION" =~ $VERSION_PATTERN ]] || fail "$REF does not name a version: use v1.2.3 or release/1.2.3 (1.2 also works)"
  echo "ci_pre_xcodebuild: setting MARKETING_VERSION to $VERSION from $REF"
  sed -E "s/(${SETTING})[^\"]*\"/\1${VERSION}\"/" "$PROJECT" > "$PROJECT.new"
  mv "$PROJECT.new" "$PROJECT"
  if grep -E "$SETTING" "$PROJECT" | grep -qvF "\"$VERSION\""; then fail "a MARKETING_VERSION was not set to $VERSION"; fi
fi
echo "Version used:"
grep -E "$SETTING" "$PROJECT" | sed -E 's/^[[:space:]]+/  /'
