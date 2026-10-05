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
clean "functionLength: a nested function's lines are not counted again in its function" "$(printf 'func f() {\n%s\n    func g() {\n%s\n    }\n}\n' "$(lets 10)" "$(lets 20)")"
flag_only "functionLength: a nested function is measured on its own, not in its function" \
  "$(printf 'func f() {\n%s\n    func g() {\n%s\n    }\n}\n' "$(lets 10)" "$(lets 21)")" "func g has 21" "func f has"
flag_only "functionLength: a function counts its own lines and the header of its nested function" \
  "$(printf 'func f() {\n%s\n    func g() {\n%s\n    }\n    h()\n}\n' "$(lets 19)" "$(lets 3)")" "func f has 21" "func g has"
flag_only "functionLength: a function nested in a nested function is measured on its own" \
  "$(printf 'func f() {\n    func g() {\n%s\n        func h() {\n%s\n        }\n    }\n}\n' "$(lets 10)" "$(lets 21)")" "func h has 21" "func f has|func g has"
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
condition_list() {   # $1 = if, guard or while, $2 = how many conditions
  local i list="c1"; for ((i = 2; i <= $2; i++)); do list+=", c$i"; done
  if [[ "$1" == guard ]]; then printf 'func f() {\n    guard %s else { return }\n}\n' "$list"; else printf 'func f() {\n    %s %s { g() }\n}\n' "$1" "$list"; fi
}
for kw in if guard while; do
  flag "cyclomaticComplexity: $kw with a list of 5 conditions makes 6" "$(condition_list $kw 5)" "cyclomaticComplexity: func f has a cyclomatic complexity of 6"
  clean "cyclomaticComplexity: $kw with a list of 4 conditions makes 5" "$(condition_list $kw 4)"
  flag "cyclomaticComplexity: $kw with a list of 7 conditions makes 8" "$(condition_list $kw 7)" "cyclomaticComplexity: func f has a cyclomatic complexity of 8"
done
flag "cyclomaticComplexity: every kind of condition in a list counts" $'func f() {\n    if let a = x, case .y = z, x is Int, b > 0, c { h() }\n}' "cyclomatic complexity of 6"
clean "cyclomaticComplexity: four kinds of condition make 5" $'func f() {\n    if let a = x, case .y = z, x is Int, b > 0 { h() }\n}'
flag "cyclomaticComplexity: a guard with optional bindings and a pattern counts each" $'func f() {\n    guard let x = a, let y = b, case .z = c, let w = d, let v = e else { return }\n}' "cyclomatic complexity of 6"
clean "cyclomaticComplexity: a condition list and an && count together (an if, an &&, a comma make 4)" $'func f() {\n    if a && b, c { h() }\n}'
flag "cyclomaticComplexity: the lists of an else if chain each count" $'func f() {\n    if a, b { g() } else if c, d { g() } else if e, f { g() }\n}' "cyclomatic complexity of 7"
clean "cyclomaticComplexity: two lists of two make 5" $'func f() {\n    if a, b { g() } else if c, d { g() }\n}'
clean "cyclomaticComplexity: a repeat-while has one condition" $'func f() {\n    repeat { g() } while a\n}'
flag "cyclomaticComplexity: the list of a statement in a closure counts in its function" $'func f() {\n    run {\n        if a, b, c, d, e { g() }\n    }\n}' "cyclomatic complexity of 6"
clean "cyclomaticComplexity: else if counts per if, an else counts for nothing" $'func f() {\n    if a { g() } else if b { g() } else if c { g() } else if d { g() } else { g() }\n}'
flag "cyclomaticComplexity: else if counts per if" $'func f() {\n    if a { g() } else if b { g() } else if c { g() } else if d { g() } else if e { g() } else { g() }\n}' "cyclomatic complexity of 6"
flag "cyclomaticComplexity: the decisions of a closure count in its function" "$(printf 'func f() {\n    run {\n%s\n    }\n}\n' "$(lines_of 5 '        if x%d { g() }')")" "cyclomaticComplexity: func f has a cyclomatic complexity of 6"
flag_only "cyclomaticComplexity: a nested function is measured on its own" \
  "$(printf 'func f() {\n%s\n    func g() {\n%s\n    }\n}\n' "$(lines_of 3 '    if x%d { h() }')" "$(lines_of 5 '        if y%d { h() }')")" "func g has a cyclomatic complexity of 6" "func f has a cyclomatic"
