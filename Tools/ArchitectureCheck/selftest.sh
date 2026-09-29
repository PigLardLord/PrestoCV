#!/usr/bin/env bash
# Self-test of the architecture checker: one case per known evasion, false positive or policy rule.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# The same build directory check.sh uses (ARCHITECTURE_CHECK_SCRATCH), so CI can keep it outside the checkout.
CHECK="${ARCHITECTURE_CHECK_SCRATCH:-$HERE/.build}/release/ArchitectureCheck"
pass=0; fail=0; ROOTS=()
trap 'rm -rf "${ROOTS[@]}"' EXIT

setup() {
  ROOT="$(mktemp -d)"; ROOTS+=("$ROOT"); mkdir -p "$ROOT/Sources/Pure" "$ROOT/Sources/Other" "$ROOT/adr"
  echo 'public struct O {}' > "$ROOT/Sources/Other/O.swift"
  echo '# ADR' > "$ROOT/adr/0011-typed-html-builder.md"
  cat > "$ROOT/Package.swift" <<'P'
// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "F", targets: [.target(name: "Other"), .target(name: "Pure")])
P
  cat > "$ROOT/rules.json" <<'J'
{"rules":{"R1":["exportedImport"],"R2":["wallClock","randomIdentity","ambientEnvironment","localization","printing"],
  "R4":["singleton","infrastructureConstruction"],"R7":["swallowedError"],"R9":["escapeHatch"],"R11":["platformCondition"],
  "R14":["testDouble"],"R9m":["swift5Mode","unsafeFlags"]},
 "infrastructureTypes":["FileStore"],
 "targets":[{"name":"Pure","path":"Sources/Pure","allowedImports":["Foundation"],"rules":["R1","R2","R4","R7","R9","R11","R14"]},
            {"name":"Other","path":"Sources/Other","allowedImports":["Foundation"],"rules":[]},
            {"name":"Manifest","path":"Package.swift","kind":"manifest","allowedImports":["PackageDescription"],"rules":["R9m"]}]}
J
  echo '[]' > "$ROOT/baseline.json"
}
src() { printf '%s\n' "$1" > "$ROOT/Sources/Pure/P.swift"; }
run() { "$CHECK" "$ROOT" --rules "$ROOT/rules.json" --baseline "$ROOT/baseline.json" --adr-dir "$ROOT/adr" "$@" > "$ROOT/out.txt" 2>&1; echo $?; }
expect() {
  local name="$1" want="$2" pat="$3"; shift 3
  local got; got=$(run "$@")
  if [[ "$got" == "$want" ]] && { [[ -z "$pat" ]] || grep -qE -- "$pat" "$ROOT/out.txt"; }; then pass=$((pass+1)); echo "ok   $name"
  else fail=$((fail+1)); echo "FAIL $name (exit $got, want $want)"; sed 's/^/     /' "$ROOT/out.txt"; fi
}
flag() { setup; src "$2"; expect "$1" 1 "$3"; }
clean() { setup; src "$2"; expect "$1" 0 ""; }

# --- every valid import form is seen
for form in 'public import Other' '/* c */ import Other' $'import\n    Other' 'import Foundation; import Other' \
            '@preconcurrency import Other' 'package import struct Other.O' $'#if canImport(Other)\nimport Other\n#endif' \
            'import `Other`' '@_spi(X)import Other' 'internal import Other'; do
  flag "import form: ${form//$'\n'/⏎}" "$form" "R1 import"
