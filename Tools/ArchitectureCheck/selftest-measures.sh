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

# --- nestingDepth: 2 levels at most
flag "nestingDepth: if, for, if is 3 levels" $'func f() {\n    if a {\n        for x in y {\n            if b { g() }\n        }\n    }\n}' "CleanFunctions: nestingDepth: func f nests 3 levels"
clean "nestingDepth: 2 levels" $'func f() {\n    if a {\n        for x in y { g() }\n    }\n}'
clean "nestingDepth: an exit-only guard is no level" $'func f() {\n    if a {\n        if b {\n            guard let c else { return }\n            g(c)\n        }\n    }\n}'
clean "nestingDepth: a guard that throws is no level" $'func f() throws {\n    if a {\n        if b {\n            guard c else { throw E.bad }\n        }\n    }\n}'
clean "nestingDepth: a guard that continues is no level" $'func f() {\n    for x in y {\n        if a {\n            guard c else { continue }\n        }\n    }\n}'
flag "nestingDepth: a guard that does more than exit is a level" $'func f() {\n    if a {\n        if b {\n            guard c else { log(); return }\n        }\n    }\n}' "nestingDepth: func f nests 3 levels"
flag "nestingDepth: a guard with a statement after its exit is a level" $'func f() {\n    if a {\n        if b {\n            guard c else { return; log() }\n        }\n    }\n}' "nestingDepth: func f nests 3 levels"
flag "nestingDepth: a closure is a level" $'func f() {\n    if a {\n        items.forEach { x in\n            if x { g() }\n        }\n    }\n}' "nestingDepth: func f nests 3 levels"
flag "nestingDepth: a closure inside a closure is a second level" $'func f() {\n    run {\n        again {\n            if x { g() }\n        }\n    }\n}' "nestingDepth: func f nests 3 levels"
clean "nestingDepth: else if continues the chain" $'func f() {\n    if a {\n        g()\n    } else if b {\n        g()\n    } else if c {\n        if d { g() }\n    }\n}'
flag "nestingDepth: an if inside the else of a chain is a level" $'func f() {\n    if a {\n        g()\n    } else {\n        if b {\n            if c { g() }\n        }\n    }\n}' "nestingDepth: func f nests 3 levels"
flag "nestingDepth: a switch is a level and its cases are not" $'func f() {\n    switch x {\n    case 1:\n        if a {\n            if b { g() }\n        }\n    default: break\n    }\n}' "nestingDepth: func f nests 3 levels"
clean "nestingDepth: a switch with an if is 2 levels" $'func f() {\n    switch x {\n    case 1:\n        if a { g() }\n    default: break\n    }\n}'
flag "nestingDepth: do is a level and catch adds none" $'func f() {\n    do {\n        if a {\n            if b { try g() }\n        }\n    } catch {\n        h()\n    }\n}' "nestingDepth: func f nests 3 levels"
clean "nestingDepth: a catch clause is at the level of its do" $'func f() {\n    do {\n        try g()\n    } catch {\n        if a { h() }\n    }\n}'
flag "nestingDepth: while, repeat, for" $'func f() {\n    while a {\n        repeat {\n            for x in y { g() }\n        } while b\n    }\n}' "nestingDepth: func f nests 3 levels"
clean "nestingDepth: a defer is no level" $'func f() {\n    if a {\n        if b {\n            defer { g() }\n        }\n    }\n}'
clean "nestingDepth: a nested function starts again at its own body" $'func f() {\n    if a {\n        func g() {\n            if b {\n                if c { h() }\n            }\n        }\n    }\n}'
flag "nestingDepth: an initialiser" $'struct S {\n    init() {\n        if a {\n            for x in y {\n                if b { g() }\n            }\n        }\n    }\n}' "nestingDepth: init nests 3 levels"
flag "nestingDepth: a computed property" $'struct S {\n    var p: Int {\n        if a {\n            for x in y {\n                if b { return 1 }\n            }\n        }\n        return 0\n    }\n}' "nestingDepth: getter of p nests 3 levels"
flag "nestingDepth: a closure that initialises a property" $'struct S {\n    static let t: Int = {\n        if a {\n            for x in y {\n                if b { return 1 }\n            }\n        }\n        return 0\n    }()\n}' "nestingDepth: closure nests 3 levels"

# --- cyclomaticComplexity: 5 at most; one plus each decision
decisions() {   # $1 = how many, $2 = a statement with one %d
  printf 'func f() {\n%s\n}\n' "$(lines_of "$1" "    $2")"
}
for stmt in 'if x%d { g() }' 'guard x%d else { return }' 'while x%d { break }' 'for i%d in xs { g() }' 'repeat { g() } while x%d'; do
  name="${stmt%% *}"
  flag "cyclomaticComplexity: 5 of $name make 6" "$(decisions 5 "$stmt")" "CleanFunctions: cyclomaticComplexity: func f has a cyclomatic complexity of 6"
  clean "cyclomaticComplexity: 4 of $name make 5" "$(decisions 4 "$stmt")"
