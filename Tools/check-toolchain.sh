#!/usr/bin/env bash
# Fails unless the active Swift is a release of the one `.swift-version` pins (ADR 0026), so a local run, the Linux
# CI job, the Mac pull request check and Xcode Cloud all build with the same compiler.
# On Linux, swiftly reads `.swift-version` from the working directory, so the script runs from the root.
# It runs under the bash of macOS too (3.2): the regular expressions live in variables, and nothing newer is used.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
pinned="$(tr -d '[:space:]' < "$ROOT/.swift-version")"
full_version='^[0-9]+\.[0-9]+\.[0-9]+$'
short_version='^[0-9]+\.[0-9]+$'
if [[ ! "$pinned" =~ $full_version ]]; then
  echo "check-toolchain: error: .swift-version holds '$pinned', not a version such as 6.4.2" >&2
  exit 1
fi
if ! banner="$(swift --version 2>&1)"; then
  echo "check-toolchain: error: 'swift --version' failed: $banner" >&2
  exit 1
fi

# Xcode prints "6.4" for 6.4.0.
full() {
  if [[ "$1" =~ $short_version ]]; then echo "$1.0"; else echo "$1"; fi
}

# The first line that names the version; Xcode's driver can print "swift-driver version: … " before it.
line=""
while IFS= read -r candidate; do
  case "$candidate" in *"Swift version "*) line="$candidate"; break ;; esac
done <<<"$banner"
if [ -z "$line" ]; then
  echo "check-toolchain: error: no Swift version in the output of 'swift --version': '$(head -n 1 <<<"$banner")'" >&2
  exit 1
fi

# A banner names its version twice, and both must be the same release:
# - a swift.org toolchain (Linux, or one installed on a Mac): "Swift version 6.4.2 (swift-6.4.2-RELEASE)";
# - Xcode: "Apple Swift version 6.4.2 (swiftlang-6.4.2.1.9 clang-…)", where the build's first three numbers are the
#   release.
# A development snapshot ("swift-6.4.2-DEVELOPMENT-SNAPSHOT-…", "6.4.2-dev (LLVM …)") matches neither and is refused.
# An Xcode beta prints the same banner as its release, so the banner cannot tell them apart.
version='[0-9]+\.[0-9]+(\.[0-9]+)?'
swift_org="(^| )Swift version ($version) \\(swift-($version)-RELEASE\\)"
xcode="(^| )Apple Swift version ($version) \\(swiftlang-([0-9]+\\.[0-9]+\\.[0-9]+)\\.[0-9]"
if [[ "$line" =~ $swift_org ]]; then
  stated="$(full "${BASH_REMATCH[2]}")"
  build="$(full "${BASH_REMATCH[4]}")"
elif [[ "$line" =~ $xcode ]]; then
  stated="$(full "${BASH_REMATCH[2]}")"
  build="${BASH_REMATCH[4]}"
else
  echo "check-toolchain: error: not a release toolchain: '$line'" >&2
  exit 1
fi
if [ "$stated" != "$build" ]; then
  echo "check-toolchain: error: the banner names two versions, $stated and $build: '$line'" >&2
  exit 1
fi
active="$stated"
if [ "$active" != "$pinned" ]; then
  echo "check-toolchain: error: the active Swift is $active ('$line'), and .swift-version pins $pinned" >&2
  case "$(uname -s)" in
    Darwin) echo "check-toolchain: use the Xcode whose Swift is $pinned (DEVELOPER_DIR), or install it" >&2 ;;
    *) echo "check-toolchain: install it with 'swiftly install $pinned'; swiftly then picks it from .swift-version" >&2 ;;
  esac
  exit 1
fi
echo "check-toolchain: Swift $active, as .swift-version pins"
