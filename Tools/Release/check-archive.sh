#!/usr/bin/env bash
# Checks an archive before it is uploaded: the bundle identifier, the display name, the version and build, the privacy
# manifest, the encryption declaration, the app icon, and the document type that "Open in PrestoCV" needs. That type is
# PDF only, with role Viewer and rank Alternate, and the app never opens it in place; the app declares no type of its own
# (no exported or imported type declaration). PrestoCVTests/App/AppInfoPlistTests.swift requires the same of the source
# Info.plist, so change both together. Fails on the first thing that is wrong.
#
#   Tools/Release/check-archive.sh <path to PrestoCV.xcarchive>
#
# Tools/Release/check-archive-selftest.sh tests this check on fake archives.
set -euo pipefail
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

DOCUMENT_TYPE="CFBundleDocumentTypes:0"
read_key "$DOCUMENT_TYPE" >/dev/null || fail "the app declares no document type"
if read_key "CFBundleDocumentTypes:1" >/dev/null; then fail "the app declares more than one document type"; fi
[ "$(read_key "$DOCUMENT_TYPE:LSItemContentTypes:0")" = "com.adobe.pdf" ] && ! read_key "$DOCUMENT_TYPE:LSItemContentTypes:1" >/dev/null \
  || fail "the document type is not PDF only"
[ "$(read_key "$DOCUMENT_TYPE:CFBundleTypeRole")" = "Viewer" ] || fail "the document type's role is not Viewer"
[ "$(read_key "$DOCUMENT_TYPE:LSHandlerRank")" = "Alternate" ] || fail "the document type's rank is not Alternate"
in_place="$(read_key LSSupportsOpeningDocumentsInPlace)" || fail "LSSupportsOpeningDocumentsInPlace is missing"
[ "$in_place" = "false" ] || fail "LSSupportsOpeningDocumentsInPlace is $in_place, not false"
for declaration in UTExportedTypeDeclarations UTImportedTypeDeclarations; do
  if read_key "$declaration" >/dev/null; then fail "the app declares $declaration"; fi
done

echo "$(read_key CFBundleDisplayName) $(read_key CFBundleShortVersionString) ($(read_key CFBundleVersion)), $(read_key CFBundleIdentifier): archive checks passed"
