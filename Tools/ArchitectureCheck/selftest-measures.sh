# The self-test cases of the size and shape detectors (ADR 0021 (c)). Sourced by selftest.sh, which owns the helpers and
# the counters. Each detector has a planted violation that must be reported and the fixed version that must pass; the
# boundary cases sit on the limit (20 lines, 3 parameters, 2 levels, complexity 5, 200 and 300 lines, 5 requirements).

lets() { local i; for ((i = 1; i <= $1; i++)); do printf '    let v%d = %d\n' "$i" "$i"; done; }
fn() { printf 'func f() {\n%s\n}\n' "$(lets "$1")"; }
lines_of() { local i; for ((i = 1; i <= $1; i++)); do printf "$2\n" "$i"; done; }      # $2 holds one %d
spaced() { local i; for ((i = 1; i <= $1; i++)); do printf '    text %d\n\n' "$i"; done; }   # text lines with a blank line after each
# A finding of $3 and none of $4: a measure must point at the right body.
flag_only() {
  setup; src "$2"; local got; got=$(run)
  if [[ "$got" == 1 ]] && grep -qE -- "$3" "$ROOT/out.txt" && ! grep -qE -- "$4" "$ROOT/out.txt"; then pass=$((pass+1)); echo "ok   $1"
  else fail=$((fail+1)); echo "FAIL $1 (exit $got; wanted $3 and not $4)"; sed 's/^/     /' "$ROOT/out.txt"; fi
}

# --- functionLength: lines of code in a body, 20 at most
flag "functionLength: 21 lines of code" "$(fn 21)" "CleanFunctions: functionLength: func f has 21 lines"
clean "functionLength: 20 lines of code" "$(fn 20)"
clean "functionLength: blank, comment and brace-only lines do not count" "$(printf 'func f() {\n%s\n\n\n    // a comment\n    /* a block\n       comment */\n    if v1 > 0\n    {\n        let w = 1\n    }\n}\n' "$(lets 18)")"
flag "functionLength: an initialiser" "$(printf 'struct S {\n    init() {\n%s\n    }\n}\n' "$(lets 21)")" "functionLength: init has 21"
flag "functionLength: a computed property" "$(printf 'struct S {\n    var p: Int {\n%s\n        return 0\n    }\n}\n' "$(lets 20)")" "functionLength: getter of p has 21"
flag "functionLength: an accessor" "$(printf 'struct S {\n    var p: Int = 0 {\n        didSet {\n%s\n        }\n    }\n}\n' "$(lets 21)")" "functionLength: didSet of p has 21"
flag "functionLength: a subscript getter" "$(printf 'struct S {\n    subscript(i: Int) -> Int {\n%s\n        return 0\n    }\n}\n' "$(lets 20)")" "functionLength: getter of subscript has 21"
flag "functionLength: a deinitialiser" "$(printf 'final class S {\n    deinit {\n%s\n    }\n}\n' "$(lets 21)")" "functionLength: deinit has 21"
flag "functionLength: a closure" "$(printf 'func f() {\n    run {\n%s\n    }\n}\n' "$(lets 21)")" "functionLength: closure has 21"
flag_only "functionLength: a closure is measured on its own, not in its function" \
  "$(printf 'func f() {\n    run {\n%s\n    }\n}\n' "$(lets 21)")" "closure has 21" "func f has"
clean "functionLength: a closure's lines are not counted again in its function" "$(printf 'func f() {\n%s\n    run {\n%s\n    }\n}\n' "$(lets 10)" "$(lets 20)")"
flag_only "functionLength: a closure inside a closure is measured on its own" \
  "$(printf 'func f() {\n    run {\n%s\n        again {\n%s\n        }\n    }\n}\n' "$(lets 15)" "$(lets 21)")" "closure has 21" "closure has 1[0-9] |func f has"