done
flag "@_exported import is banned even when allowed" $'@_exported import Foundation' "exportedImport"
# --- a module qualifier hides nothing (final gate of #66)
flag "qualified: Swift.fatalError" 'func f() { Swift.fatalError("x") }' "escapeHatch"
flag "qualified: Swift.precondition" 'func f() { Swift.precondition(true) }' "escapeHatch"
flag "qualified: Foundation.Date()" 'let d = Foundation.Date()' "wallClock"
flag "qualified: Foundation.UUID()" 'let u = Foundation.UUID()' "randomIdentity"
flag "qualified: Foundation.Date.now" 'let d = Foundation.Date.now' "wallClock"
flag "qualified: Foundation.Locale.current" 'let l = Foundation.Locale.current' "ambientEnvironment"
flag "qualified: Swift.print" 'func f() { Swift.print("x") }' "printing"
flag "qualified: Foundation.NSLocalizedString" 'let k = Foundation.NSLocalizedString("k", comment: "")' "localization"
flag "qualified: Dispatch.DispatchSemaphore(value:)" 'let s = Dispatch.DispatchSemaphore(value: 0)' "escapeHatch"
flag "qualified type: Foundation.ProcessInfo" 'let p: Foundation.ProcessInfo? = nil' "ambientEnvironment"
flag "qualified type: Dispatch.DispatchSemaphore" 'let s: Dispatch.DispatchSemaphore? = nil' "escapeHatch"
clean "not a clock: a member named now on another value" 'let t = schedule.slot.now'
clean "a qualified harmless type" 'let t = Foundation.TimeInterval(1)'
# --- comments, strings and regex literals neither hide nor invent code
for form in '// import Other' '/* import Other */' '/* /* nested */ import Other */' 'let s = "import Other"' \
            $'let s = """\nimport Other\n"""' 'let s = #"import Other"#' '/* Date() */ let x = 1' 'let s = "Date()"'; do
  clean "not code: ${form//$'\n'/⏎}" "$form"
done
flag "regex literal with a quote does not hide what follows" $'let r = /"/\nlet d = Date()' "wallClock"
flag "extended regex literal with */ does not hide an import" $'let r = #/x/*/#\nimport Other' "R1 import"
flag "regex literal with // does not hide the rest of the line" 'let r = #/a//b/#; let d = Date()' "wallClock"
flag "Date() after a string containing //" 'let s = " // harmless"; let d = Date()' "wallClock"
flag "Date() inside an interpolation" 'let s = "now: \(Date())"' "wallClock"
flag "Date() inside a raw interpolation" 'let s = #"raw \#(Date()) raw"#' "wallClock"
flag "nested interpolation" 'let s = "a \("nested \(Bundle.main)") b"' "ambientEnvironment"
# --- R2 variants
for form in 'let d = Date.now' 'func f() -> Date { .now }' 'let u = UUID.init()' 'let u = UUID()' 'let p = ProcessInfo.processInfo' \
            'let z = TimeZone.current' 'let n = NotificationCenter.default' 'let l = Locale.autoupdatingCurrent' 'let b = Bundle(path: "/")' \
            'let s = String(localized: "k")' 'let r: LocalizedStringResource = "k"' 'print("x")'; do
  flag "R2: $form" "$form" "R2"
done
clean "Bundle.module reads the package's own resources" 'import Foundation
let u = Bundle.module.url(forResource: "x", withExtension: "json")'
# --- R9 escape hatches, R7 swallowed errors, R4, R11, R14
for form in 'final class A: @unchecked Swift.Sendable {}' 'final class A: @unchecked  Sendable {}' 'func f() { fatalError ("x") }' \
            'let x: Int? = 1; let y = x!' 'func f() { precondition(true) }' 'func f() { preconditionFailure() }' 'let x = try! g()' \
            'let x = 1 as! Int' 'nonisolated(unsafe) var g = 0' 'func f() { MainActor.assumeIsolated { } }' 'let s = DispatchSemaphore(value: 0)'; do
  flag "R9: $form" "$form" "R9 escapeHatch"
done
flag "R7: try?" 'let x = try? g()' "R7 swallowedError"
flag "R7: empty catch" 'func f() { do { try g() } catch {} }' "R7 swallowedError"
flag "R4: singleton" 'final class S { static let shared = S() }' "R4 singleton"
flag "R4: infrastructure built outside composition" 'let s = FileStore()' "R4 infrastructureConstruction"
for form in $'#if !os(Linux)\nlet a = 1\n#endif' $'#if true\nlet a = 1\n#elseif os(iOS)\nlet a = 2\n#endif' \
            $'#if targetEnvironment(simulator)\nlet a = 1\n#endif' 'func f() { if #available(iOS 26, *) { } }' '@available(iOS 26, *) func f() {}'; do
  flag "R11: ${form//$'\n'/⏎}" "$form" "R11 platformCondition"
