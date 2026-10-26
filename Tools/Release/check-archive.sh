#!/usr/bin/env bash
# Checks an archive before it is uploaded: the bundle identifier, the display name, the version and build, the privacy
# manifest, the encryption declaration, the app icon, the oldest iOS release the app supports (MinimumOSVersion, which
# Xcode writes from IPHONEOS_DEPLOYMENT_TARGET: the check reads what the archive says, not what the sources set, so a
# target that no source check can read is found here), and the document type that "Open in PrestoCV" needs. That type is
# PDF only, with role Viewer and rank Alternate, and the app never opens it in place; the app declares no type of its own
# (no exported or imported type declaration). PrestoCVTests/App/AppInfoPlistTests.swift requires the same of the source
# Info.plist, so change both together. Fails on the first thing that is wrong.
#
#   Tools/Release/check-archive.sh <path to PrestoCV.xcarchive>
#
# Tools/Release/check-archive-selftest.sh tests this check on fake archives.
set -euo pipefail
# The oldest iOS release the app supports (#180). Tools/SourceChecks requires it to be the release its own check holds.
MINIMUM_OS_VERSION="26.5"
ARCHIVE="${1:?usage: check-archive.sh <archive>}"
APP="$ARCHIVE/Products/Applications/PrestoCV.app"
PLIST="$APP/Info.plist"
read_key() { /usr/libexec/PlistBuddy -c "Print :$1" "$PLIST" 2>/dev/null; }
fail() { echo "::error::$1"; exit 1; }

[ -d "$APP" ] || fail "no PrestoCV.app in $ARCHIVE"
[ "$(read_key CFBundleIdentifier)" = "com.PigLardLord.prestocv" ] || fail "unexpected bundle identifier: $(read_key CFBundleIdentifier)"
[ "$(read_key CFBundleDisplayName)" = "PrestoCV" ] || fail "unexpected display name: $(read_key CFBundleDisplayName)"
[ -n "$(read_key CFBundleShortVersionString)" ] || fail "no version"
[ -n "$(read_key CFBundleVersion)" ] || fail "no build number"
[ "$(read_key ITSAppUsesNonExemptEncryption)" = "false" ] || fail "ITSAppUsesNonExemptEncryption is not false"
[ -f "$APP/PrivacyInfo.xcprivacy" ] || fail "no privacy manifest in the app bundle"
[ -n "$(read_key CFBundleIcons:CFBundlePrimaryIcon:CFBundleIconName)" ] || fail "no app icon"

# The document type's contract. AppInfoPlistTests reads typed values (an array of dictionaries, a Bool), and PlistBuddy
# prints a string "false", a number or a dictionary with the key 0 the same way as the right type, so the types are
# checked with plutil, which names them. Its key paths are separated by dots, and an array index is a number.
plist_type() { plutil -type "$1" "$PLIST" 2>/dev/null; }
plist_value() { plutil -extract "$1" raw -o - "$PLIST" 2>/dev/null; }
DOCUMENT_TYPES="CFBundleDocumentTypes"
DOCUMENT_TYPE="$DOCUMENT_TYPES.0"
CONTENT_TYPES="$DOCUMENT_TYPE.LSItemContentTypes"
plist_type "$DOCUMENT_TYPES" >/dev/null || fail "the app declares no document type"
[ "$(plist_type "$DOCUMENT_TYPES")" = "array" ] || fail "$DOCUMENT_TYPES is not an array"
plist_type "$DOCUMENT_TYPE" >/dev/null || fail "the app declares no document type"
if plist_type "$DOCUMENT_TYPES.1" >/dev/null; then fail "the app declares more than one document type"; fi
[ "$(plist_type "$DOCUMENT_TYPE")" = "dictionary" ] || fail "the document type is not a dictionary"
[ "$(plist_type "$CONTENT_TYPES")" = "array" ] || fail "the document type's content types are not an array"
[ "$(plist_type "$CONTENT_TYPES.0")" = "string" ] && [ "$(plist_value "$CONTENT_TYPES.0")" = "com.adobe.pdf" ] \
  && ! plist_type "$CONTENT_TYPES.1" >/dev/null || fail "the document type is not PDF only"
[ "$(plist_value "$DOCUMENT_TYPE.CFBundleTypeRole")" = "Viewer" ] || fail "the document type's role is not Viewer"
[ "$(plist_value "$DOCUMENT_TYPE.LSHandlerRank")" = "Alternate" ] || fail "the document type's rank is not Alternate"
plist_type LSSupportsOpeningDocumentsInPlace >/dev/null || fail "LSSupportsOpeningDocumentsInPlace is missing"
[ "$(plist_type LSSupportsOpeningDocumentsInPlace)" = "bool" ] || fail "LSSupportsOpeningDocumentsInPlace is not a boolean"
in_place="$(plist_value LSSupportsOpeningDocumentsInPlace)"
[ "$in_place" = "false" ] || fail "LSSupportsOpeningDocumentsInPlace is $in_place, not false"
for declaration in UTExportedTypeDeclarations UTImportedTypeDeclarations; do
  if read_key "$declaration" >/dev/null; then fail "the app declares $declaration"; fi
done

# The oldest iOS release the archive runs on. It is compared as numbers, so that 26.10 is later than 26.5.
# release_at_least <release> <minimum>: both are one to three numbers separated by dots.
release_at_least() {
  local IFS=.
  local -a release=($1) minimum=($2)
  local part
  for part in 0 1 2; do
    local have=$((10#${release[part]:-0})) want=$((10#${minimum[part]:-0}))
    [ "$have" -gt "$want" ] && return 0
    [ "$have" -lt "$want" ] && return 1
  done
  return 0
}
plist_type MinimumOSVersion >/dev/null || fail "MinimumOSVersion is missing"
[ "$(plist_type MinimumOSVersion)" = "string" ] || fail "MinimumOSVersion is not a string"
minimum_os="$(plist_value MinimumOSVersion)"
[[ "$minimum_os" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]] || fail "MinimumOSVersion is not a release: $minimum_os"
release_at_least "$minimum_os" "$MINIMUM_OS_VERSION" || fail "MinimumOSVersion is $minimum_os, below $MINIMUM_OS_VERSION"

echo "$(read_key CFBundleDisplayName) $(read_key CFBundleShortVersionString) ($(read_key CFBundleVersion)), $(read_key CFBundleIdentifier): archive checks passed"