flag "cyclomaticComplexity: an initialiser" "$(printf 'struct S {\n    init() {\n%s\n    }\n}\n' "$(lines_of 5 '        if x%d { g() }')")" "cyclomaticComplexity: init has a cyclomatic complexity of 6"
flag "cyclomaticComplexity: a computed property" "$(printf 'struct S {\n    var p: Int {\n%s\n        return 0\n    }\n}\n' "$(lines_of 5 '        if x%d { return 1 }')")" "cyclomaticComplexity: getter of p has"
flag "cyclomaticComplexity: a closure that initialises a property" "$(printf 'struct S {\n    static let t: Int = {\n%s\n        return 0\n    }()\n}\n' "$(lines_of 5 '        if x%d { return 1 }')")" "cyclomaticComplexity: closure has"
clean "cyclomaticComplexity: decisions outside any body are not measured" 'let r = a && b && c && d && e && f && g'

# --- parameterCount: 3 at most; a data initialiser is exempt
flag "parameterCount: 4 parameters" 'func f(a: Int, b: Int, c: Int, d: Int) {}' "CleanFunctions: parameterCount: func f takes 4"
clean "parameterCount: 3 parameters" 'func f(a: Int, b: Int, c: Int) {}'
flag "parameterCount: a protocol requirement counts" $'protocol P {\n    func f(a: Int, b: Int, c: Int, d: Int)\n}' "parameterCount: func f takes 4"
flag "parameterCount: an initialiser that does more than store" $'struct S {\n    let a: Int, b: Int, c: Int, d: Int\n    init(a: Int, b: Int, c: Int, d: Int) { self.a = a; self.b = b; self.c = c; self.d = d + 1 }\n}' "parameterCount: init takes 4"
flag "parameterCount: an initialiser that leaves a parameter unused" $'struct S {\n    let a: Int, b: Int, c: Int\n    init(a: Int, b: Int, c: Int, d: Int) { self.a = a; self.b = b; self.c = c }\n}' "parameterCount: init takes 4"
flag "parameterCount: an initialiser that assigns one parameter twice" $'struct S {\n    let a: Int, b: Int, c: Int, d: Int\n    init(a: Int, b: Int, c: Int, d: Int) { self.a = a; self.b = b; self.c = c; self.d = d; self.d = d }\n}' "parameterCount: init takes 4"
flag "parameterCount: an initialiser with a body besides the assignments" $'struct S {\n    let a: Int, b: Int, c: Int, d: Int\n    init(a: Int, b: Int, c: Int, d: Int) {\n        self.a = a; self.b = b; self.c = c; self.d = d\n        register()\n    }\n}' "parameterCount: init takes 4"
flag "parameterCount: an initialiser that stores a parameter in another property" $'struct S {\n    let a: Int, b: Int, c: Int, d: Int\n    init(a: Int, b: Int, c: Int, d: Int) { self.a = a; self.b = b; self.c = c; self.b = d }\n}' "parameterCount: init takes 4"
flag "parameterCount: an empty initialiser" $'struct S {\n    init(a: Int, b: Int, c: Int, d: Int) {}\n}' "parameterCount: init takes 4"
clean "parameterCount: a data initialiser stores each parameter in the property of its name" $'struct S {\n    let a: Int, b: Int, c: Int, d: Int\n    init(a: Int, b: Int, c: Int, d: Int) { self.a = a; self.b = b; self.c = c; self.d = d }\n}'
clean "parameterCount: a data initialiser keeps its parameter names, not its labels" $'struct S {\n    let a: Int, b: Int, c: Int, d: Int\n    init(first a: Int, _ b: Int, _ c: Int, last d: Int) {\n        self.d = d\n        self.c = c\n        self.b = b\n        self.a = a\n    }\n}'
clean "parameterCount: an initialiser that passes its parameters unchanged is a data initialiser" $'final class S {\n    init(a: Int, b: Int, c: Int, d: Int) { self.a = a; self.b = b; self.c = c; self.d = d }\n    convenience init(origin a: Int, b: Int, c: Int, d: Int) { self.init(a: a, b: b, c: c, d: d) }\n}'
flag "parameterCount: a delegating initialiser that changes a parameter" $'final class S {\n    convenience init(a: Int, b: Int, c: Int, d: Int) { self.init(a: a, b: b, c: c, d: d + 1) }\n}' "parameterCount: init takes 4"
flag "parameterCount: a delegating initialiser that drops a parameter" $'final class S {\n    convenience init(a: Int, b: Int, c: Int, d: Int) { self.init(a: a, b: b, c: c) }\n}' "parameterCount: init takes 4"
# A data initialiser may also give the other properties a literal or a constant, and pass literals and constants on.
data_init() {   # $1 = name, $2 = clean or flag, $3 = the body of an initialiser of four parameters, $4 = what precedes the type
  local src; src="$(printf '%s\nstruct S {\n    init(a: Int, b: Int, c: Int, d: Int) { %s }\n}\n' "${4:-}" "$3")"
  if [[ "$2" == clean ]]; then clean "parameterCount: $1" "$src"; else flag "parameterCount: $1" "$src" "parameterCount: init takes 4"; fi
}
delegating_init() {   # the same, for a convenience initialiser
  local src; src="$(printf '%s\nfinal class S {\n    convenience init(a: Int, b: Int, c: Int, d: Int) { %s }\n}\n' "${4:-}" "$3")"
  if [[ "$2" == clean ]]; then clean "parameterCount: $1" "$src"; else flag "parameterCount: $1" "$src" "parameterCount: init takes 4"; fi
}
STORE='self.a = a; self.b = b; self.c = c; self.d = d'
PASS='a: a, b: b, c: c, d: d'
for value in '0' '-1' '+2' '1.5' '-0.5' 'true' '"text"' '""' 'nil' '[]' '[:]' '[0, 1]' '["a": 1]' '[[0], []]' '.none' 'Kind.empty' 'Self.zero' 'Module.Kind.empty'; do
  data_init "assignment: a data initialiser gives another property $value" clean "$STORE; self.e = $value"
  delegating_init "delegation: a data initialiser passes $value on" clean "self.init($PASS, e: $value)"