done
flag "R14: test double declared in production" 'struct MockExportRepository {}' "R14 testDouble"
flag "R14: test double referenced in production" 'let r = TestPDFRenderer.self' "R14 testDouble"
# --- R5: import access (the domain must not leak through a public API)
for form in 'import Foundation' 'public import Foundation' 'package import Foundation' '@preconcurrency public import Foundation'; do
  setup; python3 - "$ROOT/rules.json" <<'PY'
import json,sys; p=sys.argv[1]; r=json.load(open(p)); r["targets"][0]["requiredImportAccess"]={"Foundation":"internal"}; json.dump(r,open(p,"w"))
PY
  src "$form"; expect "R5: '$form' is refused where internal access is required" 1 "importAccess"
done
for form in 'internal import Foundation' 'private import Foundation' 'fileprivate import Foundation'; do
  setup; python3 - "$ROOT/rules.json" <<'PY'
import json,sys; p=sys.argv[1]; r=json.load(open(p)); r["targets"][0]["requiredImportAccess"]={"Foundation":"internal"}; json.dump(r,open(p,"w"))
PY
  src "$form"; expect "R5: '$form' is accepted" 0 ""
done
# --- inputs that cannot be read are problems, never a silent pass (#67)
setup; src 'let x = 1'; expect "a missing modules file fails" 1 "cannot read" --modules "$ROOT/missing.md"
setup; src 'let x = 1'; rm -rf "$ROOT/adr"; expect "a missing ADR directory fails" 1 "cannot read the ADR directory"
# --- manifests
setup; src 'let x = 1'; printf '%s\n' '// swift-tools-version: 6.0' 'import PackageDescription' \
  'let package = Package(name: "F", targets: [.target(name: "Pure", swiftSettings: [.swiftLanguageMode(.v5)]), .target(name: "Other")])' > "$ROOT/Package.swift"
expect "manifest: Swift 5 language mode" 1 "swift5Mode"
# Swift 5 mode is exempt only inside the declaration of a legacy target (ADR 0012), not for the whole manifest.
legacy_setup() {
  setup; src 'let x = 1'; mkdir -p "$ROOT/Sources/Old"; echo 'let old = 1' > "$ROOT/Sources/Old/Old.swift"
  python3 - "$ROOT/rules.json" <<'PYJ'
import json, sys
p = sys.argv[1]; r = json.load(open(p))
r["targets"].append({"name": "Old", "path": "Sources/Old", "kind": "legacy", "allowedImports": [], "rules": []})
json.dump(r, open(p, "w"))
PYJ
}
legacy_setup; printf '%s\n' '// swift-tools-version: 6.0' 'import PackageDescription' \
  'var targets: [Target] = [.target(name: "Pure"), .target(name: "Other")]' \
  '#if !os(Linux)' 'targets.append(.target(name: "Old", swiftSettings: [.swiftLanguageMode(.v5)]))' '#endif' \
  'let package = Package(name: "F", targets: targets)' > "$ROOT/Package.swift"
expect "manifest: Swift 5 mode on a legacy target is exempt" 0 ""
legacy_setup; printf '%s\n' '// swift-tools-version: 6.0' 'import PackageDescription' \
  'let package = Package(name: "F", targets: [.target(name: "Old", swiftSettings: [.swiftLanguageMode(.v5)]), .target(name: "Pure", swiftSettings: [.swiftLanguageMode(.v5)]), .target(name: "Other")])' > "$ROOT/Package.swift"
