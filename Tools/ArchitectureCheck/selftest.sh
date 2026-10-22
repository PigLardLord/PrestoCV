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
  "R14":["testDouble"],"R9m":["swift5Mode","unsafeFlags"],"R15":["bundleLayout"],"R16":["sourceTreePath"],
  "R5":["viewDependency","viewModelImport"],"R17":["defaultDependency"],"R18":["appleOnlyImport","bundleAccess","fullFoundation"]},
 "warningDetectors":["fullFoundation"],
 "infrastructureTypes":["FileStore"],
 "serviceSuffixes":["UseCase","Repository","Service","Container"],
 "dependencySuffixes":["UseCase","Repository","Service","Container","Store","Detector","Provider","Factory"],
 "targets":[{"name":"Pure","path":"Sources/Pure","allowedImports":["Foundation"],"rules":["R1","R2","R4","R7","R9","R11","R14"]},
            {"name":"Other","path":"Sources/Other","allowedImports":["Foundation"],"rules":[]},
            {"name":"Manifest","path":"Package.swift","kind":"manifest","allowedImports":["PackageDescription"],"rules":["R9m","R15"]}]}
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
# A copied directory lands at the root of the resource bundle under its last path component. A name the bundle's own
# structure uses fails codesign or loses the files (R15, #240); .process flattens a directory, so its name never lands there.
for res in '.copy("Resources")' '.copy("Contents")' '.copy("resources")' '.copy("Assets/_CodeSignature")' '.copy("MacOS")' \
           '.copy("Resources/")' '.copy("./Resources")' 'Resource.copy("Resources")' '.copy(#"Resources"#)' '.copy(folder)'; do
  manifest_case "manifest: resources: [$res] is refused" 1 "R15 bundleLayout" '// swift-tools-version: 6.0' 'import PackageDescription' \
    'let folder = "Headings"' "let package = Package(name: \"F\", targets: [.target(name: \"Pure\", resources: [$res]), .target(name: \"Other\")])"
done
for res in '.copy("Resources/Headings")' '.copy("../../Resources/Templates")' '.copy("Designs")' '.process("Resources")'; do
  manifest_case "manifest: resources: [$res] is fine" 0 "" '// swift-tools-version: 6.0' 'import PackageDescription' \
    "let package = Package(name: \"F\", targets: [.target(name: \"Pure\", resources: [$res]), .target(name: \"Other\")])"
done
# The detector reads the literal's value, as SwiftPM receives it: escapes decoded, multiline delimiters and line continuations removed (final gate).
for res in '.copy("\u{52}esources")' '.copy("Assets\u{2F}Resources")' '.copy(#"\#u{52}esources"#)' '.copy(#"Resources"#)'; do
  manifest_case "manifest: resources: [$res] is refused for its value" 1 "R15 bundleLayout: copies Resources/" '// swift-tools-version: 6.0' \
    'import PackageDescription' "let package = Package(name: \"F\", targets: [.target(name: \"Pure\", resources: [$res]), .target(name: \"Other\")])"
done
manifest_case "manifest: a multiline literal naming Resources is refused for its value" 1 "R15 bundleLayout: copies Resources/" \
  '// swift-tools-version: 6.0' 'import PackageDescription' 'let package = Package(name: "F", targets: [.target(name: "Pure", resources: [.copy("""' \
  '    Resources' '    """)]), .target(name: "Other")])'
manifest_case "manifest: a multiline literal naming Headings is fine" 0 "" \
  '// swift-tools-version: 6.0' 'import PackageDescription' 'let package = Package(name: "F", targets: [.target(name: "Pure", resources: [.copy("""' \
  '    Headings' '    """)]), .target(name: "Other")])'