done
data_init "assignment: the literals may come before the parameters" clean "self.e = 0; self.f = nil; $STORE; self.g = []"
data_init "assignment: a property may be named without self" clean "$STORE; e = 0"
data_init "assignment: a file-level let is a constant" clean "$STORE; self.e = limit" "let limit = 9"
data_init "assignment: a private file-level let is a constant" clean "$STORE; self.e = limit" "private let limit = 9"
data_init "assignment: a file-level let in an #if branch is a constant" clean "$STORE; self.e = limit" $'#if DEBUG\nlet limit = 9\n#else\nlet limit = 8\n#endif'
data_init "assignment: a static let is a constant" clean "$STORE; self.e = Self.limit" "extension S { static let limit = 1 }"
data_init "assignment: a static member of a type declared elsewhere is taken on trust" clean "$STORE; self.e = Other.limit"
delegating_init "delegation: the parameters may be passed in any order, with literals between them" clean "self.init(d: d, e: 0, c: c, f: nil, b: b, g: [], a: a)"
delegating_init "delegation: a file-level let is a constant" clean "self.init($PASS, e: limit)" "let limit = 9"
data_init "assignment: a computed value is behaviour" flag "$STORE; self.e = 1 + 2"
for value in 'makeDefault()' 'Foo()' '.make()' '.some(1)' 'Kind.make(1)' 'Kind.make(a:)' '"\(a)"' '[a]' '-a' 'a' 'a ?? 0' 'flag ? 1 : 2' 'defaults.limit' 'limit' 'Type.init' '[makeDefault()]' '["k": Foo()]'; do
  data_init "assignment: $value is not a literal or a constant" flag "$STORE; self.e = $value"
  delegating_init "delegation: $value is not a literal or a constant" flag "self.init($PASS, e: $value)"