expect "manifest: Swift 5 mode on a new target next to a legacy one fails" 1 "Package.swift:3: R9m swift5Mode"
legacy_setup; printf '%s\n' '// swift-tools-version: 6.0' 'import PackageDescription' \
  'let package = Package(name: "F", targets: [.target(name: "Old"), .target(name: "Pure"), .target(name: "Other")], swiftLanguageModes: [.v5])' > "$ROOT/Package.swift"
expect "manifest: a package-wide Swift 5 mode fails even with legacy targets" 1 "swift5Mode"
# A legacy name exempts only its own package's declaration (review round 5).
two_packages() {
  setup; src 'let x = 1'; rm "$ROOT/Package.swift"
  mkdir -p "$ROOT/A/Sources/Old" "$ROOT/B/Sources/Old"
  echo 'let old = 1' > "$ROOT/A/Sources/Old/Old.swift"; echo 'let new = 1' > "$ROOT/B/Sources/Old/New.swift"
  printf '%s\n' '// swift-tools-version: 6.0' 'import PackageDescription' \
    'let package = Package(name: "A", targets: [.target(name: "Old", swiftSettings: [.swiftLanguageMode(.v5)])])' > "$ROOT/A/Package.swift"
  printf '%s\n' '// swift-tools-version: 6.0' 'import PackageDescription' \
    'let package = Package(name: "B", targets: [.target(name: "Old", swiftSettings: [.swiftLanguageMode(.v5)])])' > "$ROOT/B/Package.swift"
  python3 - "$ROOT/rules.json" "$1" <<'PYJ'
import json, sys
p, bname = sys.argv[1], sys.argv[2]; r = json.load(open(p))
r["targets"] = [t for t in r["targets"] if t["name"] != "Manifest"] + [
  {"name": "Old", "path": "A/Sources/Old", "kind": "legacy", "allowedImports": [], "rules": []},
  {"name": bname, "path": "B/Sources/Old", "allowedImports": [], "rules": []},
  {"name": "AManifest", "path": "A/Package.swift", "kind": "manifest", "allowedImports": ["PackageDescription"], "rules": ["R9m"]},
  {"name": "BManifest", "path": "B/Package.swift", "kind": "manifest", "allowedImports": ["PackageDescription"], "rules": ["R9m"]}]
json.dump(r, open(p, "w"))
PYJ
}
two_packages "BOld"; expect "manifest: a legacy name does not exempt the same name in another package" 1 "B/Package.swift:3: R9m swift5Mode"
two_packages "Old"; expect "rules: a target name used twice is a problem" 1 "target name Old appears 2 times"
# A root manifest does not own the legacy targets of a nested package (review round 6).
setup; src 'let x = 1'; mkdir -p "$ROOT/N/Sources/Old" "$ROOT/Sources/Old"
echo 'let old = 1' > "$ROOT/N/Sources/Old/Old.swift"; echo 'let mine = 1' > "$ROOT/Sources/Old/Mine.swift"
printf '%s\n' '// swift-tools-version: 6.0' 'import PackageDescription' \
  'let package = Package(name: "F", targets: [.target(name: "Pure"), .target(name: "Other"), .target(name: "Old", swiftSettings: [.swiftLanguageMode(.v5)])])' > "$ROOT/Package.swift"
printf '%s\n' '// swift-tools-version: 6.0' 'import PackageDescription' \
  'let package = Package(name: "N", targets: [.target(name: "Old", swiftSettings: [.swiftLanguageMode(.v5)])])' > "$ROOT/N/Package.swift"
python3 - "$ROOT/rules.json" <<'PYJ'
import json, sys
p = sys.argv[1]; r = json.load(open(p))
r["targets"] += [{"name": "Old", "path": "N/Sources/Old", "kind": "legacy", "allowedImports": [], "rules": []},
  {"name": "RootOld", "path": "Sources/Old", "allowedImports": [], "rules": []},
  {"name": "NManifest", "path": "N/Package.swift", "kind": "manifest", "allowedImports": ["PackageDescription"], "rules": ["R9m"]}]