done
operators() {   # $1 = how many, $2 = the operator
  local i expr="a"; for ((i = 1; i <= $1; i++)); do expr+=" $2 b$i"; done
  printf 'func f() -> Bool {\n    return %s\n}\n' "$expr"
}
for op in '&&' '||' '??'; do
  flag "cyclomaticComplexity: 5 of $op make 6" "$(operators 5 "$op")" "cyclomaticComplexity: func f has a cyclomatic complexity of 6"
  clean "cyclomaticComplexity: 4 of $op make 5" "$(operators 4 "$op")"
done
ternaries() { local i expr=""; for ((i = 1; i <= $1; i++)); do expr+="c$i ? $i : "; done; printf 'func f() -> Int {\n    return %s0\n}\n' "$expr"; }
flag "cyclomaticComplexity: 5 ternaries make 6" "$(ternaries 5)" "cyclomaticComplexity: func f has a cyclomatic complexity of 6"
clean "cyclomaticComplexity: 4 ternaries make 5" "$(ternaries 4)"
catches() { local i; printf 'func f() {\n    do { try g() }'; for ((i = 1; i <= $1; i++)); do printf ' catch E%d { h() }' "$i"; done; printf '\n}\n'; }
flag "cyclomaticComplexity: 5 catch clauses make 6" "$(catches 5)" "cyclomaticComplexity: func f has a cyclomatic complexity of 6"
clean "cyclomaticComplexity: 4 catch clauses make 5" "$(catches 4)"
clean "cyclomaticComplexity: a switch counts once, however many cases (10 cases and 3 ifs make 5)" "$(printf 'func f() {\n    switch x {\n%s\n    default: break\n    }\n%s\n}\n' "$(lines_of 10 '    case %d: g()')" "$(lines_of 3 '    if x%d { g() }')")"
flag "cyclomaticComplexity: a switch counts once (10 cases and 4 ifs make 6)" "$(printf 'func f() {\n    switch x {\n%s\n    default: break\n    }\n%s\n}\n' "$(lines_of 10 '    case %d: g()')" "$(lines_of 4 '    if x%d { g() }')")" "cyclomaticComplexity: func f has a cyclomatic complexity of 6"
clean "cyclomaticComplexity: the commas of a condition list are not decisions" $'func f() {\n    if let a = x, let b = y, c, d, e, g { h() }\n}'
clean "cyclomaticComplexity: else if counts per if, an else counts for nothing" $'func f() {\n    if a { g() } else if b { g() } else if c { g() } else if d { g() } else { g() }\n}'
flag "cyclomaticComplexity: else if counts per if" $'func f() {\n    if a { g() } else if b { g() } else if c { g() } else if d { g() } else if e { g() } else { g() }\n}' "cyclomatic complexity of 6"
flag "cyclomaticComplexity: the decisions of a closure count in its function" "$(printf 'func f() {\n    run {\n%s\n    }\n}\n' "$(lines_of 5 '        if x%d { g() }')")" "cyclomaticComplexity: func f has a cyclomatic complexity of 6"
flag_only "cyclomaticComplexity: a nested function is measured on its own" \
  "$(printf 'func f() {\n%s\n    func g() {\n%s\n    }\n}\n' "$(lines_of 3 '    if x%d { h() }')" "$(lines_of 5 '        if y%d { h() }')")" "func g has a cyclomatic complexity of 6" "func f has a cyclomatic"
flag "cyclomaticComplexity: an initialiser" "$(printf 'struct S {\n    init() {\n%s\n    }\n}\n' "$(lines_of 5 '        if x%d { g() }')")" "cyclomaticComplexity: init has a cyclomatic complexity of 6"
flag "cyclomaticComplexity: a computed property" "$(printf 'struct S {\n    var p: Int {\n%s\n        return 0\n    }\n}\n' "$(lines_of 5 '        if x%d { return 1 }')")" "cyclomaticComplexity: getter of p has"
flag "cyclomaticComplexity: a closure that initialises a property" "$(printf 'struct S {\n    static let t: Int = {\n%s\n        return 0\n    }()\n}\n' "$(lines_of 5 '        if x%d { return 1 }')")" "cyclomaticComplexity: closure has"
clean "cyclomaticComplexity: decisions outside any body are not measured" 'let r = a && b && c && d && e && f && g'

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
