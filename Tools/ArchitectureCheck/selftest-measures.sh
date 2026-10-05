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
regex_body() { printf 'func f() {\n    let r = #/\n%s\n    /#\n}\n' "$(lines_of "$1" '        part%d')"; }   # one token that spans every line of it
flag "functionLength: a token that spans lines, an extended regex literal, counts line by line" "$(regex_body 19)" "functionLength: func f has 21"
clean "functionLength: an extended regex literal of 20 lines" "$(regex_body 18)"
flag "functionLength: a regex literal is counted with its blank lines" "$(printf 'func f() {\n    let r = #/\n%s\n    /#\n}\n' "$(spaced 10)")" "functionLength: func f has 21"
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
flag "nestingDepth: reported on the line of the first construct over the limit" $'func f() {\n    if a {\n        for x in y {\n            if b {\n                while c { g() }\n            }\n        }\n    }\n}' "P.swift:4: CleanFunctions: nestingDepth: func f nests 4 levels"
flag "nestingDepth: reported once, at the first construct, however many are too deep" $'func f() {\n    if a {\n        for x in y {\n            if b { g() }\n            if c { g() }\n        }\n    }\n}' "P.swift:4: CleanFunctions: nestingDepth: func f nests 3 levels"
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
clean "cyclomaticComplexity: the operators of a compile-time condition are no decisions" $'func f() {\n#if DEBUG && FAST && SLOW && SMALL && TINY && LARGE\n    g()\n#elseif A || B || C || D || E || F\n    h()\n#endif\n}'
clean "cyclomaticComplexity: a negated and parenthesised compile-time condition is no decision" $'func f() {\n#if !(A && B) || (C && D && E && G)\n    g()\n#endif\n}'
flag "cyclomaticComplexity: the decisions inside a compile-time branch still count" "$(printf 'func f() {\n#if DEBUG && FAST\n%s\n#endif\n}\n' "$(lines_of 5 '    if x%d { g() }')")" "cyclomaticComplexity: func f has a cyclomatic complexity of 6"
flag "cyclomaticComplexity: every branch of a compile-time condition counts its decisions" "$(printf 'func f() {\n#if DEBUG\n%s\n#else\n%s\n#endif\n}\n' "$(lines_of 3 '    if x%d { g() }')" "$(lines_of 3 '    if y%d { h() }')")" "cyclomatic complexity of 7"
flag "cyclomaticComplexity: a runtime operator next to a compile-time one still counts" $'func f() -> Bool {\n#if DEBUG && FAST\n    return a && b && c && d && e && f\n#endif\n}' "cyclomatic complexity of 6"
flag "cyclomaticComplexity: a condition inside a nested compile-time branch still counts" $'func f() -> Bool {\n#if DEBUG\n#if FAST && SLOW\n    return a && b && c && d && e && f\n#endif\n#endif\n}' "cyclomatic complexity of 6"
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
clean "parameterCount: an initialiser that passes its parameters unchanged is a data initialiser" $'final class S {\n    let a: Int, b: Int, c: Int, d: Int\n    init(a: Int, b: Int, c: Int, d: Int) { self.a = a; self.b = b; self.c = c; self.d = d }\n    convenience init(origin a: Int, b: Int, c: Int, d: Int) { self.init(a: a, b: b, c: c, d: d) }\n}'
flag "parameterCount: a delegating initialiser that changes a parameter" $'final class S {\n    convenience init(a: Int, b: Int, c: Int, d: Int) { self.init(a: a, b: b, c: c, d: d + 1) }\n}' "parameterCount: init takes 4"
flag "parameterCount: a delegating initialiser that drops a parameter" $'final class S {\n    convenience init(a: Int, b: Int, c: Int, d: Int) { self.init(a: a, b: b, c: c) }\n}' "parameterCount: init takes 4"
# A data initialiser may also give the other properties a literal or a constant, and pass literals and constants on.
data_init() {   # $1 = name, $2 = clean or flag, $3 = the body of an initialiser of four parameters, $4 = what precedes the type
  local src; src="$(printf '%s\nstruct S {\n    let a: Int, b: Int, c: Int, d: Int\n    var e, f, g: Any?\n    init(a: Int, b: Int, c: Int, d: Int) { %s }\n}\n' "${4:-}" "$3")"
  if [[ "$2" == clean ]]; then clean "parameterCount: $1" "$src"; else flag "parameterCount: $1" "$src" "parameterCount: init takes 4"; fi
}
delegating_init() {   # the same, for a convenience initialiser that delegates to the designated one, a data initialiser
  local src; src="$(printf '%s\nfinal class S {\n    let a: Int, b: Int, c: Int, d: Int\n    var e, f, g: Any?\n    init(a: Int, b: Int, c: Int, d: Int, e: Any? = nil, f: Any? = nil, g: Any? = nil) {\n        self.a = a; self.b = b; self.c = c; self.d = d; self.e = e; self.f = f; self.g = g\n    }\n    convenience init(first a: Int, b: Int, c: Int, d: Int) { %s }\n}\n' "${4:-}" "$3")"
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
delegating_init "delegation: the parameters may go to other parameters of the callee, with literals between them" clean "self.init(a: d, b: c, c: b, d: a, e: 0, f: nil, g: [])"
delegating_init "delegation: the callee's parameters with a default value may be left out" clean "self.init(a: a, b: b, c: c, d: d, g: [])"
delegating_init "delegation: arguments whose labels are not the callee's are no delegation to it" flag "self.init(d: d, e: 0, c: c, f: nil, b: b, g: [], a: a)"
delegating_init "delegation: a file-level let is a constant" clean "self.init($PASS, e: limit)" "let limit = 9"
data_init "assignment: a computed value is behaviour" flag "$STORE; self.e = 1 + 2"
for value in 'Kind.currently' 'Kind.nowhere' '.mainStreet' 'Kind.defaults' '.sharedKey'; do
  data_init "assignment: $value does not name ambient state" clean "$STORE; self.e = $value"
done
for value in '.now' 'Date.now' 'Foundation.Date.now' '.shared' 'URLSession.shared' 'Self.shared' '.default' 'FileManager.default' '.current' 'Locale.current' \
             'Calendar.autoupdatingCurrent' '.main' 'Bundle.main' '.standard' 'UserDefaults.standard' 'makeDefault()' 'Foo()' '.make()' '.some(1)' 'Kind.make(1)' 'Kind.make(a:)' '"\(a)"' '[a]' '-a' 'a' 'a ?? 0' 'flag ? 1 : 2' 'defaults.limit' 'limit' 'Type.init' '[makeDefault()]' '["k": Foo()]'; do
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
delegating_init "delegation: a call of another type's initialiser is no delegation" flag "Other.init($PASS)"
delegating_init "delegation: a call of the superclass initialiser is no delegation" flag "super.init($PASS)"
delegating_init "delegation: a call of Self.init is no delegation" flag "Self.init($PASS)"
data_init "assignment: a dictionary whose key is a call is behaviour" flag "$STORE; self.e = [Foo(): 1]"
data_init "assignment: a dictionary whose key is a parameter is behaviour" flag "$STORE; self.e = [a: 1]"
data_init "assignment: a dictionary whose value is a call is behaviour" flag "$STORE; self.e = [\"k\": Foo()]"
data_init "assignment: a dictionary of literals is a constant" clean "$STORE; self.e = [\"k\": 1, \"j\": 2]"
data_init "assignment: a dictionary with a constant key and a constant value" clean "$STORE; self.e = [Kind.empty: .none]"
delegating_init "delegation: a second statement" flag "self.init($PASS, e: 0); register()"
delegating_init "delegation: a name that a parameter shares with a file-level let is the parameter" flag "self.init(a: a, b: b, c: c, d: a)" "let a = 1"
clean "parameterCount: the parameters of a closure are not counted" 'let f: (Int, Int, Int, Int) -> Void = { a, b, c, d in }'

# A data initialiser assigns stored properties that the file declares (ADR 0021 (c)). These fixtures are Swift that compiles
# (swiftc -typecheck, Swift 5 mode, with a second file for a type that the fixture's file does not declare), so a case
# cannot pass for a reason that is a typo. SELFTEST_TYPECHECK=0 skips the compiling, and so does a machine without swiftc.
compiles() {   # $1 = name, $2 = source, $3 = the other file of the module, if any
  command -v swiftc > /dev/null && [[ "${SELFTEST_TYPECHECK:-1}" != 0 ]] || return 0
  local dir files; dir="$(mktemp -d)"; ROOTS+=("$dir"); files=("$dir/Fixture.swift"); printf '%s\n' "$2" > "$dir/Fixture.swift"
  if [[ -n "${3:-}" ]]; then printf '%s\n' "$3" > "$dir/Context.swift"; files+=("$dir/Context.swift"); fi
  if swiftc -typecheck -swift-version 5 -parse-as-library "${files[@]}" > "$dir/out.txt" 2>&1; then pass=$((pass+1)); echo "ok   compiles: $1"
  else fail=$((fail+1)); echo "FAIL the fixture of '$1' does not compile"; sed 's/^/     /' "$dir/out.txt"; fi
}
typed() {   # $1 = name, $2 = clean or flag, $3 = source, $4 = the other file of the module, if any, $5 = what a finding says
  compiles "$1" "$3" "${4:-}"
  if [[ "$2" == clean ]]; then clean "parameterCount: $1" "$3"; else flag "parameterCount: $1" "$3" "${5:-parameterCount: init takes 4}"; fi
}
INIT4='init(a: Int, b: Int, c: Int, d: Int) { self.a = a; self.b = b; self.c = c; self.d = d }'
NL=$'\n'
STORAGE='    private var storage = [0, 0, 0, 0]'
computed() { printf '    var %s: Int { get { storage[%d] } set { storage[%d] = newValue } }\n' "$1" "$2" "$2"; }   # $1 = name, $2 = index
typed "destinations: stored properties of the type" clean $'struct S {\n    let a: Int, b: Int, c: Int, d: Int\n    '"$INIT4"$'\n}'
typed "destinations: stored properties, a computed one beside them that is not assigned" clean $'struct S {\n    let a: Int, b: Int, c: Int, d: Int\n    var sum: Int { a + b + c + d }\n    '"$INIT4"$'\n}'
typed "destinations: every one computed, whose setters do work" flag "struct S {${NL}$STORAGE${NL}$(computed a 0)${NL}$(computed b 1)${NL}$(computed c 2)${NL}$(computed d 3)${NL}    $INIT4${NL}}"
typed "destinations: one of four computed" flag "struct S {${NL}    let a: Int, b: Int, c: Int${NL}$STORAGE${NL}$(computed d 3)${NL}    $INIT4${NL}}"
typed "destinations: a computed one declared in an extension" flag "struct S {${NL}    let a: Int, b: Int, c: Int${NL}$STORAGE${NL}    $INIT4${NL}}${NL}extension S {${NL}$(computed d 3)${NL}}"
typed "destinations: a computed property with a getter only is no destination either" flag $'struct S {\n    let a: Int, b: Int, c: Int\n    var d: Int { 0 }\n    init(a: Int, b: Int, c: Int, d: Int) { self.a = a; self.b = b; self.c = c }\n}'
typed "destinations: a static property is no instance's" flag $'struct S {\n    static var d = 0\n    let a: Int, b: Int, c: Int\n    init(a: Int, b: Int, c: Int, d: Int) { self.a = a; self.b = b; self.c = c; Self.d = d }\n}'
typed "destinations: a class property is no instance's" flag $'class S {\n    class var d: Int { 0 }\n    let a: Int, b: Int, c: Int\n    init(a: Int, b: Int, c: Int, d: Int) { self.a = a; self.b = b; self.c = c }\n}'
typed "destinations: properties of a type that another file declares are not found" flag \
  $'extension S {\n    init(_ a: Int, _ b: Int, _ c: Int, _ d: Int) { self.a = a; self.b = b; self.c = c; self.d = d }\n}' \
  $'struct S { var a = 0, b = 0, c = 0, d = 0 }'
typed "destinations: the extended type is declared in this file, so its properties are found" clean \
  $'struct S {\n    let a: Int, b: Int, c: Int, d: Int\n}\nextension S {\n    init(_ a: Int, _ b: Int, _ c: Int, _ d: Int) { self.a = a; self.b = b; self.c = c; self.d = d }\n}'
typed "destinations: the extension may come before the type" clean \
  $'extension S {\n    init(_ a: Int, _ b: Int, _ c: Int, _ d: Int) { self.a = a; self.b = b; self.c = c; self.d = d }\n}\nstruct S {\n    let a: Int, b: Int, c: Int, d: Int\n}'
typed "destinations: a property with observers stores, since the type's own observers do not run in its initialiser" clean \
  $'struct S {\n    var count = 0\n    var a: Int { willSet { count += 1 } }\n    var b: Int { didSet { count += 1 } }\n    var c: Int { willSet { count += 1 } didSet { count += 2 } }\n    var d: Int { didSet { count += 1 } }\n    '"$INIT4"$'\n}'
typed "destinations: a property with a getter and an observer is computed" flag $'struct S {\n    let a: Int, b: Int, c: Int\n    var d: Int { get { 0 } set { } }\n    '"$INIT4"$'\n}'
typed "destinations: a property declared in a #if branch is found" clean $'struct S {\n    let a: Int, b: Int, c: Int\n#if DEBUG\n    let d: Int\n#else\n    let d: Int\n#endif\n    '"$INIT4"$'\n}'
typed "destinations: a nested type has its own properties" clean $'struct Outer {\n    struct S {\n        let a: Int, b: Int, c: Int, d: Int\n        '"$INIT4"$'\n    }\n}'
typed "destinations: the properties of an enclosing type are not the nested type's" flag $'struct Outer {\n    let a: Int, b: Int, c: Int, d: Int\n    struct S {\n        let a: Int, b: Int, c: Int\n        init(a: Int, b: Int, c: Int, d: Int) { self.a = a; self.b = b; self.c = c }\n    }\n}'
typed "destinations: a static property that shares a name with an instance property is not the instance's" clean $'struct S {\n    static var d: Int { 0 }\n    let a: Int, b: Int, c: Int, d: Int\n    '"$INIT4"$'\n}'
typed "destinations: two types of one name in different scopes are one name, and a computed property in either is no destination" flag \
  $'struct A {\n    struct S {\n        let a: Int, b: Int, c: Int, d: Int\n    }\n}\nstruct B {\n    struct S {\n        let a: Int, b: Int, c: Int\n        private var storage = 0\n        var d: Int { get { storage } set { storage = newValue } }\n        '"$INIT4"$'\n    }\n}'
# Not Swift that compiles: a getter-only property cannot be assigned, but the checker must not call it stored all the same.
flag "destinations: a property with only a getter is not stored" $'struct S {\n    let a: Int, b: Int, c: Int\n    var d: Int { 0 }\n    '"$INIT4"$'\n}' "parameterCount: init takes 4"
# A delegation has to reach a data initialiser that the file declares for the same type.
DELEGATE4='init(a: Int, b: Int, c: Int, d: Int) { self.init(values: a, b, c, d) }'
STORING='init(first a: Int, b: Int, c: Int, d: Int) { self.a = a; self.b = b; self.c = c; self.d = d }'
FIELDS='    let a: Int, b: Int, c: Int, d: Int'
typed "delegation: to a designated initialiser that stores" clean "struct S {${NL}$FIELDS${NL}    $STORING${NL}    init(a: Int, b: Int, c: Int, d: Int) { self.init(first: a, b: b, c: c, d: d) }${NL}}"
typed "delegation: to a chain of initialisers that ends in one that stores" clean "struct S {${NL}$FIELDS${NL}    $STORING${NL}    init(second a: Int, b: Int, c: Int, d: Int) { self.init(first: a, b: b, c: c, d: d) }${NL}    init(a: Int, b: Int, c: Int, d: Int) { self.init(second: a, b: b, c: c, d: d) }${NL}}"
typed "delegation: from an extension to an initialiser of the type, which the file declares" clean "struct S {${NL}$FIELDS${NL}    $STORING${NL}}${NL}extension S {${NL}    init(a: Int, b: Int, c: Int, d: Int) { self.init(first: a, b: b, c: c, d: d) }${NL}}"
typed "delegation: to an initialiser declared in an extension" clean "struct S {${NL}$FIELDS${NL}}${NL}extension S {${NL}    $STORING${NL}    init(second a: Int, b: Int, c: Int, d: Int) { self.init(first: a, b: b, c: c, d: d) }${NL}}"
typed "delegation: to a variadic initialiser that computes" flag "struct S {${NL}    var total = 0${NL}    init(values: Int...) { total = values.reduce(0, +) }${NL}    $DELEGATE4${NL}}"
typed "delegation: to a variadic initialiser that only stores" flag "struct S {${NL}    var values: [Int]${NL}    init(values: Int...) { self.values = values }${NL}    $DELEGATE4${NL}}"
typed "delegation: to an initialiser that computes" flag "struct S {${NL}    var sum = 0${NL}    init(first a: Int, b: Int, c: Int, d: Int) { sum = a + b + c + d }${NL}    init(a: Int, b: Int, c: Int, d: Int) { self.init(first: a, b: b, c: c, d: d) }${NL}}"
typed "delegation: to an initialiser that assigns a computed property" flag "struct S {${NL}$STORAGE${NL}$(computed a 0)${NL}$(computed b 1)${NL}$(computed c 2)${NL}$(computed d 3)${NL}    $STORING${NL}    init(a: Int, b: Int, c: Int, d: Int) { self.init(first: a, b: b, c: c, d: d) }${NL}}"
typed "delegation: when one of the initialisers it can mean computes, the caller is no data initialiser" flag "struct S {${NL}$FIELDS${NL}    $STORING${NL}    init(first a: Double, b: Int, c: Int, d: Int) { self.a = Int(a); self.b = b; self.c = c; self.d = d }${NL}    init(a: Int, b: Int, c: Int, d: Int) { self.init(first: a, b: b, c: c, d: d) }${NL}}" "" "P.swift:5: CleanFunctions: parameterCount: init takes 4"
typed "delegation: to a variadic parameter that one argument fills" flag "struct S {${NL}    let a: Int, b: Int, c: Int, ds: [Int]${NL}    init(a: Int, b: Int, c: Int, ds: Int...) { self.a = a; self.b = b; self.c = c; self.ds = ds }${NL}    init(a: Int, b: Int, c: Int, d: Int) { self.init(a: a, b: b, c: c, ds: d) }${NL}}" "" "P.swift:4: CleanFunctions: parameterCount: init takes 4"
typed "delegation: to an initialiser of a type that another file declares" flag \
  $'extension S {\n    init(_ a: Int, _ b: Int, _ c: Int, _ d: Int) { self.init(first: a, b: b, c: c, d: d) }\n}' \
  $'struct S {\n    let a: Int, b: Int, c: Int, d: Int\n    init(first a: Int, b: Int, c: Int, d: Int) { self.a = a; self.b = b; self.c = c; self.d = d }\n}'
typed "delegation: to the memberwise initialiser, which the file does not declare" flag "struct S {${NL}$FIELDS${NL}}${NL}extension S {${NL}    init(_ a: Int, _ b: Int, _ c: Int, _ d: Int) { self.init(a: a, b: b, c: c, d: d) }${NL}}"
# Not Swift that compiles, which is the point: a call that no declaration answers cannot be resolved.
flag "delegation: to an initialiser that nothing declares" "struct S {${NL}$FIELDS${NL}    $STORING${NL}    init(a: Int, b: Int, c: Int, d: Int) { self.init(first: a, b: b, c: c, d: d) }${NL}    init(_ a: Int, _ b: Int, _ c: Int, _ d: Int) { self.init(a: a, b: b, c: c, d: d, e: 0) }${NL}}" "parameterCount: init takes 4"
# A variadic parameter fits any number of arguments, and an initialiser with one is never a data initialiser, so a call that
# a variadic overload can take is not exempt, whatever else it can mean.
typed "variadic: an initialiser with a variadic parameter is no data initialiser, though it only stores" flag "struct S {${NL}    let a: Int, b: Int, c: Int, values: [Int]${NL}    init(a: Int, b: Int, c: Int, values: Int...) { self.a = a; self.b = b; self.c = c; self.values = values }${NL}}"
typed "variadic: a delegation that a variadic overload can take is not exempt, beside the data initialiser it can also mean" flag "struct V {${NL}$FIELDS${NL}    init(_ a: Int, _ b: Int, _ c: Int, _ d: Int) { self.a = a; self.b = b; self.c = c; self.d = d }${NL}    init(_ values: String...) { a = Int(values[0]) ?? 0; b = Int(values[1]) ?? 0; c = Int(values[2]) ?? 0; d = Int(values[3]) ?? 0 }${NL}    init(text a: String, _ b: String, _ c: String, _ d: String) { self.init(a, b, c, d) }${NL}}" "" "P.swift:5: CleanFunctions: parameterCount: init takes 4"
typed "variadic: a variadic parameter that the call leaves out still fits" flag "struct W {${NL}$FIELDS${NL}    $INIT4${NL}    init(a: Int, b: Int, c: Int, d: Int, rest: Int...) { self.init(a: a, b: b, c: c, d: d) }${NL}    init(first a: Int, b: Int, c: Int, d: Int) { self.init(a: a, b: b, c: c, d: d) }${NL}}" "" "P.swift:5: CleanFunctions: parameterCount: init takes 4"
typed "variadic: a delegation to a variadic overload that the labels fit, with several arguments" flag "struct W {${NL}    var values: [Int]${NL}    init(_ values: Int...) { self.values = values }${NL}    init(a: Int, b: Int, c: Int, d: Int) { self.init(a, b, c, d) }${NL}}" "" "P.swift:4: CleanFunctions: parameterCount: init takes 4"
typed "variadic: the delegation is exempt when no variadic overload can take it" clean "struct W {${NL}$FIELDS${NL}    $STORING${NL}    init(other: Int, values: Int...) { self.init(first: other, b: 0, c: 0, d: 0) }${NL}    init(a: Int, b: Int, c: Int, d: Int) { self.init(first: a, b: b, c: c, d: d) }${NL}}"
# The search is bounded by counted work, not by time: each initialiser is examined once, a delegation that comes back to it is a
# cycle, the labels of a call are matched against the parameters in one pass, and a file whose search spends more than the
# budget (--search-steps, a million by default) reports it and exempts nothing. A file built to blow the search up still ends.
fan() {   # $1 = n: n initialisers, each with one parameter more than the last and delegating to the next, the last one storing
  local i j args params
  printf 'struct Fan {\n    var '; for ((i = 1; i <= $1; i++)); do printf 'l%d: Int%s' "$i" "$([[ $i -lt $1 ]] && printf ', ')"; done; printf '\n'
  for ((i = 1; i < $1; i++)); do
    params=""; args=""
    for ((j = 1; j <= i; j++)); do params+="l$j: Int = 0, "; args+="l$j: l$j, "; done
    printf '    init(%s) { self.init(%sl%d: 0) }\n' "${params%, }" "$args" "$((i + 1))"
  done
  params=""; args=""
  for ((j = 1; j <= $1; j++)); do params+="l$j: Int = 0, "; args+="self.l$j = l$j; "; done
  printf '    init(%s) { %s}\n}\n' "${params%, }" "$args"
}
unlabeled() {   # $1 = n: an initialiser of n defaulted unlabeled parameters, a variadic one, and one of n + 1 that delegates
  local i params args xs
  params=""; args=""; xs=""
  for ((i = 1; i <= $1; i++)); do params+="_ a$i: Int = 0, "; args+="a$i, "; done
  local calls=""; for ((i = 1; i <= $1 + 1; i++)); do xs+="x$i: Int, "; calls+="x$i, "; done
  printf 'struct U {\n    var values: [Int] = []\n    init(_ values: Int...) { self.values = values }\n    init(%s) { self.values = [%s] }\n    init(%s) { self.init(%s) }\n}\n' "${params%, }" "${args%, }" "${xs%, }" "${calls%, }"
}
setup; src "$(fan 20)"; expect "search: twenty overloads that each delegate to the next, all data initialisers, finish within the budget" 0 ""
setup; src "$(fan 20)"; expect "search: the same file with a budget of 100 steps is reported, and nothing in it is exempt" 1 "the search for data initialisers stopped at its budget of 100 steps" --search-steps 100
setup; src "$(fan 20)"; expect "search: a budget that is spent leaves the initialisers it reached as findings" 1 "init takes 19 parameters" --search-steps 100
setup; src "$(unlabeled 24)"; expect "search: twenty-four defaulted unlabeled parameters and a variadic overload are matched in one pass" 1 "init takes 25 parameters"
setup; src "$(unlabeled 24)"; got=$(run)
if grep -q "stopped at its budget" "$ROOT/out.txt"; then fail=$((fail+1)); echo "FAIL search: the unlabeled parameters spent the whole budget"; else pass=$((pass+1)); echo "ok   search: the unlabeled parameters stay within the budget"; fi
setup; src $'struct S {\n    let a: Int, b: Int, c: Int\n    init(a: Int, b: Int, c: Int) { self.a = a; self.b = b; self.c = c }\n}'; expect "search: an initialiser within the parameter cap is not searched, so it spends nothing" 0 "" --search-steps 0
setup; src "$(fan 20)"; got=$(run --search-steps 1000000)
if [[ "$got" == 0 ]]; then pass=$((pass+1)); echo "ok   search: the default budget is a million steps"; else fail=$((fail+1)); echo "FAIL search: the default budget"; fi
# The default values of an initialiser are part of it: they run each time a call leaves the argument out, so each has to be a
# literal or a constant, as the values it stores are, and so do the defaults of the initialiser that a delegation reaches.
typed "defaults: values that run code are behaviour, however plainly the initialiser stores them" flag "import Foundation${NL}struct Stamped {${NL}    let id: UUID, at: Date, b: Int, c: Int${NL}    init(id: UUID = UUID(), at: Date = Date(), b: Int, c: Int) { self.id = id; self.at = at; self.b = b; self.c = c }${NL}}"
typed "defaults: literals are constants" clean "struct S {${NL}    let a: Int, b: String, c: [Int], d: Double?${NL}    init(a: Int = 0, b: String = \"\", c: [Int] = [], d: Double? = nil) { self.a = a; self.b = b; self.c = c; self.d = d }${NL}}"
typed "defaults: negative numbers, booleans and dictionaries are constants" clean "struct S {${NL}    let a: Int, b: Bool, c: [String: Int], d: Double${NL}    init(a: Int = -1, b: Bool = true, c: [String: Int] = [:], d: Double = 1.5) { self.a = a; self.b = b; self.c = c; self.d = d }${NL}}"
typed "defaults: an enum case, a static constant and a file-level let are constants" clean "let limit = 9${NL}enum Kind { case none, some${NL}    static let fallback = Kind.some }${NL}struct S {${NL}    let a: Int, b: Kind, c: Kind, d: Kind${NL}    init(a: Int = limit, b: Kind = .none, c: Kind = Kind.some, d: Kind = Kind.fallback) { self.a = a; self.b = b; self.c = c; self.d = d }${NL}}"
typed "defaults: a call is behaviour" flag "func fresh() -> Int { 1 }${NL}struct S {${NL}    let a: Int, b: Int, c: Int, d: Int${NL}    init(a: Int = fresh(), b: Int, c: Int, d: Int) { self.a = a; self.b = b; self.c = c; self.d = d }${NL}}" "" "P.swift:4: CleanFunctions: parameterCount: init takes 4"
typed "defaults: an operator is behaviour" flag "struct S {${NL}    let a: Int, b: Int, c: Int, d: Int${NL}    init(a: Int, b: Int = 1 + 2, c: Int, d: Int) { self.a = a; self.b = b; self.c = c; self.d = d }${NL}}"
typed "defaults: the clock is ambient, whatever its spelling" flag "import Foundation${NL}struct S {${NL}    let a: Int, b: Int, c: Int, d: Date${NL}    init(a: Int, b: Int, c: Int, d: Date = .now) { self.a = a; self.b = b; self.c = c; self.d = d }${NL}}"
typed "defaults: a default that is not a constant makes the delegation that leaves it out no data initialiser" flag "import Foundation${NL}struct S {${NL}    let a: Int, b: Int, c: Int, d: Int, e: Date${NL}    init(first a: Int, b: Int, c: Int, d: Int, e: Date = Date()) { self.a = a; self.b = b; self.c = c; self.d = d; self.e = e }${NL}    init(a: Int, b: Int, c: Int, d: Int) { self.init(first: a, b: b, c: c, d: d) }${NL}}" "" "P.swift:5: CleanFunctions: parameterCount: init takes 4"
typed "defaults: constant defaults on the initialiser that a delegation reaches keep it exempt" clean "struct S {${NL}    let a: Int, b: Int, c: Int, d: Int, e: [Int]${NL}    init(first a: Int, b: Int, c: Int, d: Int, e: [Int] = []) { self.a = a; self.b = b; self.c = c; self.d = d; self.e = e }${NL}    init(a: Int, b: Int, c: Int, d: Int) { self.init(first: a, b: b, c: c, d: d) }${NL}}"
typed "defaults: a default that a delegation passes explicitly still has to be a constant on the callee" flag "import Foundation${NL}struct S {${NL}    let a: Int, b: Int, c: Int, d: Int, e: Date${NL}    init(first a: Int, b: Int, c: Int, d: Int, e: Date = Date()) { self.a = a; self.b = b; self.c = c; self.d = d; self.e = e }${NL}    init(a: Int, b: Int, c: Int, d: Int, e: Date) { self.init(first: a, b: b, c: c, d: d, e: e) }${NL}}" "" "P.swift:5: CleanFunctions: parameterCount: init takes 5"
typed "defaults: an initialiser with no default values is unaffected" clean "struct S {${NL}    let a: Int, b: Int, c: Int, d: Int${NL}    $INIT4${NL}}"
# Known limit, stated in ADR 0021 and the README: resolution is per file, so an overload that another file declares is not seen.
# The delegation below can mean the overload of Q.swift at compile time, which computes; the checker sees only the one in P.swift.
# Review is the backstop for it.
setup; src $'struct Over {\n    var a: Int, b: Int, c: Int, d: Int\n    init(a: Int, b: Int, c: Int, d: Int) { self.a = a; self.b = b; self.c = c; self.d = d }\n    init(text: String, b: String, c: Int, d: Int) { self.init(a: text, b: b, c: c, d: d) }\n}'
printf '%s\n' 'extension Over {' '    init(a: String, b: String, c: Int, d: Int) { self.init(a: Int(a) ?? 0, b: Int(b) ?? 0, c: c, d: d); register() }' '}' > "$ROOT/Sources/Pure/Q.swift"
got=$(run)
if [[ "$got" == 1 ]] && grep -q "Q.swift:2: CleanFunctions: parameterCount" "$ROOT/out.txt" && ! grep -q "P.swift" "$ROOT/out.txt"; then pass=$((pass+1)); echo "ok   known limit: an overload declared in another file is not seen, and the extension that declares it is not resolved"
else fail=$((fail+1)); echo "FAIL known limit: an overload in another file"; sed 's/^/     /' "$ROOT/out.txt"; fi
# Not Swift that compiles: the call leaves out a parameter that has no default value.
flag "delegation: to an initialiser that needs an argument the call leaves out" "struct S {${NL}    let a: Int, b: Int, c: Int, d: Int, e: Int${NL}    init(a: Int, b: Int, c: Int, d: Int, e: Int) { self.a = a; self.b = b; self.c = c; self.d = d; self.e = e }${NL}    init(first a: Int, b: Int, c: Int, d: Int) { self.init(a: a, b: b, c: c, d: d) }${NL}}" "P.swift:4: CleanFunctions: parameterCount: init takes 4"
# A cycle is not Swift that compiles, which is the point: the checker has to end on it.
flag "delegation: two initialisers that delegate to each other end the check and are no data initialisers" "struct S {${NL}$FIELDS${NL}    init(a: Int, b: Int, c: Int, d: Int) { self.init(first: a, b: b, c: c, d: d) }${NL}    init(first a: Int, b: Int, c: Int, d: Int) { self.init(a: a, b: b, c: c, d: d) }${NL}}" "parameterCount: init takes 4"
flag "delegation: an initialiser that delegates to itself ends the check and is no data initialiser" "struct S {${NL}$FIELDS${NL}    init(a: Int, b: Int, c: Int, d: Int) { self.init(a: a, b: b, c: c, d: d) }${NL}}" "parameterCount: init takes 4"
flag "delegation: a cycle of three" "struct S {${NL}$FIELDS${NL}    init(a: Int, b: Int, c: Int, d: Int) { self.init(first: a, b: b, c: c, d: d) }${NL}    init(first a: Int, b: Int, c: Int, d: Int) { self.init(second: a, b: b, c: c, d: d) }${NL}    init(second a: Int, b: Int, c: Int, d: Int) { self.init(a: a, b: b, c: c, d: d) }${NL}}" "parameterCount: init takes 4"
# A property with an attribute is not stored, whatever the attribute: a property wrapper runs code on every assignment, a macro can
# rewrite the property, and syntax cannot tell either from @MainActor or @available.
WRAPPER=$'@propertyWrapper\nstruct Clamped {\n    private var value: Int\n    init(wrappedValue: Int) { value = max(0, wrappedValue) }\n    var wrappedValue: Int { get { value } set { value = max(0, newValue) } }\n}'
typed "attributes: a property wrapper on a destination runs code, so it is no destination" flag "$WRAPPER${NL}struct S {${NL}    @Clamped var a: Int${NL}    let b: Int, c: Int, d: Int${NL}    $INIT4${NL}}"
typed "attributes: the same type without the wrapper stores" clean "struct S {${NL}    var a: Int${NL}    let b: Int, c: Int, d: Int${NL}    $INIT4${NL}}"
typed "attributes: a wrapper on every destination" flag "$WRAPPER${NL}struct S {${NL}    @Clamped var a: Int${NL}    @Clamped var b: Int${NL}    @Clamped var c: Int${NL}    @Clamped var d: Int${NL}    $INIT4${NL}}"
typed "attributes: an attribute that is no wrapper counts all the same" flag "struct S {${NL}    let a: Int, b: Int, c: Int${NL}    @usableFromInline var d: Int${NL}    $INIT4${NL}}"
typed "attributes: an actor isolation counts" flag "struct S {${NL}    let a: Int, b: Int, c: Int${NL}    @MainActor var d: Int${NL}    @MainActor $INIT4${NL}}"
typed "attributes: an attribute with arguments, on its own line" flag "struct S {${NL}    let a: Int, b: Int, c: Int${NL}    @_documentation(visibility: private)${NL}    var d: Int${NL}    $INIT4${NL}}"
typed "attributes: a wrapper on a property that the initialiser does not assign is no matter" clean "$WRAPPER${NL}struct S {${NL}    @Clamped var extra = 0${NL}    let a: Int, b: Int, c: Int, d: Int${NL}    $INIT4${NL}}"
typed "attributes: an attribute on the type is no matter" clean "@MainActor${NL}struct S {${NL}    let a: Int, b: Int, c: Int, d: Int${NL}    $INIT4${NL}}"
typed "attributes: an attribute on the initialiser is no matter" clean "struct S {${NL}    let a: Int, b: Int, c: Int, d: Int${NL}    @inlinable $INIT4${NL}}"
typed "attributes: a delegation to an initialiser that assigns a wrapped property" flag "$WRAPPER${NL}struct S {${NL}    @Clamped var a: Int${NL}    let b: Int, c: Int, d: Int${NL}    init(first a: Int, b: Int, c: Int, d: Int) { self.a = a; self.b = b; self.c = c; self.d = d }${NL}    init(a: Int, b: Int, c: Int, d: Int) { self.init(first: a, b: b, c: c, d: d) }${NL}}" "" "P.swift:10: CleanFunctions: parameterCount: init takes 4"
# A type is found by its full path in the file, `Outer.Inner`, and an extension names the path it extends. A path that no single
# declaration answers gives no exemption.
TRACKED=$'protocol Tracked { var a: Int { get set }; var b: Int { get set }; var c: Int { get set }; var d: Int { get set } }\nextension Tracked {\n    var a: Int { get { 0 } set { _ = newValue } }\n    var b: Int { get { 0 } set { _ = newValue } }\n    var c: Int { get { 0 } set { _ = newValue } }\n    var d: Int { get { 0 } set { _ = newValue } }\n}'
typed "paths: a type of the same name elsewhere does not license an assignment whose property a protocol extension computes" flag "$TRACKED${NL}enum First {${NL}    struct Record { var a: Int, b: Int, c: Int, d: Int }${NL}}${NL}enum Second {${NL}    struct Record: Tracked {${NL}        $INIT4${NL}    }${NL}}" "" "P.swift:13: CleanFunctions: parameterCount: init takes 4"
typed "paths: two types of one name in different scopes each find their own properties" clean "enum First {${NL}    struct Record {${NL}        let a: Int, b: Int, c: Int, d: Int${NL}        $INIT4${NL}    }${NL}}${NL}enum Second {${NL}    struct Record {${NL}        var a: Int, b: Int, c: Int, d: Int${NL}        $INIT4${NL}    }${NL}}"
typed "paths: an extension names its path, and finds the properties of that type only" flag "enum First {${NL}    struct Record { let a: Int, b: Int, c: Int, d: Int }${NL}}${NL}enum Second {${NL}    struct Record {${NL}        var a: Int, b: Int, c: Int${NL}        var d: Int { get { 0 } set { _ = newValue } }${NL}    }${NL}}${NL}extension Second.Record {${NL}    $INIT4${NL}}" "" "P.swift:11: CleanFunctions: parameterCount: init takes 4"
typed "paths: an extension of the other type of that name finds that type's properties" clean "enum First {${NL}    struct Record { let a: Int, b: Int, c: Int, d: Int }${NL}}${NL}enum Second {${NL}    struct Record {${NL}        var a: Int, b: Int, c: Int${NL}        var d: Int { get { 0 } set { _ = newValue } }${NL}    }${NL}}${NL}extension First.Record {${NL}    init(_ a: Int, _ b: Int, _ c: Int, _ d: Int) { self.a = a; self.b = b; self.c = c; self.d = d }${NL}}"
typed "paths: a simple name reaches the top-level type, not a nested one of that name" clean "struct Record { let a: Int, b: Int, c: Int, d: Int }${NL}enum First {${NL}    struct Record { let a: Int, b: Int, c: Int }${NL}}${NL}extension Record {${NL}    init(_ a: Int, _ b: Int, _ c: Int, _ d: Int) { self.a = a; self.b = b; self.c = c; self.d = d }${NL}}"
typed "paths: a type nested in an extension has the path of the extended type and its own name" clean "struct Outer {}${NL}extension Outer {${NL}    struct Inner {${NL}        let a: Int, b: Int, c: Int, d: Int${NL}        $INIT4${NL}    }${NL}}${NL}extension Outer.Inner {${NL}    init(_ a: Int, _ b: Int, _ c: Int, _ d: Int) { self.init(a: a, b: b, c: c, d: d) }${NL}}"
typed "paths: two declarations of one path, in the branches of a #if, are not one type" flag "#if DEBUG${NL}struct S {${NL}    let a: Int, b: Int, c: Int, d: Int${NL}    $INIT4${NL}}${NL}#else${NL}struct S {${NL}    let a: Int, b: Int, c: Int, d: Int${NL}    $INIT4${NL}}${NL}#endif"
typed "paths: a type declared inside a function is found by itself" clean "func make() -> Int {${NL}    struct Local {${NL}        let a: Int, b: Int, c: Int, d: Int${NL}        $INIT4${NL}    }${NL}    return Local(a: 1, b: 2, c: 3, d: 4).a${NL}}"
typed "paths: two local types of one name in different functions are two types" clean "func first() -> Int {${NL}    struct Local {${NL}        let a: Int, b: Int, c: Int, d: Int${NL}        $INIT4${NL}    }${NL}    return Local(a: 1, b: 2, c: 3, d: 4).a${NL}}${NL}func second() -> Int {${NL}    struct Local {${NL}        let a: Int, b: Int, c: Int, d: Int${NL}        $INIT4${NL}    }${NL}    return Local(a: 1, b: 2, c: 3, d: 4).b${NL}}"
typed "destinations: a class stores in its own properties" clean $'final class S {\n    let a: Int, b: Int, c: Int, d: Int\n    '"$INIT4"$'\n}'

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
for form in "/** ${R}5 */" $'/**\n * The domain\n * ('"${R}2"$').\n */' "/*! ${R}9 */" "/// ${R}11" $'/* open\n   '"${R}12"$' */' "func f() {} // ${R}13"; do
  flag "ruleNumberCitation: ${form//$'\n'/⏎}" "$form" "CleanComments: ruleNumberCitation"
done
flag "ruleNumberCitation: reported on the line of a documentation block" $'let a = 1\n/**\n * Text\n * '"${R}6"$'\n */\nlet b = 2' "P.swift:4: CleanComments: ruleNumberCitation"
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

# --- the policy: these rules apply to every production target by kind, and to no other (ADR 0021 (c))
kind_case() {   # $1 = the kind of the target that holds a function of 21 lines, "" for a production target
  setup; src 'let x = 1'
  if [[ -n "$1" ]]; then python3 - "$ROOT/rules.json" "$1" <<'PYJ'
import json, sys
p, kind = sys.argv[1:3]; r = json.load(open(p)); r["targets"][0]["kind"] = kind
json.dump(r, open(p, "w"))
PYJ
  fi
  printf '%s\n' "$(fn 21)" > "$ROOT/Sources/Pure/P.swift"
}
kind_case ""; expect "a production target is measured" 1 "functionLength"
setup; src 'let x = 1'; printf '%s\n' "$(fn 21)" > "$ROOT/Sources/Other/O.swift"
expect "a production target that lists no rule is measured all the same" 1 "Sources/Other/O.swift:1: CleanFunctions: functionLength"
setup; src 'let x = 1'; mkdir -p "$ROOT/Sources/Late"; printf '%s\n' "$(fn 21)" > "$ROOT/Sources/Late/L.swift"
python3 - "$ROOT/rules.json" <<'PYJ'
import json, sys
p = sys.argv[1]; r = json.load(open(p))
r["targets"].append({"name": "Late", "path": "Sources/Late", "allowedImports": ["Foundation"], "rules": []})
json.dump(r, open(p, "w"))
PYJ
expect "a target added later cannot forget the rules" 1 "Sources/Late/L.swift:1: CleanFunctions: functionLength"
for kind in test tool legacy excluded; do
  kind_case "$kind"; expect "a $kind target is not measured" 0 ""
done
setup; src 'let x = 1'; printf '%s\n' "$(fn 21)" >> "$ROOT/Package.swift"
expect "a manifest is not measured" 0 ""
kind_case ""; python3 - "$ROOT/rules.json" <<'PYJ'
import json, sys
p = sys.argv[1]; r = json.load(open(p)); r["targets"][0]["rules"] += ["CleanFunctions", "CleanTypes"]
json.dump(r, open(p, "w"))
PYJ
expect "a target that also lists a rule is measured once" 1 "functionLength"
if [[ "$(grep -c 'functionLength' "$ROOT/out.txt")" == 1 ]]; then pass=$((pass+1)); echo "ok   a rule listed by the target and by kind reports its finding once"
else fail=$((fail+1)); echo "FAIL a rule listed twice reports its finding twice"; sed 's/^/     /' "$ROOT/out.txt"; fi
kind_case ""; python3 - "$ROOT/rules.json" <<'PYJ'
import json, sys
p = sys.argv[1]; r = json.load(open(p)); r["productionRules"].append("NoSuchRule")
json.dump(r, open(p, "w"))
PYJ
expect "a production rule that rules.json does not define is a problem" 1 "production rule NoSuchRule, which rules.json does not define"
if python3 - "$HERE/rules.json" <<'PYJ'
import json, sys
r = json.load(open(sys.argv[1]))
sized = {"CleanFunctions", "CleanTypes", "CleanComments", "ISP"}
listed = [t["name"] for t in r["targets"] if sized & set(t["rules"])]
sys.exit(0 if sized <= set(r.get("productionRules", [])) and not listed else 1)
PYJ
then pass=$((pass+1)); echo "ok   rules.json: the size, shape and comment rules are held by kind, and no target lists them"
else fail=$((fail+1)); echo "FAIL rules.json: the size, shape and comment rules are not all production rules, or a target lists them"; fi
