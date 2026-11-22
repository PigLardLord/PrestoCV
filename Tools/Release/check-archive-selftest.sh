#!/usr/bin/env bash
# Self-test of check-archive.sh. It builds minimal fake archives (an Info.plist, the privacy manifest) and runs the check
# on each. One archive passes: PDF as the only document type, a viewer of alternate rank, never opened in place. Each of
# the others breaks one rule of the document type, of the minimum iOS release or of the privacy manifest, and must fail
# with its own message. The archive of a case carries a copy of the source manifest PrestoCV/PrivacyInfo.xcprivacy unless
# the case changes it. Runs on macOS, where check-archive.sh reads the plists with PlistBuddy and plutil.
#
#   Tools/Release/check-archive-selftest.sh
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
CHECK="$HERE/check-archive.sh"
[ -x /usr/libexec/PlistBuddy ] || { echo "check-archive-selftest: needs macOS, for PlistBuddy" >&2; exit 1; }
SOURCE_MANIFEST="$HERE/../../PrestoCV/PrivacyInfo.xcprivacy"
[ -f "$SOURCE_MANIFEST" ] || { echo "check-archive-selftest: no $SOURCE_MANIFEST" >&2; exit 1; }
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
pass=0; fail=0; count=0

# The minimum iOS release an archive has unless a check says otherwise (the oldest release the app supports, #180).
MIN_OS='<key>MinimumOSVersion</key><string>26.5</string>'

# The keys every archive has, whatever it declares about documents.
BASE='<key>CFBundleIdentifier</key><string>com.PigLardLord.prestocv</string>
<key>CFBundleDisplayName</key><string>PrestoCV</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>ITSAppUsesNonExemptEncryption</key><false/>
<key>CFBundleIcons</key><dict><key>CFBundlePrimaryIcon</key><dict><key>CFBundleIconName</key><string>AppIcon</string></dict></dict>'

