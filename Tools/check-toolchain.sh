#!/usr/bin/env bash
# Fails unless the active Swift is the one `.swift-version` pins (ADR 0026), so a local run, the Linux CI job,
# the Mac pull request check and Xcode Cloud all build with the same compiler.
# On Linux, swiftly reads `.swift-version` from the working directory, so the script runs from the root.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
pinned="$(tr -d '[:space:]' < "$ROOT/.swift-version")"
if [[ ! "$pinned" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "check-toolchain: error: .swift-version holds '$pinned', not a version such as 6.4.2" >&2
  exit 1
fi
if ! banner="$(swift --version 2>&1)"; then
  echo "check-toolchain: error: 'swift --version' failed: $banner" >&2
  exit 1
fi
# "Swift version 6.4.2 (swift-6.4.2-RELEASE)" on Linux, "Apple Swift version 6.4.2 (swiftlang-…)" with Xcode.
active="$(sed -nE 's/.*Swift version ([0-9]+\.[0-9]+(\.[0-9]+)?)[ (].*/\1/p' <<<"$banner" | head -n 1)"
if [ -z "$active" ]; then
  echo "check-toolchain: error: no Swift version in: $(head -n 1 <<<"$banner")" >&2
  exit 1
fi
# Xcode prints "6.4" for 6.4.0.
if [[ "$active" =~ ^[0-9]+\.[0-9]+$ ]]; then
  active="$active.0"
fi
if [ "$active" != "$pinned" ]; then
  echo "check-toolchain: error: the active Swift is $active ($(head -n 1 <<<"$banner")), and .swift-version pins $pinned" >&2
  case "$(uname -s)" in
    Darwin) echo "check-toolchain: use the Xcode whose Swift is $pinned (DEVELOPER_DIR), or install it" >&2 ;;
    *) echo "check-toolchain: install it with 'swiftly install $pinned'; swiftly then picks it from .swift-version" >&2 ;;
  esac
  exit 1
fi
echo "check-toolchain: Swift $active, as .swift-version pins"
