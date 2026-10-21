#!/usr/bin/env bash
# Self-test of check-archive.sh. It builds minimal fake archives (an Info.plist, the privacy manifest) and runs the check
# on each. One archive passes: PDF as the only document type, a viewer of alternate rank, never opened in place. Each of
# the others breaks one rule of the document type and must fail with its own message. Runs on macOS, where
# check-archive.sh reads the plist with PlistBuddy.
#
#   Tools/Release/check-archive-selftest.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
CHECK="$HERE/check-archive.sh"
[ -x /usr/libexec/PlistBuddy ] || { echo "check-archive-selftest: needs macOS, for PlistBuddy" >&2; exit 1; }
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
pass=0; fail=0; count=0

# The keys every archive has, whatever it declares about documents.
BASE='<key>CFBundleIdentifier</key><string>com.PigLardLord.prestocv</string>
<key>CFBundleDisplayName</key><string>PrestoCV</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>ITSAppUsesNonExemptEncryption</key><false/>
<key>CFBundleIcons</key><dict><key>CFBundlePrimaryIcon</key><dict><key>CFBundleIconName</key><string>AppIcon</string></dict></dict>'

# document_type <role> <rank> <content type>...
document_type() {
  local role="$1" rank="$2"; shift 2
  printf '<dict><key>CFBundleTypeName</key><string>PDF</string><key>CFBundleTypeRole</key><string>%s</string>' "$role"
  printf '<key>LSHandlerRank</key><string>%s</string><key>LSItemContentTypes</key><array>' "$rank"
  printf '<string>%s</string>' "$@"
  printf '</array></dict>'
}
document_types() { printf '<key>CFBundleDocumentTypes</key><array>%s</array>' "$*"; }
in_place() { printf '<key>LSSupportsOpeningDocumentsInPlace</key><%s/>' "$1"; }

PDF="$(document_type Viewer Alternate com.adobe.pdf)"
VALID_TYPES="$(document_types "$PDF")"
COPIED="$(in_place false)"

# check <name> <message the check must fail with, or "" when it must pass> <the plist keys that differ from the base>...
check() {
  local name="$1" message="$2"; shift 2
  local archive="$WORK/$((++count)).xcarchive" app out rc want
  app="$archive/Products/Applications/PrestoCV.app"
  mkdir -p "$app"
  : > "$app/PrivacyInfo.xcprivacy"
  {
    echo '<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict>'
    echo "$BASE"
    printf '%s\n' "$@"
    echo '</dict></plist>'
  } > "$app/Info.plist"
  out="$("$CHECK" "$archive" 2>&1)"; rc=$?
  if [ -z "$message" ]; then
    if [ "$rc" = 0 ] && grep -qF "archive checks passed" <<< "$out"; then pass=$((pass+1)); echo "ok   $name"; return; fi
  elif [ "$rc" = 1 ] && grep -qxF "::error::$message" <<< "$out"; then pass=$((pass+1)); echo "ok   $name"; return; fi
  want="0"; [ -z "$message" ] || want="1 with \"$message\""
  fail=$((fail+1)); echo "FAIL $name (exit $rc, want $want)"; sed 's/^/     /' <<< "$out"
}

check "PDF only, viewer, alternate, not in place" "" "$VALID_TYPES" "$COPIED"

check "no document type" "the app declares no document type" "$COPIED"
check "an empty list of document types" "the app declares no document type" "$(document_types)" "$COPIED"
check "a second document type" "the app declares more than one document type" \
  "$(document_types "$PDF" "$PDF")" "$COPIED"
check "a second document type that is not PDF" "the app declares more than one document type" \
  "$(document_types "$PDF" "$(document_type Viewer Alternate public.plain-text)")" "$COPIED"
check "a non-PDF content type" "the document type is not PDF only" \
  "$(document_types "$(document_type Viewer Alternate public.plain-text)")" "$COPIED"
check "a content type besides PDF" "the document type is not PDF only" \
  "$(document_types "$(document_type Viewer Alternate com.adobe.pdf public.image)")" "$COPIED"
for role in Editor Shell None; do
  check "role $role" "the document type's role is not Viewer" \
    "$(document_types "$(document_type "$role" Alternate com.adobe.pdf)")" "$COPIED"
done
for rank in Default Owner None; do
  check "rank $rank" "the document type's rank is not Alternate" \
    "$(document_types "$(document_type Viewer "$rank" com.adobe.pdf)")" "$COPIED"
done

check "opened in place" "LSSupportsOpeningDocumentsInPlace is true, not false" "$VALID_TYPES" "$(in_place true)"
check "no in-place key" "LSSupportsOpeningDocumentsInPlace is missing" "$VALID_TYPES"

for key in UTExportedTypeDeclarations UTImportedTypeDeclarations; do
  check "$key declared" "the app declares $key" "$VALID_TYPES" "$COPIED" "<key>$key</key><array/>"
done

echo "$pass passed, $fail failed"
[ "$fail" = 0 ]