# document_type_with <role> <rank> <the value of LSItemContentTypes>
document_type_with() {
  printf '<dict><key>CFBundleTypeName</key><string>PDF</string><key>CFBundleTypeRole</key><string>%s</string>' "$1"
  printf '<key>LSHandlerRank</key><string>%s</string><key>LSItemContentTypes</key>%s</dict>' "$2" "$3"
}
# document_type <role> <rank> <content type>...
document_type() {
  local role="$1" rank="$2" types=""; shift 2
  for type in "$@"; do types+="<string>$type</string>"; done
  document_type_with "$role" "$rank" "<array>$types</array>"
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
  cp "${MANIFEST_FILE-$SOURCE_MANIFEST}" "$app/PrivacyInfo.xcprivacy"
  {
    echo '<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict>'
    echo "$BASE"
    echo "${OS_KEYS-$MIN_OS}"
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

# check_os <name> <message the check must fail with, or "" when it must pass> <the plist keys for the minimum iOS release,
# or "" for none>
check_os() { local name="$1" message="$2" keys="$3"; OS_KEYS="$keys" check "$name" "$message" "$VALID_TYPES" "$COPIED"; }
os_release() { printf '<key>MinimumOSVersion</key><string>%s</string>' "$1"; }

for release in 26.5 26.5.0 26.5.1 26.6 26.10 27 27.0 27.0.1 100.0; do
  check_os "minimum iOS $release" "" "$(os_release "$release")"
done
for release in 26 26.0 26.4 26.4.9 26.04 18.0 17.6.1 1.0 0; do
  check_os "minimum iOS $release" "MinimumOSVersion is $release, below 26.5" "$(os_release "$release")"
done
check_os "no minimum iOS" "MinimumOSVersion is missing" ""
for release in abc 26.x 26. .5 26..5 26.5.0.1 v26.5 "26.5 " ""; do
  check_os "minimum iOS \"$release\" is no release" "MinimumOSVersion is not a release: $release" "$(os_release "$release")"
done
check_os "minimum iOS as a real" "MinimumOSVersion is not a string" "<key>MinimumOSVersion</key><real>26.5</real>"
check_os "minimum iOS as an integer" "MinimumOSVersion is not a string" "<key>MinimumOSVersion</key><integer>27</integer>"
check_os "minimum iOS as a dictionary" "MinimumOSVersion is not a string" "<key>MinimumOSVersion</key><dict/>"

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

# A value of the wrong plist type reads the same as the right one in text, and the app reads it as nothing at all.
check "document types as a dictionary with the key 0" "CFBundleDocumentTypes is not an array" \
  "<key>CFBundleDocumentTypes</key><dict><key>0</key>$PDF</dict>" "$COPIED"
check "a document type that is not a dictionary" "the document type is not a dictionary" \
  "$(document_types "<string>com.adobe.pdf</string>")" "$COPIED"
check "content types as a dictionary with the key 0" "the document type's content types are not an array" \
  "$(document_types "$(document_type_with Viewer Alternate "<dict><key>0</key><string>com.adobe.pdf</string></dict>")")" "$COPIED"
check "opened in place" "LSSupportsOpeningDocumentsInPlace is true, not false" "$VALID_TYPES" "$(in_place true)"
check "in place as the string false" "LSSupportsOpeningDocumentsInPlace is not a boolean" "$VALID_TYPES" \
  "<key>LSSupportsOpeningDocumentsInPlace</key><string>false</string>"
check "in place as the number 0" "LSSupportsOpeningDocumentsInPlace is not a boolean" "$VALID_TYPES" \
  "<key>LSSupportsOpeningDocumentsInPlace</key><integer>0</integer>"
check "no in-place key" "LSSupportsOpeningDocumentsInPlace is missing" "$VALID_TYPES"

for key in UTExportedTypeDeclarations UTImportedTypeDeclarations; do
  check "$key declared" "the app declares $key" "$VALID_TYPES" "$COPIED" "<key>$key</key><array/>"
done

# The privacy manifest of the archive. check_manifest <name> <message, or "" when it must pass> <file>: the archive carries
# that file. manifest_variant <name> <message> <plutil arguments>...: it carries the source manifest changed by plutil.
check_manifest() {
  MANIFEST_FILE="$3" check "$1" "$2" "$VALID_TYPES" "$COPIED"
}
manifest_variant() {
  local name="$1" message="$2"; shift 2
  local file="$WORK/manifest-$((count + 1)).xcprivacy"
  cp "$SOURCE_MANIFEST" "$file"
  plutil "$@" "$file" || { fail=$((fail+1)); echo "FAIL $name (plutil $* failed)"; return; }
  check_manifest "$name" "$message" "$file"
}
NOT_PLIST="the privacy manifest is not a valid property list"
NOT_FALSE="NSPrivacyTracking is not the boolean false"
HAS_DOMAINS="the privacy manifest lists tracking domains"
HAS_DATA="the privacy manifest declares collected data types"
DIFFERS="the privacy manifest differs from the source manifest PrestoCV/PrivacyInfo.xcprivacy"

check_manifest "a manifest that is the source" "" "$SOURCE_MANIFEST"
manifest_variant "the source as a binary property list" "" -convert binary1
: > "$WORK/empty.xcprivacy"
check_manifest "an empty manifest" "$NOT_PLIST" "$WORK/empty.xcprivacy"
echo "not a property list" > "$WORK/text.xcprivacy"
check_manifest "a manifest of plain text" "$NOT_PLIST" "$WORK/text.xcprivacy"
head -c 120 "$SOURCE_MANIFEST" > "$WORK/cut.xcprivacy"
check_manifest "a manifest cut short" "$NOT_PLIST" "$WORK/cut.xcprivacy"

manifest_variant "tracking true" "$NOT_FALSE" -replace NSPrivacyTracking -bool YES
manifest_variant "tracking as the string false" "$NOT_FALSE" -replace NSPrivacyTracking -string false
manifest_variant "tracking as the number 0" "$NOT_FALSE" -replace NSPrivacyTracking -integer 0
manifest_variant "no tracking key" "$NOT_FALSE" -remove NSPrivacyTracking
manifest_variant "a tracking domain" "$HAS_DOMAINS" -replace NSPrivacyTrackingDomains -json '["tracker.example"]'
manifest_variant "tracking domains as a string" "$HAS_DOMAINS" -replace NSPrivacyTrackingDomains -string tracker.example
manifest_variant "a collected data type" "$HAS_DATA" -replace NSPrivacyCollectedDataTypes -json '[{"NSPrivacyCollectedDataType":"NSPrivacyCollectedDataTypeEmailAddress"}]'
manifest_variant "collected data types as a boolean" "$HAS_DATA" -replace NSPrivacyCollectedDataTypes -bool NO

manifest_variant "another required-reason category" "$DIFFERS" -replace NSPrivacyAccessedAPITypes -json '[{"NSPrivacyAccessedAPIType":"NSPrivacyAccessedAPICategoryDiskSpace","NSPrivacyAccessedAPITypeReasons":["E174.1"]}]'
manifest_variant "no required-reason categories" "$DIFFERS" -replace NSPrivacyAccessedAPITypes -json '[]'
manifest_variant "a key of its own" "$DIFFERS" -insert NSPrivacyExtra -bool YES
manifest_variant "no tracking domains key" "$DIFFERS" -remove NSPrivacyTrackingDomains
manifest_variant "no collected data types key" "$DIFFERS" -remove NSPrivacyCollectedDataTypes

echo "$pass passed, $fail failed"
[ "$fail" = 0 ]