json.dump(r, open(p, "w"))
PYJ
expect "manifest: a root manifest cannot exempt a nested package's legacy name" 1 "error: new violation Package.swift:3: R9m swift5Mode"
if grep -q "N/Package.swift" "$ROOT/out.txt"; then fail=$((fail+1)); echo "FAIL nested package's own legacy declaration was flagged"; else pass=$((pass+1)); echo "ok   the nested package's own legacy declaration stays exempt"; fi
setup; src 'let x = 1'; printf '%s\n' '// swift-tools-version: 6.0' 'import PackageDescription' \
  'let package = Package(name: "F", targets: [.target(name: "Pure", swiftSettings: [.unsafeFlags(["-Onone"])]), .target(name: "Other")])' > "$ROOT/Package.swift"
expect "manifest: unsafeFlags" 1 "unsafeFlags"
# Every spelling of a language mode below 6 (final gate of #66).
manifest_case() {   # $1 = name, $2 = expected exit, $3 = pattern, $4... = manifest lines; the root rules have no legacy targets
  local name="$1" want="$2" pat="$3"; shift 3
  setup; src 'let x = 1'; printf '%s\n' "$@" > "$ROOT/Package.swift"; expect "$name" "$want" "$pat"
}
manifest_case "manifest: .swiftLanguageMode(.version(\"5\")) fails" 1 "swift5Mode" '// swift-tools-version: 6.0' 'import PackageDescription' \
  'let package = Package(name: "F", targets: [.target(name: "Pure", swiftSettings: [.swiftLanguageMode(.version("5"))]), .target(name: "Other")])'
manifest_case "manifest: swiftLanguageModes: [.version(\"5\")] fails" 1 "swift5Mode" '// swift-tools-version: 6.0' 'import PackageDescription' \
  'let package = Package(name: "F", targets: [.target(name: "Pure"), .target(name: "Other")], swiftLanguageModes: [.version("5")])'
manifest_case "manifest: .version(\"4.2\") fails" 1 "swift5Mode" '// swift-tools-version: 6.0' 'import PackageDescription' \
  'let package = Package(name: "F", targets: [.target(name: "Pure", swiftSettings: [.swiftLanguageMode(.version("4.2"))]), .target(name: "Other")])'
manifest_case "manifest: .version(\"6\") is fine" 0 "" '// swift-tools-version: 6.0' 'import PackageDescription' \
  'let package = Package(name: "F", targets: [.target(name: "Pure", swiftSettings: [.swiftLanguageMode(.version("6"))]), .target(name: "Other")])'
manifest_case "manifest: tools version 5.10 with new targets fails" 1 "swift-tools-version 5 builds" '// swift-tools-version: 5.10' 'import PackageDescription' \
  'let package = Package(name: "F", targets: [.target(name: "Pure"), .target(name: "Other")])'
legacy_only() {
  setup; src 'let x = 1'; mkdir -p "$ROOT/Sources/Old"; echo 'let old = 1' > "$ROOT/Sources/Old/Old.swift"
  python3 - "$ROOT/rules.json" <<'PYJ'
import json, sys
p = sys.argv[1]; r = json.load(open(p))
r["targets"] = [{"name": "Pure", "path": "Sources/Pure", "kind": "legacy", "allowedImports": [], "rules": []},
  {"name": "Other", "path": "Sources/Other", "kind": "legacy", "allowedImports": [], "rules": []},
  {"name": "Old", "path": "Sources/Old", "kind": "legacy", "allowedImports": [], "rules": []}] + [t for t in r["targets"] if t.get("kind") == "manifest"]
json.dump(r, open(p, "w"))
PYJ
}
legacy_only; printf '%s\n' '// swift-tools-version: 5.10' 'import PackageDescription' \
  'let package = Package(name: "F", targets: [.target(name: "Pure"), .target(name: "Other"), .target(name: "Old")])' > "$ROOT/Package.swift"