done
delegating_init "delegation: a computed argument is behaviour" flag "self.init($PASS, e: 1 + 2)"
data_init "assignment: a parameter stored a second time" flag "$STORE; self.e = a"
data_init "assignment: a name that a parameter shares with a file-level let is the parameter" flag "$STORE; self.e = a" "let a = 1"
data_init "assignment: two parameters stored in each other's property" flag "self.a = b; self.b = a; self.c = c; self.d = d"
data_init "assignment: a transformed parameter" flag "self.a = a; self.b = b; self.c = c; self.d = d!"
data_init "assignment: a parameter that a literal replaces" flag "self.a = a; self.b = b; self.c = c; self.d = 0"
data_init "assignment: a property given a literal twice" flag "$STORE; self.e = 0; self.e = 1"
data_init "assignment: a parameter stored under its own name and again by a literal" flag "$STORE; self.d = 0"
data_init "assignment: a file-level var is not a constant" flag "$STORE; self.e = counter" "var counter = 0"
data_init "assignment: a let inside a function is not a constant" flag "$STORE; self.e = local" "func g() { let local = 1 }"
data_init "assignment: a static var of the file is not a constant" flag "$STORE; self.e = Self.shared" "extension S { static var shared = 0 }"
data_init "assignment: a class var of the file is not a constant" flag "$STORE; self.e = .shared" "extension S { class var shared: Int { 0 } }"
data_init "assignment: a call after the assignments" flag "$STORE; self.e = 0; register()"
delegating_init "delegation: a parameter passed twice" flag "self.init($PASS, e: d)"
delegating_init "delegation: a parameter replaced by a literal" flag "self.init(a: a, b: b, c: c, d: 0)"
delegating_init "delegation: a name that is neither a parameter nor a file-level let" flag "self.init($PASS, e: unknown)"
delegating_init "delegation: a trailing closure" flag "self.init($PASS) { }"
delegating_init "delegation: a second statement" flag "self.init($PASS, e: 0); register()"
delegating_init "delegation: a name that a parameter shares with a file-level let is the parameter" flag "self.init(a: a, b: b, c: c, d: a)" "let a = 1"
clean "parameterCount: the parameters of a closure are not counted" 'let f: (Int, Int, Int, Int) -> Void = { a, b, c, d in }'

# --- typeLength: 200 lines of code per declaration or extension
members() { lines_of "$1" '    var m%d = 0'; }
flag "typeLength: a struct of 201 lines" "$(printf 'struct S {\n%s\n}\n' "$(members 201)")" "CleanTypes: typeLength: struct S has 201"
clean "typeLength: a struct of 200 lines" "$(printf 'struct S {\n%s\n}\n' "$(members 200)")"
flag "typeLength: a class" "$(printf 'final class C {\n%s\n}\n' "$(members 201)")" "typeLength: class C has 201"
flag "typeLength: an enumeration" "$(printf 'enum E {\n%s\n}\n' "$(lines_of 201 '    case c%d')")" "typeLength: enum E has 201"
flag "typeLength: an actor" "$(printf 'actor A {\n%s\n}\n' "$(members 201)")" "typeLength: actor A has 201"
flag "typeLength: an extension" "$(printf 'extension S {\n%s\n}\n' "$(members 201)")" "typeLength: extension S has 201"
flag_only "typeLength: a declaration and its extension are measured separately" \
  "$(printf 'struct S {\n%s\n}\nextension S {\n%s\n}\n' "$(members 50)" "$(members 201)")" "extension S has 201" "struct S has"
clean "typeLength: a declaration and its extension within the limit, 242 lines in all" "$(printf 'struct S {\n%s\n}\nextension S {\n%s\n}\n' "$(members 120)" "$(members 120)")"
clean "typeLength: a nested type's lines are not counted again in its type" "$(printf 'struct S {\n%s\n    struct N {\n%s\n    }\n}\n' "$(members 150)" "$(lines_of 60 '        var n%d = 0')")"
flag_only "typeLength: a nested type is measured on its own, not in its type" \
  "$(printf 'struct S {\n%s\n    struct N {\n%s\n    }\n}\n' "$(members 100)" "$(lines_of 201 '        var n%d = 0')")" "struct N has 201" "struct S has"
flag_only "typeLength: a type counts its own lines and the header of its nested type" \
  "$(printf 'struct S {\n%s\n    struct N {\n%s\n    }\n}\n' "$(members 200)" "$(lines_of 60 '        var n%d = 0')")" "struct S has 201" "struct N has"
clean "typeLength: braces, blank lines and comments do not count" "$(printf 'struct S {\n%s\n\n    // a comment\n\n    /* a block\n       comment */\n}\n' "$(members 200)")"

# --- fileLength: 300 lines of code
flag "fileLength: 301 lines" "$(lets 301)" "CleanTypes: fileLength: the file has 301"
clean "fileLength: 300 lines" "$(lets 300)"
clean "fileLength: blank, comment and brace-only lines do not count" "$(printf '%s\n\n// a comment\n\n/* a block\n   comment */\nstruct S\n{\n    var a = 0\n}\n' "$(lets 298)")"

# --- protocolSize: 5 requirements at most
flag "protocolSize: 6 requirements" "$(printf 'protocol P {\n%s\n}\n' "$(lines_of 6 '    func f%d()')")" "ISP: protocolSize: protocol P declares 6"
clean "protocolSize: 5 requirements" "$(printf 'protocol P {\n%s\n}\n' "$(lines_of 5 '    func f%d()')")"
clean "protocolSize: functions, variables, subscripts, initialisers and associated types are 5; a typealias is none" \
  $'protocol P {\n    associatedtype T\n    init()\n    subscript(i: Int) -> Int { get }\n    var a: Int { get }\n    func f()\n    typealias U = Int\n}'
