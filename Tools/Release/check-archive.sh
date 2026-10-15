#!/usr/bin/env bash
# Checks an archive before it is uploaded: the bundle identifier, the display name, the version and build, the privacy
# manifest, the encryption declaration, the app icon, and that no document type is declared. Fails on the first thing
# that is wrong.
#
#   Tools/Release/check-archive.sh <path to PrestoCV.xcarchive>
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
if read_key CFBundleDocumentTypes >/dev/null; then fail "the app declares document types"; fi
echo "$(read_key CFBundleDisplayName) $(read_key CFBundleShortVersionString) ($(read_key CFBundleVersion)), $(read_key CFBundleIdentifier): archive checks passed"