manifest_case "manifest: a multiline literal continued over two lines into Resources is refused for its value" 1 "R15 bundleLayout: copies Resources/" \
  '// swift-tools-version: 6.0' 'import PackageDescription' 'let package = Package(name: "F", targets: [.target(name: "Pure", resources: [.copy("""' \
  '    Res\' '    ources' '    """)]), .target(name: "Other")])'
manifest_case "manifest: a multiline literal continued over two lines into Headings is fine" 0 "" \
  '// swift-tools-version: 6.0' 'import PackageDescription' 'let package = Package(name: "F", targets: [.target(name: "Pure", resources: [.copy("""' \
  '    Head\' '    ings' '    """)]), .target(name: "Other")])'
manifest_case "manifest: resources: [.copy(\"\\u{48}eadings\")] is fine" 0 "" '// swift-tools-version: 6.0' 'import PackageDescription' \
  'let package = Package(name: "F", targets: [.target(name: "Pure", resources: [.copy("\u{48}eadings")]), .target(name: "Other")])'
manifest_case "manifest: an interpolated path is refused" 1 "R15 bundleLayout: the path of a copied resource must be a string literal without interpolation" \
  '// swift-tools-version: 6.0' 'import PackageDescription' 'let name = "Headings"' \
  'let package = Package(name: "F", targets: [.target(name: "Pure", resources: [.copy("\(name)")]), .target(name: "Other")])'
manifest_case "manifest: a copied Resources in an Apple-only branch is refused on every host" 1 "Package.swift:5: R15 bundleLayout" \
  '// swift-tools-version: 6.0' 'import PackageDescription' 'var targets: [Target] = [.target(name: "Pure"), .target(name: "Other")]' \
  '#if !os(Linux)' 'targets[0] = .target(name: "Pure", resources: [.copy("Resources")])' '#endif' 'let package = Package(name: "F", targets: targets)'
legacy_setup; printf '%s\n' '// swift-tools-version: 6.0' 'import PackageDescription' \
  'let package = Package(name: "F", targets: [.target(name: "Pure"), .target(name: "Other"), .target(name: "Old", resources: [.copy("Resources")])])' > "$ROOT/Package.swift"
expect "manifest: a legacy target's copied Resources is refused too, since its bundle is signed in the same build" 1 "R15 bundleLayout"
# --- R16: a target a test plan runs reads no source tree, since the plan runs where only the built products are (#246)
plan() {   # $1 = plan path under the root, $2... = the names of its test targets
  local file="$ROOT/$1"; shift; mkdir -p "$(dirname "$file")"
  python3 - "$file" "$@" <<'PY'
import json, sys
json.dump({"testTargets": [{"target": {"containerPath": "container:F", "identifier": n, "name": n}} for n in sys.argv[2:]], "version": 1},
          open(sys.argv[1], "w"))
PY
}
with_rule() {   # $1 = target name, $2 = rule: adds the rule to the target's rules
  python3 - "$ROOT/rules.json" "$1" "$2" <<'PY'
import json, sys
p, name, rule = sys.argv[1:]; r = json.load(open(p))
next(t for t in r["targets"] if t["name"] == name)["rules"].append(rule); json.dump(r, open(p, "w"))
PY
}
on_device() { setup; with_rule Pure R16; plan TestPlans/CI.xctestplan Pure; src "$2"; expect "$1" "$3" "${4:-}"; }
for form in 'let here = URL(fileURLWithPath: #filePath)' 'let here = #file' 'let p = "at \(#filePath)"' \
            'func root(_ path: String = #filePath) -> String { path }' $'#if DEBUG\nlet here = #filePath\n#endif'; do
  on_device "R16: ${form//$'\n'/⏎} in a target a test plan runs" "$form" 1 "R16 sourceTreePath"
done
for form in 'func check(file: StaticString = #filePath, line: UInt = #line) {}' 'func check(_ file: StaticString = #file) {}' \
            'let id = #fileID' '// URL(fileURLWithPath: #filePath)' 'let s = "#filePath"'; do
  on_device "R16: '$form' reads no source tree" "$form" 0
done
# A StaticString that defaults to #filePath only reports where an assertion failed while it is forwarded, unchanged, as
# the file: argument of a call. Turned into text it is a path of the checkout (final gate of #246).
for form in 'func root(file: StaticString = #filePath) -> URL { URL(fileURLWithPath: String(describing: file)).deletingLastPathComponent() }' \
            'func root(file: StaticString = #filePath) -> String { "\(file)" }' \
            'func root(file: StaticString = #filePath) -> String { file.description }' \
            'func root(file: StaticString = #file) -> String { file.withUTF8Buffer { String(decoding: $0, as: UTF8.self) } }' \
            'func root(file path: StaticString = #filePath) -> String { "\(path)" }' \
            'func check(file: StaticString = #filePath) { let f = file; XCTFail("x", file: f) }' \
            'func check(file: StaticString = #filePath) { record(at: file) }' \
            'func check(file: StaticString = #filePath) { let t = (file: file, line: 1); _ = t }'; do
  on_device "R16: '$form' turns the location into a path" "$form" 1 "R16 sourceTreePath"
done
for form in 'func check(_ ok: Bool, file: StaticString = #filePath, line: UInt = #line) { XCTAssertTrue(ok, "x", file: file, line: line) }' \
            'func check(at file: StaticString = #filePath) { items.forEach { XCTFail("\($0)", file: file) } }' \
            'func check(file: StaticString = #filePath) { XCTFail(report.file, file: file); assertWhole(file: file) }' \
            'init(file: StaticString = #filePath) { XCTFail("x", file: file) }'; do
  on_device "R16: '$form' only forwards the location" "$form" 0
done
setup; src 'let x = 1'; plan TestPlans/CI.xctestplan Pure
expect "R16: a target a test plan runs without the rule is an error" 1 "test plan TestPlans/CI.xctestplan runs Pure without the repository, so its rules must include R16"
setup; src 'let x = 1'; plan TestPlans/CI.xctestplan Ghost
expect "R16: a test plan that runs a target rules.json does not know is an error" 1 "runs Ghost, which rules.json does not know"
setup; src 'let x = 1'; mkdir -p "$ROOT/TestPlans"; echo 'not json' > "$ROOT/TestPlans/CI.xctestplan"
expect "R16: a test plan that cannot be read is an error, never a silent pass" 1 "cannot read the test plan"
setup; src 'let x = 1'; mkdir -p "$ROOT/Prototypes/P"; echo 'let p = 1' > "$ROOT/Prototypes/P/P.swift"
python3 - "$ROOT/rules.json" <<'PY'
import json, sys
p = sys.argv[1]; r = json.load(open(p)); r["targets"].append({"name": "Proto", "path": "Prototypes", "kind": "excluded", "allowedImports": [], "rules": []})
json.dump(r, open(p, "w"))
PY
plan Prototypes/P/Old.xctestplan Ghost
expect "R16: a test plan in an excluded path is not the repository's" 0 ""
legacy_tests() {   # a legacy test target with the given rules, whose code reads the source tree, breaks R1 and R2, and is in a plan
  setup; src 'let x = 1'; mkdir -p "$ROOT/Tests/Old"
  printf '%s\n' 'import Unlisted' 'let here = #filePath' 'let d = Date()' > "$ROOT/Tests/Old/OldTests.swift"
  python3 - "$ROOT/rules.json" "$1" <<'PY'
import json, sys
p, rules = sys.argv[1], [x for x in sys.argv[2].split(",") if x]; r = json.load(open(p))
r["targets"].append({"name": "OldTests", "path": "Tests/Old", "kind": "legacy", "allowedImports": [], "rules": rules})
json.dump(r, open(p, "w"))
PY
}
legacy_tests "R16"; plan TestPlans/CI.xctestplan OldTests
expect "R16: a legacy test target a test plan runs is checked for it" 1 "Tests/Old/OldTests.swift:2: R16 sourceTreePath"
if grep -qE "R1 import|wallClock" "$ROOT/out.txt"; then fail=$((fail+1)); echo "FAIL a legacy target was checked for more than the rules listed for it"; sed 's/^/     /' "$ROOT/out.txt"
else pass=$((pass+1)); echo "ok   a legacy target is checked only for the rules listed for it, without its imports"; fi
legacy_tests ""; expect "R16: a legacy target with no rules stays exempt (ADR 0012)" 0 ""
setup; with_rule Pure R16; plan TestPlans/CI.xctestplan Pure; src 'let here = #filePath'
python3 - "$ROOT/rules.json" <<'PY'
import json, sys
p = sys.argv[1]; r = json.load(open(p))
r["exceptions"] = [{"path": "Sources/Pure/P.swift", "detector": "sourceTreePath", "adr": "0011", "reason": "writes a golden file on request"}]
json.dump(r, open(p, "w"))
PY
expect "R16: an exception backed by an ADR allows a writer that needs the checkout" 0 ""
# --- R5: a view renders and forwards intents; it holds no service and makes no view model, except in a DEBUG preview (#256)
only_rule() {   # $1 = rule: the Pure target has only this rule, and may import the UI frameworks, so a case shows this rule alone
  python3 - "$ROOT/rules.json" "$1" <<'PY'
import json, sys
p, rule = sys.argv[1:]; r = json.load(open(p)); t = next(t for t in r["targets"] if t["name"] == "Pure")
t["rules"] = [rule]; t["allowedImports"] += ["SwiftUI", "UIKit", "AppKit", "Combine", "Observation"]; json.dump(r, open(p, "w"))
PY
}
view_case() { setup; only_rule R5; src "$2"; expect "$1" "$3" "${4:-}"; }
for form in 'struct V: View { let service: ExportService; var body: some View { EmptyView() } }' \
            'struct V: View { var body: some View { Text(LiveExportService().name) } }' \
            'struct V: SwiftUI.View { let container: DependencyContainerProtocol; var body: some View { EmptyView() } }' \
            'struct V: View { let cvs: CVManagementUseCaseProtocol; var body: some View { EmptyView() } }' \
            'struct R: UIViewRepresentable { let repository: CVRepository }' \
            'struct V: Equatable & View { let store: CVRepository; var body: some View { EmptyView() } }' \
            $'struct V: View {\n    var body: some View { EmptyView() }\n}\nextension V {\n    func load() { _ = CVRepository.self }\n}'; do
  view_case "R5: a view references a service: ${form//$'\n'/⏎}" "$form" 1 "R5 viewDependency"
done
for form in 'struct V: View { @StateObject private var viewModel = ListViewModel(); var body: some View { EmptyView() } }' \
            'struct V: View { @StateObject private var viewModel: ListViewModel; init() { _viewModel = StateObject(wrappedValue: ListViewModel()) }; var body: some View { EmptyView() } }' \
            'struct V: View { @StateObject private var viewModel: ListViewModel = .init(); var body: some View { EmptyView() } }' \
            'struct V: View { var body: some View { Child(viewModel: ChildViewModel.init(title: "")) } }' \
            $'struct V: View {\n    var body: some View {\n        #if DEBUG\n        EmptyView()\n        #else\n        Child(viewModel: ChildViewModel())\n        #endif\n    }\n}'; do
  view_case "R5: a view makes a view model: ${form//$'\n'/⏎}" "$form" 1 "R5 viewDependency"
done
for form in 'struct V: View { @ObservedObject var viewModel: ListViewModel; let makeSheet: (Int) -> SheetViewModel; var body: some View { EmptyView() } }' \
            'struct V: View { let makeViewModel: () -> ListViewModel; var body: some View { Child(viewModel: makeViewModel()) } }' \
            $'struct V: View {\n    var body: some View { EmptyView() }\n}\n#if DEBUG\n#Preview { V(viewModel: ListViewModel(useCase: PreviewUseCase())) }\nstruct V_Previews: PreviewProvider { static var previews: some View { V(viewModel: ListViewModel(service: PreviewService())) } }\n#endif' \
            $'struct V: View {\n    var body: some View { EmptyView() }\n    #if DEBUG\n    static func preview() -> ListViewModel { ListViewModel(useCase: PreviewUseCase()) }\n    #endif\n}' \
            'final class ViewModelFactory { func make() -> ListViewModel { ListViewModel(service: LiveExportService()) } }' \
            'struct Row { let service: ExportService }' \
            $'struct ItemsContainer: View {\n    var body: some View { EmptyView() }\n}\nstruct V: View {\n    var body: some View { ItemsContainer() }\n}'; do
  view_case "R5: allowed: ${form//$'\n'/⏎}" "$form" 0
done
# A view's extension in another file of the target is part of the view.
setup; only_rule R5; printf '%s\n' 'struct V: View { var body: some View { EmptyView() } }' > "$ROOT/Sources/Pure/V.swift"
src $'extension V {\n    func make() -> ListViewModel { ListViewModel() }\n}'
expect "R5: an extension of a view declared in another file makes a view model" 1 "Sources/Pure/P.swift:2: R5 viewDependency"
# Contextual `.init(…)` is resolved through the type the context expects, and a qualified type name is still a view model.
for form in 'struct V: View { var body: some View { Child(viewModel: .init(title: "")) } }' \
            $'struct V: View {\n    @StateObject private var viewModel: ListViewModel\n    init() { _viewModel = StateObject(wrappedValue: .init()) }\n    var body: some View { EmptyView() }\n}' \
            $'struct V: View {\n    @StateObject private var viewModel: ListViewModel\n    init() { self._viewModel = StateObject(wrappedValue: .init(title: "")) }\n    var body: some View { EmptyView() }\n}' \
            $'struct V: View {\n    @State private var model: ListViewModel\n    init() { model = .init() }\n    var body: some View { EmptyView() }\n}' \
            'struct V: View { @StateObject private var viewModel = PrestoCVPresentation.ListViewModel(); var body: some View { EmptyView() } }' \
            'struct V: View { var body: some View { Child(viewModel: Outer.ChildViewModel.init()) } }' \
            $'struct Child: View {\n    let model: ChildViewModel\n    var body: some View { EmptyView() }\n}\nstruct V: View { var body: some View { Child(model: .init()) } }' \
            $'struct Child: View {\n    init(model: ChildViewModel) {}\n    var body: some View { EmptyView() }\n}\nstruct V: View { var body: some View { Child(model: .init()) } }' \
            $'struct V: View {\n    func make() -> ListViewModel { .init() }\n    var body: some View { EmptyView() }\n}' \
            $'struct V: View {\n    var body: some View {\n        #if DEBUG\n        EmptyView()\n        #else\n        Child(viewModel: .init())\n        #endif\n    }\n}' \
            $'struct V: View {\n    @StateObject private var viewModel: ListViewModel\n    init() {\n        #if DEBUG\n        _viewModel = StateObject(wrappedValue: ListViewModel(useCase: PreviewUseCase()))\n        #else\n        _viewModel = StateObject(wrappedValue: .init())\n        #endif\n    }\n    var body: some View { EmptyView() }\n}' \
            $'struct V: View {\n    var body: some View {\n        #if os(iOS)\n        Child(viewModel: PrestoCVPresentation.ChildViewModel())\n        #endif\n    }\n}'; do
  view_case "R5: a view makes a view model: ${form//$'\n'/⏎}" "$form" 1 "R5 viewDependency"
done
for form in 'struct V: View { var body: some View { Child(title: .init()) } }' \
            $'struct V: View {\n    @State private var title: String\n    init() { _title = State(wrappedValue: .init()) }\n    var body: some View { EmptyView() }\n}' \
            'struct V: View { var body: some View { PrestoCVPresentation.ListView(viewModel: viewModel) } }' \
            $'struct V: View {\n    var body: some View {\n        #if DEBUG\n        Child(viewModel: .init(useCase: PreviewUseCase()))\n        #endif\n    }\n}' \
            'final class ViewModelFactory { func make() -> ListViewModel { .init() }; func list() -> PrestoCVPresentation.ListViewModel { .init() } }'; do
  view_case "R5: allowed: ${form//$'\n'/⏎}" "$form" 0
done
# Overloaded initialisers are told apart by the labels of the call and of the `.init(…)`, in either declaration order;
# a local that shadows a property is not the property, unless `self.` names it; a closure's return type is read.
vm_decl=$'final class ListViewModel { init(useCase: Any) {} }'
for order in $'    init(model: ListViewModel) {}\n    init(model: String) {}' $'    init(model: String) {}\n    init(model: ListViewModel) {}'; do
  child=$"struct Child: View {\n$order\n    var body: some View { EmptyView() }\n}"
  view_case "R5: an overload of an initialiser that takes a view model: ${order//$'\n'/⏎}" \
    "$vm_decl"$'\n'"$child"$'\nstruct V: View { let injected = 0; var body: some View { Child(model: .init(useCase: injected)) } }' 1 "R5 viewDependency"
  view_case "R5: allowed: an overload of an initialiser that takes a String: ${order//$'\n'/⏎}" \
    "$vm_decl"$'\n'"$child"$'\nstruct V: View { var body: some View { Child(model: .init(repeating: "x", count: 2)) } }' 0
done
for form in $'struct V: View {\n    @State private var model: ListViewModel\n    func reset() { let model = ""; self.model = .init(); _ = model }\n    var body: some View { EmptyView() }\n}' \
            $'struct V: View {\n    func make() { var model: ListViewModel; model = .init(); _ = model }\n    var body: some View { EmptyView() }\n}' \
            $'struct V: View { let injected = 0; var body: some View { Child(factory: { () -> ListViewModel in return .init(useCase: injected) }) } }' \
            $'struct V: View { let injected = 0; var body: some View { Child(factory: { () -> ListViewModel in .init(useCase: injected) }) } }' \
            $'struct Child: View {\n    init(factory: @escaping () -> ListViewModel) {}\n    var body: some View { EmptyView() }\n}\nstruct V: View { var body: some View { Child(factory: { .init() }) } }' \
            $'struct V: View {\n    var body: some View {\n        #if DEBUG\n        EmptyView()\n        #else\n        Child(factory: { () -> ListViewModel in .init() })\n        #endif\n    }\n}'; do
  view_case "R5: a view makes a view model: ${form//$'\n'/⏎}" "$form" 1 "R5 viewDependency"
done
for form in $'struct V: View {\n    @State private var model: ListViewModel\n    func reset() { var model = ""; model = .init(); _ = model }\n    var body: some View { EmptyView() }\n}' \
            $'struct V: View {\n    @State private var model: ListViewModel\n    func reset(_ model: inout String) { model = .init() }\n    var body: some View { EmptyView() }\n}' \
            $'struct V: View {\n    @State private var model: ListViewModel\n    func reset(names: [String]) { for model in names { var copy = model; copy = .init(); _ = copy } }\n    var body: some View { EmptyView() }\n}' \
            $'struct V: View { var body: some View { Child(factory: { () -> String in .init() }) } }' \
            $'struct Child: View {\n    init(factory: @escaping () -> String) {}\n    var body: some View { EmptyView() }\n}\nstruct V: View { var body: some View { Child(factory: { .init() }) } }'; do
  view_case "R5: allowed: ${form//$'\n'/⏎}" "$form" 0
done
# A variadic parameter takes no value, one or several, before or after the argument that makes the view model.
variadic_child() { printf 'struct Child: View {\n    init(%s) {}\n    var body: some View { EmptyView() }\n}\n' "$1"; }
for pair in 'model: ListViewModel, tags: String...|Child(model: .init())' \
            'model: ListViewModel, tags: String...|Child(model: .init(), tags: "a", "b", "c")' \
            'tags: String..., model: ListViewModel|Child(tags: "a", "b", model: .init())' \
            '_ names: String..., model: ListViewModel|Child("a", "b", model: .init())' \
            'models: ListViewModel...|Child(models: .init(), .init())'; do
  view_case "R5: a view makes a view model through a variadic initialiser: ${pair#*|}" \
    "$(variadic_child "${pair%%|*}")"$'\n'"struct V: View { var body: some View { ${pair#*|} } }" 1 "R5 viewDependency"
done
for pair in 'model: String, tags: String...|Child(model: .init(), tags: "a", "b")' \
            'model: ListViewModel, tags: String...|Child(model: model, tags: .init(), .init())'; do
  view_case "R5: allowed: a variadic initialiser: ${pair#*|}" \
    "$(variadic_child "${pair%%|*}")"$'\n'"struct V: View { let model: ListViewModel; var body: some View { ${pair#*|} } }" 0
done
# The type a contextual `.init(…)` makes is found in another file of the target too.
setup; only_rule R5; printf '%s\n' 'struct Child: View { let model: ChildViewModel; var body: some View { EmptyView() } }' > "$ROOT/Sources/Pure/C.swift"
src 'struct V: View { var body: some View { Child(model: .init()) } }'
expect "R5: a contextual .init for a parameter of a view declared in another file makes a view model" 1 "Sources/Pure/P.swift:1: R5 viewDependency"
# --- R5: a view model imports no UI framework (Combine and Observation are fine)
for form in $'import SwiftUI\nfinal class ListViewModel: ObservableObject {}' $'import UIKit\nextension ListViewModel {}' \
            $'import struct SwiftUI.Color\nstruct ListViewModel {}' $'@preconcurrency import AppKit\nactor ListViewModel {}'; do
  view_case "R5: a view model's file imports a UI framework: ${form//$'\n'/⏎}" "$form" 1 "R5 viewModelImport"
done
for form in $'import Combine\nimport Observation\nimport Foundation\nfinal class ListViewModel: ObservableObject {}' \
            $'import SwiftUI\nstruct ListView: View { @ObservedObject var viewModel: ListViewModel; var body: some View { EmptyView() } }'; do
  view_case "R5: allowed: ${form//$'\n'/⏎}" "$form" 0
done
# --- R17: a default argument never makes a dependency or reads ambient state; the composition root passes them (#256)
default_case() { setup; only_rule R17; src "$2"; expect "$1" "$3" "${4:-}"; }
for form in 'init(now: @escaping () -> Date = { Date() }) {}' 'func f(date: Date = .now) {}' 'func f(date: Date = Foundation.Date()) {}' \
            'init(calendar: Calendar = .autoupdatingCurrent) {}' 'init(locale: Locale = .current) {}' 'init(zone: TimeZone = TimeZone.current) {}' \
            'init(languages: [String] = Locale.preferredLanguages) {}' 'init(languages: [String] = Bundle.main.preferredLocalizations) {}' \
            'init(locale: Locale = Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en")) {}' \
            'init(directory: URL = FileManager.default.temporaryDirectory) {}' 'init(file: URL = .applicationSupportDirectory) {}' \
            'init(file: URL = URL.documentsDirectory) {}' 'init(path: String = NSTemporaryDirectory()) {}' \
            'init(defaults: UserDefaults = .standard) {}' 'init(arguments: [String] = ProcessInfo.processInfo.arguments) {}' \
            'init(title: String = String(localized: "export.file_name")) {}' 'init(title: String = NSLocalizedString("k", comment: "")) {}' \
            'init(sleep: @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) }) {}' \
            'init(clock: any Clock<Duration> = ContinuousClock()) {}' \
            'init(service: ExportService = ExportService()) {}' 'init(service: any ExportServiceProtocol = LiveExport()) {}' \
            'init(detector: LanguageDetector = .onDevice) {}' 'init(store: (any PreferencesStore)? = .init()) {}' \
            'init(container: Container = Container.shared) {}' 'init(store: FileStore = FileStore()) {}' \
            'init(directory: @escaping () throws -> URL = DependencyContainer.defaultDirectory) {}' \
            'init(makeID: @escaping () -> UUID = { UUID() }) {}' 'init(bootstrap: @escaping () async -> Void = installTemplates) {}' \
            'init(availability: AvailabilityProvider = { .available }) {}' \
            $'#if DEBUG\nfunc current(arguments: [String] = ProcessInfo.processInfo.arguments) {}\n#endif'; do
  default_case "R17: refused: $form" "$form" 1 "R17 defaultDependency"
done
for form in 'init(id: UUID = UUID()) {}' 'init(debounce: Duration = .milliseconds(250)) {}' \
            'init(margin: Double = 43, title: String = "", items: [Int] = [], flag: Bool = Feature.isShipped) {}' \
            'init(onTap: @escaping () -> Void = {}) {}' 'init(onChange: @escaping (Int) -> Void = { _ in }) {}' \
            'func find(matcher: @escaping @Sendable (Int) -> Bool = { _ in true }) {}' 'init(limit: @escaping () -> Int? = { nil }) {}' \
            'init(modifier: ((String) -> String)? = nil) {}' 'init(service: ExportService) {}' 'init(service: (any ExportServiceProtocol)? = nil) {}' \
            'init(bundle: Bundle = .module) {}' 'init(bundle: Bundle = Bundle.module) {}' 'func f() { let now = Date(); _ = now }' 'init(style: Style = .default, side: Double = Thumbnail.side) {}' \
            'init(file: StaticString = #filePath, line: UInt = #line) {}'; do
  default_case "R17: allowed: $form" "$form" 0
done
legacy_tests "R17"; printf '%s\n' 'init(now: @escaping () -> Date = { Date() }) {}' >> "$ROOT/Tests/Old/OldTests.swift"
expect "R17: a legacy target with R17 is checked for it, and only for it" 1 "Tests/Old/OldTests.swift:4: R17 defaultDependency"
if grep -qE "R1 import|wallClock" "$ROOT/out.txt"; then fail=$((fail+1)); echo "FAIL a legacy target with R17 was checked for more"; sed 's/^/     /' "$ROOT/out.txt"
else pass=$((pass+1)); echo "ok   a legacy target with R17 is checked for nothing else"; fi
# --- R18: a pure target stays portable to Android: no Apple-only module and no bundle; an API that needs the full
# Foundation, with ICU, warns without failing (#267)
only_portable() {   # the Pure target has only R18 and may import every module a case names, so a case shows R18 alone
  python3 - "$ROOT/rules.json" <<'PY'
import json, sys
p = sys.argv[1]; r = json.load(open(p)); t = next(t for t in r["targets"] if t["name"] == "Pure")
t["rules"] = ["R18"]
t["allowedImports"] += ["SwiftUI", "UIKit", "AppKit", "Combine", "CryptoKit", "os", "OSLog", "NaturalLanguage", "FoundationModels", "PDFKit",
                        "WebKit", "Vision", "Darwin", "FoundationEssentials", "Observation", "Synchronization", "Other"]
json.dump(r, open(p, "w"))
PY
}
portable_case() { setup; only_portable; src "$2"; expect "$1" "$3" "${4:-}"; }
for form in 'import SwiftUI' 'import UIKit' 'import AppKit' 'import Combine' 'import CryptoKit' 'import os' 'import os.log' 'import OSLog' \
            'import NaturalLanguage' 'import FoundationModels' 'import PDFKit' 'import WebKit' 'import Vision' 'import Darwin' \
            'import struct CryptoKit.Insecure' '@preconcurrency import Combine' 'internal import UIKit' $'#if canImport(UIKit)\nimport UIKit\n#endif'; do
  portable_case "R18: ${form//$'\n'/⏎} in a pure target" "$form" 1 "R18 appleOnlyImport"
done
for form in 'import Foundation' 'import FoundationEssentials' 'import Observation' 'import Synchronization' 'import Other' 'let os = 1'; do
  portable_case "R18: '$form' is portable" "$form" 0
done
for form in 'let u = Bundle.module.url(forResource: "x", withExtension: "json")' 'let b = Bundle.main' 'let b = Bundle(path: "/")' \
            'init(bundle: Bundle) {}' 'func f(_ b: Bundle = .module) {}' 'let b: Foundation.Bundle? = nil' 'let u = Foundation.Bundle.module' \
            'let b = #bundle'; do
  portable_case "R18: '$form' reads a bundle" "$form" 1 "R18 bundleAccess"
done
for form in '// Bundle.module' 'let s = "Bundle.module"' 'struct DesignBundle {}' 'let b = designs.bundle'; do
  portable_case "R18: '$form' reads no bundle" "$form" 0
done
for form in 'let t = s.trimmingCharacters(in: .whitespaces)' 'let r = s.range(of: "a+", options: .regularExpression)' \
            'let x = try NSRegularExpression(pattern: "a")' 'let r: NSRange? = nil' 'let f = s.folding(options: .diacriticInsensitive, locale: nil)' \
            'let t = s.replacingOccurrences(of: "a", with: "b")' 'let o = try JSONSerialization.jsonObject(with: d)' \
            'let o = try Foundation.JSONSerialization.jsonObject(with: d)' 'let n = NSString(string: s)' 'let t = String(format: "%d", 1)' \
            'let f = DateFormatter()' 'let f = NumberFormatter()' 'let f = ISO8601DateFormatter()' 'let o = a.localizedCompare(b)' \
            'let o = a.localizedStandardCompare(b)' 'let o = a.localizedCaseInsensitiveCompare(b)'; do
  portable_case "R18: '$form' warns and passes" "$form" 0 "warning: Sources/Pure/P.swift:1: R18 fullFoundation"
done
for form in 'let t = s.split(separator: " ")' 'let r = s.firstMatch(of: /a+/)' 'let d = try JSONDecoder().decode(Int.self, from: data)'; do
  portable_case "R18: '$form' needs no full Foundation" "$form" 0
  if grep -q "fullFoundation" "$ROOT/out.txt"; then fail=$((fail+1)); echo "FAIL R18: '$form' warned"; else pass=$((pass+1)); echo "ok   R18: '$form' does not warn"; fi
done
setup; only_portable; src 'let t = s.trimmingCharacters(in: .whitespaces)'
"$CHECK" "$ROOT" --rules "$ROOT/rules.json" --baseline "$ROOT/baseline.json" --adr-dir "$ROOT/adr" --write-baseline > "$ROOT/out.txt" 2>&1
if grep -q "wrote 0 entries" "$ROOT/out.txt" && [[ "$(cat "$ROOT/baseline.json")" == "[]" ]]; then pass=$((pass+1)); echo "ok   R18: a warning never enters the baseline"
else fail=$((fail+1)); echo "FAIL R18: a warning entered the baseline"; sed 's/^/     /' "$ROOT/out.txt"; fi
setup; src 'let t = s.trimmingCharacters(in: .whitespaces)'; expect "R18: a target without R18 gets no warning" 0 ""
if grep -q "fullFoundation" "$ROOT/out.txt"; then fail=$((fail+1)); echo "FAIL R18: a target without R18 warned"; else pass=$((pass+1)); echo "ok   R18: the warning belongs to R18 only"; fi
# Android is the C library of the Swift SDK for Android, as Glibc is Linux's: modules.md names it like the others.
setup; src 'let x = 1'
python3 - "$ROOT/rules.json" <<'PY'
import json,sys; p=sys.argv[1]; r=json.load(open(p)); r["targets"][0]["allowedImports"] += ["Glibc", "Darwin", "Android"]; json.dump(r,open(p,"w"))
PY
printf '| Target | Layer | Platforms | May import |\n|---|---|---|---|\n| `Pure` | adapter | all | Foundation, Glibc, Darwin, Android |\n| `Other` | x | all | Foundation |\n' > "$ROOT/modules.md"
expect "modules.md: Android is a module name, as Glibc and Darwin are" 0 "" --modules "$ROOT/modules.md"
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
# On Darwin, skipDescendants() after a file skips the next directory: .gitignore hid PrestoCVTests on a Mac (#246). On
# APFS, .buildinfo is listed before Nested, so a folder that holds only the two shows it on every Mac.
setup; src 'let x = 1'; mkdir -p "$ROOT/Sources/Pure/Generated/Nested"; touch "$ROOT/Sources/Pure/Generated/.buildinfo"
echo 'let d = Date()' > "$ROOT/Sources/Pure/Generated/Nested/N.swift"
expect "inventory: the folder after a skipped file is still checked" 1 "Sources/Pure/Generated/Nested/N.swift:1: R2 wallClock"
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
# --- the pre-commit hook
# git exports GIT_DIR and GIT_INDEX_FILE to its hooks, as absolute paths in a linked worktree. SwiftPM runs git in its
# dependency checkouts with `git -C`, which those variables override, so the first commit in a fresh worktree checked
# out swift-syntax's revision in the project's repository and failed. Here check.sh is a stub that makes the same call,
# and records the configuration given to the commit with `git -c` and GIT_CONFIG_COUNT, which the hook keeps.
HOOK_ROOT="$(mktemp -d)"; ROOTS+=("$HOOK_ROOT")
LABEL="hook: from a linked worktree, check.sh's git works on its own repository with the commit's configuration, and the commit keeps the staged file"
# Not the condition of an `if`, where bash ignores set -e and only the last command would count.
(
  set -e; cd "$HOOK_ROOT"
  # Neither the developer's git configuration (identity, signing, hooks) nor the repository of a caller that runs this
  # from a git hook plays any part: its GIT_DIR would point every git call here at that repository.
  unset $(git rev-parse --local-env-vars)
  export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
  export GIT_AUTHOR_NAME=selftest GIT_AUTHOR_EMAIL=selftest@example.invalid
  export GIT_COMMITTER_NAME=selftest GIT_COMMITTER_EMAIL=selftest@example.invalid
  git init -q -b main dep; git -C dep commit -q --allow-empty -m first; git -C dep commit -q --allow-empty -m second
  FIRST="$(git -C dep rev-parse HEAD~1)"
  git init -q -b main repo; mkdir -p repo/Tools/ArchitectureCheck hooks
  {
    echo '#!/usr/bin/env bash'
    echo 'set -e'
    echo "git -C '$HOOK_ROOT/dep' checkout -q -f $FIRST"
    echo "git -C '$HOOK_ROOT/dep' config --get selftest.param >> '$HOOK_ROOT/kept' || :"
    echo "git -C '$HOOK_ROOT/dep' config --get selftest.count >> '$HOOK_ROOT/kept' || :"
  } > repo/Tools/ArchitectureCheck/check.sh
  chmod +x repo/Tools/ArchitectureCheck/check.sh
  git -C repo add -A; git -C repo commit -q -m stub
  ln -s "$HERE/pre-commit.sh" hooks/pre-commit; git -C repo config core.hooksPath "$HOOK_ROOT/hooks"
  git -C repo worktree add -q ../wt -b feature
  echo 'let x = 1' > wt/A.swift; git -C wt add A.swift
  GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=selftest.count GIT_CONFIG_VALUE_0=count \
    git -C wt -c selftest.param=param commit -q -m change
  # The stub checked out its own repository, and git, which reads the index again after the hook, committed ours.
  [ "$(git -C dep rev-parse HEAD)" = "$FIRST" ] || { echo "check.sh did not check out its own repository"; exit 1; }
  git -C wt cat-file -e HEAD:A.swift || { echo "the commit lost the staged A.swift"; exit 1; }
  KEPT="$(tr '\n' ' ' < kept)"
  [ "$KEPT" = "param count " ] || { echo "check.sh got this of the configuration given to the commit: '$KEPT'"; exit 1; }
) > "$HOOK_ROOT/out.txt" 2>&1
if [[ $? -eq 0 ]]; then pass=$((pass+1)); echo "ok   $LABEL"
else fail=$((fail+1)); echo "FAIL $LABEL"; sed 's/^/     /' "$HOOK_ROOT/out.txt"; fi

echo "selftest: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