flag "protocolSize: each kind of requirement counts" \
  $'protocol P {\n    associatedtype T\n    init()\n    subscript(i: Int) -> Int { get }\n    var a: Int { get }\n    var b: Int { get set }\n    func f()\n}' "protocol P declares 6"
flag "protocolSize: every #if branch counts" "$(printf 'protocol P {\n%s\n#if DEBUG\n    func a()\n    func b()\n#else\n    func c()\n#endif\n}\n' "$(lines_of 3 '    func f%d()')")" "protocol P declares 6"
flag_only "protocolSize: what a protocol inherits is not counted, what it declares is" \
  "$(printf 'protocol Base {\n%s\n}\nprotocol P: Base {\n    func extra()\n}\n' "$(lines_of 6 '    func f%d()')")" "protocol Base declares 6" "protocol P declares"
clean "protocolSize: a struct with many methods is not a protocol" "$(printf 'struct S {\n%s\n}\n' "$(lines_of 6 '    func f%d() {}')")"

# --- ruleNumberCitation: a former rule number in a comment. The numbers are built from parts, so that no literal one
# is left anywhere in the repository outside the merged ADRs.
R=R
for form in "// ${R}8" "/// The domain is pure (${R}2)." "/* ${R}10 */" "let x = 1   // ${R}14" "// see ${R}1 and ${R}4" "// ${R}9m" \
            $'/// First line.\n/// '"${R}3"$' on the second.' "//${R}5"; do
  flag "ruleNumberCitation: ${form//$'\n'/⏎}" "$form" "CleanComments: ruleNumberCitation"
done
flag "ruleNumberCitation: reported on the line of the comment" $'let a = 1\n/* two\n   lines '"${R}6"$' */\nlet b = 2' "P.swift:3: CleanComments: ruleNumberCitation"
for form in "// ${R}15" "// A${R}8" "// ${R}80" "// ${R}0" "// the rule is DependencyRule" "let s = \"${R}8\"" "let r = \"(${R}2)\"" "// ${R}${R}8" "// ${R}8x"; do
  clean "ruleNumberCitation: not a citation: $form" "$form"
done

# The same detector reads the documents that cite the rules: docs/**/*.md, AGENTS.md and every README.md. The merged ADRs
# 0001 to 0012 and ADR 0021 keep the former numbers, and so does the table of rules.md that maps them.
doc() { mkdir -p "$ROOT/$(dirname "$1")"; printf '%s\n' "$2" > "$ROOT/$1"; }   # $1 = path under the root, $2 = contents
doc_flag() { setup; src 'let x = 1'; doc "$2" "$3"; expect "ruleNumberCitation in a document: $1" 1 "$4"; }   # $1 = name, $2 = path, $3 = contents, $4 = expected line
doc_clean() { setup; src 'let x = 1'; doc "$2" "$3"; expect "ruleNumberCitation in a document: $1" 0 ""; }
CITED="the (${R}8) rule"
doc_flag "AGENTS.md" AGENTS.md "$CITED" "AGENTS.md:1: CleanComments: ruleNumberCitation"
doc_flag "the README of the repository" README.md "$CITED" "README.md:1: CleanComments: ruleNumberCitation"
doc_flag "the README of a package" Package/README.md "$CITED" "Package/README.md:1: CleanComments: ruleNumberCitation"
doc_flag "a document of docs/" docs/architecture/modules.md "$CITED" "docs/architecture/modules.md:1: CleanComments: ruleNumberCitation"
doc_flag "a nested document of docs/" docs/guides/deep/guide.md "$CITED" "docs/guides/deep/guide.md:1: CleanComments: ruleNumberCitation"
doc_flag "an ADR that is not merged yet" docs/architecture/adr/0013-new.md "$CITED" "adr/0013-new.md:1: CleanComments: ruleNumberCitation"
doc_flag "the first ADR after the merged ones" docs/architecture/adr/0020-last.md "$CITED" "adr/0020-last.md:1"
doc_flag "reported on the line of the citation" README.md $'first\nsecond\nthird '"(${R}2)" "README.md:3: CleanComments: ruleNumberCitation"
doc_flag "every citation of a line" README.md "${R}1 and ${R}14 and ${R}9m" "ruleNumberCitation: the document cites"
for adr in 0001 0006 0012 0021; do
  doc_clean "ADR $adr keeps the former numbers" "docs/architecture/adr/$adr-record.md" "$CITED"