expect "manifest: tools version 5.10 is fine when every target is legacy" 0 ""
# The effective mode, as SwiftPM evaluates it, catches spellings the syntax cannot see.
setup; src 'let x = 1'; printf '%s\n' '// swift-tools-version: 6.0' 'import PackageDescription' 'let five = "5"' \
  'let package = Package(name: "F", targets: [.target(name: "Pure", swiftSettings: [.swiftLanguageMode(.version(five))]), .target(name: "Other")])' > "$ROOT/Package.swift"
expect "packages: an effective Swift 5 mode from a computed value fails" 1 "builds in Swift 5 mode" --packages .
setup; src 'let x = 1'; printf '%s\n' '// swift-tools-version: 6.0' 'import PackageDescription' 'let five = "5"' \
  'let package = Package(name: "F", targets: [.target(name: "Pure", swiftSettings: [.swiftLanguageMode(.version(five), .when(platforms: [.iOS])), .swiftLanguageMode(.v6, .when(platforms: [.macOS]))]), .target(name: "Other")])' > "$ROOT/Package.swift"
expect "packages: a Swift 5 mode for one platform fails even when another setting says 6" 1 "builds in Swift 5 mode" --packages .
legacy_only; printf '%s\n' '// swift-tools-version: 6.0' 'import PackageDescription' 'let five = "5"' \
  'let package = Package(name: "F", targets: [.target(name: "Pure", swiftSettings: [.swiftLanguageMode(.version(five))]), .target(name: "Other"), .target(name: "Old")])' > "$ROOT/Package.swift"