flag "functionLength: a trailing closure of a call" "$(printf 'func f() {\n    items.forEach { item in\n%s\n    }\n}\n' "$(lets 21)")" "functionLength: closure has 21"
flag "functionLength: a closure that initialises a property" "$(printf 'struct S {\n    static let table: [Int] = {\n%s\n        return []\n    }()\n}\n' "$(lets 20)")" "functionLength: closure has 21"
flag_only "functionLength: a nested function counts in its function and in itself" \
  "$(printf 'func f() {\n%s\n    func g() {\n%s\n    }\n}\n' "$(lets 12)" "$(lets 12)")" "func f has 25" "func g has"
flag "functionLength: a nested function of 21 lines" "$(printf 'func f() {\n    func g() {\n%s\n    }\n}\n' "$(lets 21)")" "functionLength: func g has 21"
flag "functionLength: every #if branch counts" "$(printf 'func f() {\n#if DEBUG\n%s\n#else\n%s\n#endif\n}\n' "$(lets 12)" "$(lets 12)")" "functionLength: func f has"
clean "functionLength: a short #if is no finding" "$(printf 'func f() {\n#if DEBUG\n%s\n#else\n%s\n#endif\n}\n' "$(lets 5)" "$(lets 5)")"
flag "functionLength: a multi-line string counts line by line" "$(printf 'func f() -> String {\n    return """\n%s\n    """\n}\n' "$(lines_of 19 '    text %d')")" "functionLength: func f has 21"
clean "functionLength: a multi-line string of 18 lines is 20 lines of code" "$(printf 'func f() -> String {\n    return """\n%s\n    """\n}\n' "$(lines_of 18 '    text %d')")"
flag "functionLength: blank lines inside a multi-line string count" \
  "$(printf 'func f() -> String {\n    return """\n%s\n    """\n}\n' "$(spaced 10)")" "functionLength: func f has 21"
flag "functionLength: a multi-line expression counts line by line" "$(printf 'func f() {\n    g(\n%s\n        0\n    )\n}\n' "$(lines_of 18 '        %d,')")" "functionLength: func f has 21"
clean "functionLength: a multi-line expression of 20 lines" "$(printf 'func f() {\n    g(\n%s\n        0\n    )\n}\n' "$(lines_of 17 '        %d,')")"
flag "functionLength: a defer body counts in its function" "$(printf 'func f() {\n    defer {\n        a()\n        b()\n        c()\n        d()\n    }\n%s\n}\n' "$(lets 17)")" "functionLength: func f has 22"
clean "functionLength: a function with a defer within the limit" "$(printf 'func f() {\n    defer {\n        a()\n    }\n%s\n}\n' "$(lets 17)")"
flag "functionLength: a result-builder body is a computed property" "$(printf 'struct V {\n    @Builder var body: Int {\n        Stack {\n%s\n        }\n    }\n}\n' "$(lets 21)")" "functionLength: closure has 21"
flag "functionLength: a protocol extension method" "$(printf 'extension P {\n    func f() {\n%s\n    }\n}\n' "$(lets 21)")" "functionLength: func f has 21"
flag "functionLength: reported in a type nested in a function" "$(printf 'func f() {\n    struct L {\n        func g() {\n%s\n        }\n    }\n}\n' "$(lets 21)")" "functionLength: func g has 21"

# --- the policy: these detectors run on production targets only (ADR 0021 (c))
setup; src 'let x = 1'; printf '%s\n' "$(fn 21)" > "$ROOT/Sources/Other/O.swift"
expect "a target that does not list the rules is not measured" 0 ""
if python3 - "$HERE/rules.json" <<'PYJ'
import json, sys
r = json.load(open(sys.argv[1]))
sized = {"CleanFunctions", "CleanTypes", "CleanComments", "ISP"}
bad = [t["name"] for t in r["targets"] if t.get("kind", "production") != "production" and sized & set(t["rules"])]
sys.exit(1 if bad else 0)
PYJ
then pass=$((pass+1)); echo "ok   rules.json: no test, tool, manifest, legacy or excluded target lists a size, shape or comment rule"
else fail=$((fail+1)); echo "FAIL rules.json: a target that is not a production target lists a size, shape or comment rule"; fi