done
doc_clean "a Markdown file outside docs, AGENTS.md and the READMEs is not read" notes/other.md "$CITED"
doc_clean "a prototype is not read" Prototypes/Demo/README.md "$CITED"
for text in "${R}15" "A${R}8" "${R}80" "${R}0" "the rule is DependencyRule" "${R}8x"; do
  doc_clean "not a citation: $text" README.md "$text"
done
doc_clean "rules.md keeps the table of former numbers" docs/architecture/rules.md $'# Rules\n\n## Former numbers\n\n| '"${R}1"$' | `DependencyRule` |\n| '"${R}14"$' | `NoDeadCode` |\n\n'
doc_flag "rules.md before its table of former numbers" docs/architecture/rules.md $'# Rules '"(${R}3)"$'\n\n## Former numbers\n\n| '"${R}1"$' | `DependencyRule` |\n' "docs/architecture/rules.md:1: CleanComments"
doc_flag "rules.md after its table of former numbers" docs/architecture/rules.md $'## Former numbers\n\n| '"${R}1"$' | x |\n\n## Review checklist\n\nSee '"${R}4"$'.\n' "docs/architecture/rules.md:7: CleanComments"
doc_flag "another document with a section of the same name" docs/architecture/modules.md $'## Former numbers\n\n| '"${R}1"$' | x |\n' "docs/architecture/modules.md:3: CleanComments"

# --- no baseline (ADR 0021 (e)): the checker refuses a baseline entry of these detectors and never writes one
fingerprint() { python3 -c 'import sys; h = 0xcbf29ce484222325
for b in " ".join(sys.argv[1].split()).encode(): h = ((h ^ b) * 0x100000001b3) % 2**64
print(format(h, "x"))' "$1"; }
baseline_with() { printf '[%s]\n' "$1" > "$ROOT/baseline.json"; }
for entry in "CleanFunctions|functionLength|func f has 21 lines of code, at most 20" "CleanFunctions|parameterCount|x" "CleanFunctions|nestingDepth|x" \
             "CleanFunctions|cyclomaticComplexity|x" "CleanTypes|typeLength|x" "CleanTypes|fileLength|x" "ISP|protocolSize|x" "CleanComments|ruleNumberCitation|x"; do
  rule="${entry%%|*}"; rest="${entry#*|}"; detector="${rest%%|*}"; node="${rest#*|}"
  setup; src 'let x = 1'; baseline_with "\"Sources/Pure/P.swift|$rule|$detector|$(fingerprint "$node")#0\""
  expect "baseline: an entry of $detector is refused" 1 "baseline entry of the measurement detector $detector"
done
setup; src "$(fn 21)"; baseline_with "\"Sources/Pure/P.swift|CleanFunctions|functionLength|$(fingerprint 'func f has 21 lines of code, at most 20')#0\""
expect "baseline: an entry of a measurement detector does not suppress its finding" 1 "new violation Sources/Pure/P.swift:1: CleanFunctions: functionLength"
setup; src 'let x = 1'; baseline_with "\"Sources/Pure/P.swift|CleanErrors|swallowedError|abc#0\""
expect "baseline: an entry of another detector is judged as before (stale)" 1 "no longer occurs"
setup; src "$(printf 'func g() { fatalError("x") }\n%s\n' "$(fn 21 | sed 's/func f/func h/')")"
"$CHECK" "$ROOT" --rules "$ROOT/rules.json" --baseline "$ROOT/baseline.json" --adr-dir "$ROOT/adr" --write-baseline > "$ROOT/out.txt" 2>&1
if grep -q "escapeHatch" "$ROOT/baseline.json" && ! grep -q "functionLength" "$ROOT/baseline.json"; then pass=$((pass+1)); echo "ok   --write-baseline writes the other findings and none of a measurement detector"
else fail=$((fail+1)); echo "FAIL --write-baseline wrote: $(cat "$ROOT/baseline.json")"; fi
if grep -q "never baselined" "$ROOT/out.txt"; then pass=$((pass+1)); echo "ok   --write-baseline says it left the measurement findings out"
else fail=$((fail+1)); echo "FAIL --write-baseline does not say it left findings out"; sed 's/^/     /' "$ROOT/out.txt"; fi
expect "after --write-baseline the measurement finding is still reported" 1 "functionLength"

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