expect "packages: an effective Swift 5 mode on a legacy target of this package is fine" 0 "" --packages .
# --- baseline: occurrences, stability, monotonicity
setup; src 'func a() { fatalError("x") }'
"$CHECK" "$ROOT" --rules "$ROOT/rules.json" --baseline "$ROOT/baseline.json" --adr-dir "$ROOT/adr" --write-baseline >/dev/null
expect "baselined occurrence passes" 0 ""
src $'func a() { fatalError("x") }\nfunc b() { fatalError("x") }'; expect "a second identical occurrence is new" 1 "new violation"
src 'let k = 1';                                                  expect "a fixed occurrence leaves a stale entry" 1 "no longer occurs"
src 'func a() { fatalError("other message") }';                  expect "replacing it with a different one is new and stale" 1 "no longer occurs"
src $'\n\n// a new comment\nfunc a() {   fatalError( "x" )   } // trailing'; expect "moving, re-spacing or commenting the line does not churn" 0 ""
setup; src 'func a() { fatalError("x") }'; echo '[]' > "$ROOT/base.json"
"$CHECK" "$ROOT" --rules "$ROOT/rules.json" --baseline "$ROOT/baseline.json" --adr-dir "$ROOT/adr" --write-baseline >/dev/null
expect "adding a violation with its baseline entry fails in CI" 1 "baseline grew" --against "$ROOT/base.json"
cp "$ROOT/baseline.json" "$ROOT/base.json"; expect "an unchanged baseline passes in CI" 0 "" --against "$ROOT/base.json"
# --- exceptions need an existing ADR
setup; src 'func a() { fatalError("x") }'
python3 - "$ROOT/rules.json" <<'PY'
import json,sys; p=sys.argv[1]; r=json.load(open(p)); r["exceptions"]=[{"path":"Sources/Pure","detector":"escapeHatch","adr":"0011","reason":"test"}]; json.dump(r,open(p,"w"))
PY
expect "an exception backed by an ADR suppresses the finding" 0 ""
python3 - "$ROOT/rules.json" <<'PY'
import json,sys; p=sys.argv[1]; r=json.load(open(p)); r["exceptions"][0]["adr"]="9999"; json.dump(r,open(p,"w"))
PY
expect "an exception citing a missing ADR is an error" 1 "does not exist"
# --- inventory
setup; src 'let x = 1'; mkdir -p "$ROOT/Sources/Stray"; echo 'let s = 1' > "$ROOT/Sources/Stray/S.swift"
expect "a file outside every target is an error" 1 "unmapped file"
setup; src 'let x = 1'; ln -s "$ROOT/Sources/Other" "$ROOT/Sources/Pure/Linked"
expect "a symbolic link in the source tree is an error" 1 "symbolic link"
setup; src 'let x = 1'
python3 - "$ROOT/rules.json" <<'PY'
import json,sys; p=sys.argv[1]; r=json.load(open(p)); r["targets"].append({"name":"Twin","path":"Sources/Pure","allowedImports":[],"rules":[]}); json.dump(r,open(p,"w"))
PY
expect "two targets claiming one path is an error" 1 "claimed by"
setup; mkdir -p "$ROOT/Sources/Pure" && echo 'let x = 1' > "$ROOT/Sources/Pure/P.swift"
cp "$ROOT/baseline.json" /dev/null; rm "$ROOT/Sources/Other/O.swift"; mkdir -p "$ROOT/Sources/Stray"; echo 'x' > "$ROOT/Sources/Stray/S.swift"
"$CHECK" "$ROOT" --rules "$ROOT/rules.json" --baseline "$ROOT/baseline.json" --adr-dir "$ROOT/adr" --write-baseline > "$ROOT/out.txt" 2>&1
if [[ $? -eq 1 ]] && grep -q "refusing" "$ROOT/out.txt"; then pass=$((pass+1)); echo "ok   --write-baseline refuses while there are problems"; else fail=$((fail+1)); echo "FAIL --write-baseline refuses"; fi
# --- modules.md, both directions
setup; src 'let x = 1'
printf '| Target | Layer | Platforms | May import |\n|---|---|---|---|\n| `Pure` | domain | all | Foundation |\n| `Other` | x | all | Foundation |\n' > "$ROOT/modules.md"
expect "rules matching modules.md pass" 0 "" --modules "$ROOT/modules.md"
printf '| `Extra` | x | all | Foundation |\n' >> "$ROOT/modules.md"
expect "a documented target missing from rules.json fails" 1 "not in notYetImplemented" --modules "$ROOT/modules.md"
python3 - "$ROOT/rules.json" <<'PY'
import json,sys; p=sys.argv[1]; r=json.load(open(p)); r["notYetImplemented"]=["Extra"]; json.dump(r,open(p,"w"))
PY
expect "a documented target declared not yet implemented passes" 0 "" --modules "$ROOT/modules.md"
python3 - "$ROOT/rules.json" <<'PY'
import json,sys; p=sys.argv[1]; r=json.load(open(p)); r["targets"][0]["allowedImports"].append("Other"); json.dump(r,open(p,"w"))
PY
expect "rules looser than modules.md fail" 1 "modules.md does not" --modules "$ROOT/modules.md"
# --- declared package dependencies
setup; src 'let x = 1'
printf '%s\n' '// swift-tools-version: 6.0' 'import PackageDescription' \
  'let package = Package(name: "F", targets: [.target(name: "Other"), .target(name: "Pure", dependencies: ["Other"])])' > "$ROOT/Package.swift"
expect "a manifest dependency the rules do not allow fails" 1 "depends on" --packages .
# swift package dump-package evaluates the manifest for the host, so an Apple-only branch is visible only on macOS (ADR 0006).
setup; src 'let x = 1'; printf '%s\n' '// swift-tools-version: 6.0' 'import PackageDescription' \
  'var targets: [Target] = [.target(name: "Pure"), .target(name: "Other")]' \
  '#if !os(Linux)' 'targets[0] = .target(name: "Pure", dependencies: ["Other"])' '#endif' \
  'let package = Package(name: "F", targets: targets)' > "$ROOT/Package.swift"
if [[ "$(uname)" == Darwin ]]; then
  expect "packages: a forbidden dependency in an Apple-only manifest branch fails on macOS" 1 "depends on" --packages .
else
  expect "packages: an Apple-only manifest branch is invisible on Linux, so CI also checks packages on macOS" 0 "" --packages .
fi

echo "selftest: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
