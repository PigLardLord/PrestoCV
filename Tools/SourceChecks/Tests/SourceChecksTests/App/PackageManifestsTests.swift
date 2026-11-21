import Testing

// MARK: - Reading package manifests

/// The reader behind the release checks: what it does not follow must fail those checks, never shrink what they scan.
@Suite("Package manifests")
struct PackageManifestsTests {

    private func read(_ manifests: [String: String]) -> PackageManifests {
        PackageManifests(packages: manifests.keys.sorted()) { manifests[$0] ?? "" }
    }

    private func folded(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    // MARK: What it reads

    @Test("The reader of manifests follows names, aliases, paths, conditions and ignores comments and test targets")
    func theReaderOfManifestsReadsTheShapesTheManifestsUse() {
        let manifests = read(["P": """
            let logging = Target.Dependency.product(name: "Log", package: "Logs")
            var targets: [Target] = [
                .target(name: "A", dependencies: ["B", logging]),   // .target(name: "Hidden")
                .target(name: "B", dependencies: [
                    .product(name: "C", package: "Other", condition: .when(platforms: [.iOS])),
                ], path: "Sources/Elsewhere"),
                .testTarget(name: "ATests", dependencies: ["A"]),
            ]
            #if !os(Linux)
            products.append(.library(name: "Lib", targets: ["A", "B"]))
            #endif
            """])

        #expect(Set(manifests.targets.keys) == ["P/A", "P/B"])
        #expect(manifests.targets["P/A"]?.targets == ["B"])
        #expect(manifests.targets["P/A"]?.products == [.init(name: "Log", package: "Logs")])
        #expect(manifests.targets["P/B"]?.products == [.init(name: "C", package: "Other")])
        #expect(manifests.targets["P/B"]?.folder == "P/Sources/Elsewhere")
        #expect(manifests.targets["P/A"]?.folder == "P/Sources/A")
        #expect(manifests.products["P"]?["Lib"] == ["A", "B"])
        #expect(manifests.unreadable.isEmpty, "\(manifests.unreadable)")
    }

    @Test("Every form of the grammar, in one manifest, is read with nothing reported")
    func everyFormOfTheGrammarIsRead() {
        let manifests = read(["P": """
            // swift-tools-version: 6.1
            import PackageDescription

            // Two aliases, one of them typed
            let logging = Target.Dependency.product(name: "Log", package: "Logs")
            let trace: Target.Dependency = .product(name: "Trace", package: "Logs")

            var products: [Product] = [
                .library(name: "Lib", targets: ["A"]),
                // A comment inside a list
                .library(name: "Extra", targets: [
                    "B",
                ]),
            ]
            var dependencies: [Package.Dependency] = []
            var targets: [Target] = [
                .target(name: "A", dependencies: ["B", logging], resources: [.copy("Designs")]),
                .testTarget(name: "ATests", dependencies: ["A"], resources: [.copy("../../Docs/notes.md")]),
            ]

            #if os(Linux)
            targets.append(.target(name: "B", dependencies: [trace]))
            #elseif compiler(>=6.0) && canImport(Darwin)
            targets.append(.target(name: "B", dependencies: [trace]))
            #else
            products.append(.library(name: "Dynamic", type: .dynamic, targets: ["A"]))
            dependencies.append(.package(path: "../Logs"))
            dependencies += [.package(path: "../Other")]
            targets.append(.testTarget(name: "BTests", dependencies: ["B"]))
            #endif

            let package = Package(
                name: "P",
                platforms: [.iOS(.v17), .macOS(.v14)],
                products: products,
                dependencies: dependencies,
                targets: targets
            )
            """])

        #expect(manifests.unreadable.isEmpty, "\(manifests.unreadable)")
        #expect(Set(manifests.targets.keys) == ["P/A", "P/B"])
        #expect(manifests.targets["P/B"]?.folder == "P/Sources/B")
        #expect(manifests.targets["P/A"]?.targets == ["B"])
        #expect(manifests.targets["P/A"]?.products == [.init(name: "Log", package: "Logs")])
        #expect(manifests.targets["P/B"]?.products == [.init(name: "Trace", package: "Logs")])
        #expect(manifests.products["P"] == ["Lib": ["A"], "Extra": ["B"], "Dynamic": ["A"]])
    }

    @Test("A product, an alias and a library written over several lines are read as on one line")
    func declarationsOverSeveralLinesAreRead() {
        let manifests = read([
            "P": """
                let logging: Target.Dependency = .product(
                    name: "Log",
                    package: "Logs"
                )
                let trace = Target.Dependency.product(
                    name: "Trace", package: "Logs")
                let products: [Product] = [
                    .library(
                        name: "Lib",
                        type: .dynamic,
                        targets: [
                            "A",
                        ]
                    ),
                ]
                targets.append(.target(
                    name: "A",
                    dependencies: [
                        .product(
                            name: "Drafting",
                            package: "Other"
                        ),
                        logging, trace,
                    ]
                ))
                """,
            "Other": """
                products.append(.library(name: "Drafting", targets: ["D"]))
                targets.append(.target(name: "D"))
                """,
            "Logs": """
                let products: [Product] = [.library(name: "Log", targets: ["L"]), .library(name: "Trace", targets: ["L"])]
                targets.append(.target(name: "L"))
                """,
        ])

        let walk = manifests.reached(from: [.init(name: "Lib", package: "P")])

        #expect(manifests.products["P"]?["Lib"] == ["A"])
        #expect(manifests.targets["P/A"]?.products == [
            .init(name: "Drafting", package: "Other"), .init(name: "Log", package: "Logs"), .init(name: "Trace", package: "Logs"),
        ])
        #expect(Set(walk.targets.map(\.name)) == ["A", "D", "L"])
        #expect(walk.unresolved.isEmpty, "\(walk.unresolved)")
        #expect(manifests.unreadable.isEmpty, "\(manifests.unreadable)")
    }

    @Test("A dependency on a product no manifest declares is unresolved, not dropped")
    func aProductNoManifestDeclaresIsUnresolved() {
        let manifests = read(["P": """
            products.append(.library(name: "Lib", targets: ["A"]))
            targets.append(.target(name: "A", dependencies: [
                .product(
                    name: "Missing",
                    package: "Nowhere"
                ),
            ]))
            """])

        #expect(manifests.reached(from: [.init(name: "Lib", package: "P")]).unresolved == [.init(name: "Missing", package: "Nowhere")])
    }

    @Test("A target named as a dependency inside another declaration does not replace the target's own declaration")
    func aTargetNamedAsADependencyIsNotADeclaration() {
        let manifests = read(["P": """
            targets.append(.target(name: "A", dependencies: ["B"]))
            targets.append(.testTarget(name: "ATests", dependencies: [.target(name: "A"), .target(name: "Fixtures")]))
            targets.append(.target(name: "B"))
            """])

        #expect(Set(manifests.targets.keys) == ["P/A", "P/B"])
        #expect(manifests.targets["P/A"]?.targets == ["B"])
    }

    @Test("A target declared in both branches of a condition keeps the dependencies of both")
    func aTargetDeclaredTwiceKeepsBothDependencies() {
        let manifests = read(["P": """
            #if os(Linux)
            targets.append(.target(name: "A", dependencies: ["B", .product(name: "X", package: "Other")]))
            #else
            targets.append(.target(name: "A", dependencies: [
                "C", .target(name: "D", condition: .when(platforms: [.iOS])),
                .product(name: "Y", package: "Other"), .product(name: "X", package: "Other"),
            ]))
            #endif
            """])

        #expect(manifests.targets["P/A"]?.targets == ["B", "C", "D"])
        #expect(manifests.targets["P/A"]?.products == [.init(name: "X", package: "Other"), .init(name: "Y", package: "Other")])
        #expect(manifests.unreadable.isEmpty, "\(manifests.unreadable)")
    }

    @Test("A target declared at two folders is reported, as the scan cannot know which one ships")
    func aTargetDeclaredAtTwoFoldersIsReported() {
        let manifests = read(["P": """
            #if os(Linux)
            targets.append(.target(name: "A", path: "Sources/Linux"))
            #else
            targets.append(.target(name: "A"))
            #endif
            """])

        #expect(manifests.unreadable == ["P: A declared at P/Sources/Linux and at P/Sources/A"])
    }

    @Test("Declarations written inside Package(...) are read as those in a list before it")
    func declarationsInsideThePackageAreRead() {
        let manifests = read(["P": """
            let package = Package(
                name: "P",
                products: [.library(name: "Lib", targets: ["A"])],
                dependencies: [.package(path: "../Other", traits: ["Fast"])],
                targets: [.target(name: "A", dependencies: ["B"]), .target(name: "B")]
            )
            """])

        #expect(manifests.products["P"] == ["Lib": ["A"]])
        #expect(Set(manifests.targets.keys) == ["P/A", "P/B"])
        #expect(manifests.unreadable == [#"P: .package(path: "../Other", traits: ["Fast"])"#])
    }

    @Test("A product declared in both branches of a condition reaches the targets of both")
    func aProductDeclaredTwiceReachesBothTargets() {
        let manifests = read(["P": """
            #if os(Linux)
            products.append(.library(name: "Lib", targets: ["A"]))
            #else
            products.append(.library(name: "Lib", targets: ["B"]))
            #endif
            targets.append(.target(name: "A"))
            targets.append(.target(name: "B"))
            """])

        #expect(manifests.products["P"]?["Lib"] == ["A", "B"])
        #expect(Set(manifests.reached(from: [.init(name: "Lib", package: "P")]).targets.map(\.name)) == ["A", "B"])
        #expect(manifests.unreadable.isEmpty, "\(manifests.unreadable)")
    }

    @Test("An alias declared in both branches of a condition reaches the products of both")
    func anAliasDeclaredTwiceReachesBothProducts() {
        let manifests = read([
            "P": """
                #if os(Linux)
                let logging = Target.Dependency.product(name: "LogA", package: "Logs")
                #else
                let logging = Target.Dependency.product(name: "LogB", package: "Logs")
                #endif
                products.append(.library(name: "Lib", targets: ["A"]))
                targets.append(.target(name: "A", dependencies: [logging]))
                """,
            "Logs": """
                products.append(.library(name: "LogA", targets: ["LA"]))
                products.append(.library(name: "LogB", targets: ["LB"]))
                targets.append(.target(name: "LA"))
                targets.append(.target(name: "LB"))
                """,
        ])

        #expect(manifests.targets["P/A"]?.products == [.init(name: "LogA", package: "Logs"), .init(name: "LogB", package: "Logs")])
        #expect(Set(manifests.reached(from: [.init(name: "Lib", package: "P")]).targets.map(\.name)) == ["A", "LA", "LB"])
        #expect(manifests.unreadable.isEmpty, "\(manifests.unreadable)")
    }

    @Test("A test target is not reported: it is never in a build that ships")
    func aTestTargetIsNotReported() {
        let manifests = read(["P": """
            targets.append(.target(name: "A"))
            targets.append(.testTarget(name: "ATests", dependencies: ["A"]))
            """])

        #expect(manifests.unreadable.isEmpty, "\(manifests.unreadable)")
    }

    @Test("A declaration with white space before its parenthesis is read as one without", arguments: [" ", "\n    ", "\t  "])
    func aDeclarationWithWhiteSpaceBeforeItsParenthesisIsRead(space: String) {
        let manifests = read(["P": """
            products.append(.library\(space)(name: "Lib", targets: ["A"]))
            #if os(Linux)
            targets.append(.target(name: "A"))
            #else
            targets.append(.target\(space)(name: "A", dependencies: ["B", .product\(space)(name: "C", package: "Other")]))
            #endif
            targets.append(.target(name: "B", path: "Sources/library target"))
            """])

        #expect(Set(manifests.reached(from: [.init(name: "Lib", package: "P")]).targets.map(\.name)) == ["A", "B"])
        #expect(manifests.targets["P/A"]?.products == [.init(name: "C", package: "Other")])
        #expect(manifests.unreadable.isEmpty, "\(manifests.unreadable)")
    }

    @Test("A carriage return ends a comment and a line, as it does for the compiler", arguments: ["\r\n", "\r"])
    func aCarriageReturnEndsACommentAndALine(end: String) {
        let manifests = read(["P": """
            products.append(.library(name: "Lib", targets: ["A"]))
            targets.append(.target(name: "A", dependencies: ["B"]))
            let names = ["A"] // note\(end)targets.append(.target(name: "C"))
            targets.append(.target(name: "B"))
            """])

        #expect(manifests.targets["P/C"] != nil)
        #expect(manifests.unreadable.isEmpty, "\(manifests.unreadable)")
    }

    // MARK: What it reports

    @Test("A shape the reader does not follow is reported, so the checks fail instead of scanning less")
    func shapesTheReaderDoesNotFollowAreReported() {
        let manifests = read(["P": """
            let shared = [Target.Dependency.target(name: "B")]
            let more: [Target.Dependency] = [.product(name: "C", package: "Other")]
            products.append(.library(name: libraryName, targets: ["A"]))
            targets.append(.target(name: "A", dependencies: [unknownAlias, .product(name: productName, package: "Other"), "B"]))
            targets.append(.target(name: "B", dependencies: shared))
            targets.append(.target(name: names[2]))
            targets.append(.target(name: targetName))
            targets.append(.target(name: "C", path: folder))
            targets.append(.target(name: ""))
            targets.append(.target(name: "../D"))
            """])

        #expect(Set(manifests.unreadable) == [
            #"P: .library(name: libraryName, targets: ["A"])"#,
            "P: unknownAlias",
            #"P: .product(name: productName, package: "Other")"#,
            "P: B dependencies: shared",
            "P: targets.append(.target(name: names[2]))",
            "P: .target(name: targetName)",
            "P: .target(name: \"C\", path: folder)",
            #"P: .target(name: "")"#,
            #"P: .target(name: "../D")"#,
        ])
        #expect(manifests.targets["P/A"]?.targets == ["B"], "What it does follow is still read")
        #expect(manifests.targets["P/B"] != nil, "A target whose dependencies it cannot read is still scanned")
    }

    @Test("An alias declared once as a product and once another way is reported where it is used, not read as the product")
    func anAliasDeclaredAnotherWayInOneBranchIsReported() {
        let manifests = read(["P": """
            #if os(Linux)
            let logging = Target.Dependency.product(name: "Log", package: "Logs")
            #else
            let logging = Target.Dependency.target(name: "B")
            #endif
            targets.append(.target(name: "A", dependencies: [logging]))
            targets.append(.target(name: "B"))
            """])

        #expect(manifests.unreadable == ["P: logging"])
        #expect(manifests.targets["P/A"]?.products == [])
    }

    @Test("A target kind the reader does not follow is reported, even beside a target it reads in the other branch", arguments: [
        "executableTarget", "macro", "plugin", "binaryTarget", "systemLibrary",
    ])
    func aTargetKindTheReaderDoesNotFollowIsReported(kind: String) {
        let manifests = read(["P": """
            #if os(Linux)
            targets.append(.target(name: "A"))
            #else
            targets.append(.\(kind)(name: "A", dependencies: ["B"]))
            #endif
            targets.append(.target(name: "B"))
            """])

        #expect(manifests.unreadable == ["P: .\(kind)(name: \"A\", dependencies: [\"B\"])"])
    }

    @Test("A product the reader does not follow is reported", arguments: [
        #".executable(name: "Tool", targets: ["A"])"#,
        #".plugin(name: "Gen", targets: ["A"])"#,
        #".library(name: "Lib", targets: ["A"], extra: "x")"#,
        #".library(name: "Lib", targets: ["A", other])"#,
        #".library(name: "Lib", targets: names)"#,
    ])
    func aProductTheReaderDoesNotFollowIsReported(declaration: String) {
        let manifests = read(["P": """
            products.append(\(declaration))
            targets.append(.target(name: "A"))
            """])

        #expect(manifests.unreadable == ["P: \(declaration)"])
    }

    @Test("A label the reader does not follow is reported, and the target is still scanned", arguments: [
        (#"targets.append(.target(name: "A", swiftSettings: [.define("DEBUG")]))"#, #"A swiftSettings: [.define("DEBUG")]"#),
        (#"targets.append(.target(name: "A", plugins: [.plugin(name: "Gen")]))"#, #"A plugins: [.plugin(name: "Gen")]"#),
        (
            #"targets.append(.target(name: "A", dependencies: [.product(name: "C", package: "Other", moduleAliases: nil)]))"#,
            #".product(name: "C", package: "Other", moduleAliases: nil)"#
        ),
        (#"targets.append(.target(name: "A", path: "Sources/A", path: "Sources/B"))"#, #"A path: "Sources/B""#),
        (#"targets.append(.target(name: "A", "B"))"#, #"A "B""#),
        (#"targets.append(.target(name: "A", dependencies: [.target(name: "B", platforms: [.iOS])]))"#, #".target(name: "B", platforms: [.iOS])"#),
    ])
    func aLabelTheReaderDoesNotFollowIsReported(line: String, reported: String) {
        let manifests = read(["P": """
            products.append(.library(name: "Lib", targets: ["A"]))
            \(line)
            targets.append(.target(name: "B"))
            """])

        #expect(manifests.unreadable == ["P: \(reported)"])
        #expect(manifests.targets["P/A"] != nil)
    }

    @Test("A package setting the reader does not follow is reported", arguments: [
        (
            #"let package = Package(name: "P", traits: [.default(enabledTraits: ["Fast"])], targets: targets)"#,
            #"Package traits: [.default(enabledTraits: ["Fast"])]"#
        ),
        (#"dependencies.append(.package(path: "../Other", traits: ["Fast"]))"#, #".package(path: "../Other", traits: ["Fast"])"#),
    ])
    func aPackageSettingTheReaderDoesNotFollowIsReported(line: String, reported: String) {
        let manifests = read(["P": """
            targets.append(.target(name: "A"))
            \(line)
            """])

        #expect(manifests.unreadable == ["P: \(reported)"])
    }

    @Test("A target changed after its declaration is reported, so a dependency added later is never missed", arguments: [
        #"a.dependencies.append("B")"#,
        #"a.dependencies += ["B"]"#,
        #"a.dependencies = ["B"]"#,
    ])
    func aTargetChangedAfterItsDeclarationIsReported(change: String) {
        let manifests = read(["P": """
            let a: Target = .target(name: "A")
            targets.append(a)
            \(change)
            products.append(.library(name: "Lib", targets: ["A"]))
            targets.append(.target(name: "B"))
            """])

        #expect(manifests.unreadable == ["P: \(change)"])
        #expect(manifests.targets["P/A"] != nil)
    }

    @Test("A statement outside the grammar is reported as the lines that hold it", arguments: [
        (#"a.path = "Elsewhere""#, [#"a.path = "Elsewhere""#]),
        (#"targets[0].dependencies += ["B"]"#, [#"targets[0].dependencies += ["B"]"#]),
        (#"for t in targets { t.dependencies.append("B") }"#, [#"for t in targets { t.dependencies.append("B") }"#]),
        ("for t in targets {\n    t.dependencies.append(\"B\")\n}", [#"for t in targets { t.dependencies.append("B") }"#]),
        (#"func add() { targets.append(.target(name: "C")) }"#, [#"func add() { targets.append(.target(name: "C")) }"#]),
        (#"print("x"); targets.append(.target(name: "C"))"#, [#"print("x"); targets.append(.target(name: "C"))"#]),
        (#"targets.append(.target(name: "C")); targets.removeAll()"#, [#"targets.append(.target(name: "C")); targets.removeAll()"#]),
        ("let pair = (targets.removeAll(), 1).1", ["let pair = (targets.removeAll(), 1).1"]),
        (
            #"targets.append(.target(name: "C", resources: [(targets.removeAll(), .copy("x")).1]))"#,
            [#"targets.append(.target(name: "C", resources: [(targets.removeAll(), .copy("x")).1]))"#]
        ),
        ("import Foundation", ["import Foundation"]),
        (#"let names = targets.map(\.name)"#, [#"let names = targets.map(\.name)"#]),
        ("let kept = targets\n    .filter { $0.name != \"A\" }", [#".filter { $0.name != "A" }"#]),
        ("let all = targets\n    + others", ["+ others"]),
        ("targets = []", ["targets = []"]),
        ("targets.removeAll()", ["targets.removeAll()"]),
        ("targets.removeLast(count)", ["targets.removeLast(count)"]),
        (")", [")"]),
        ("let names = [\n    \"A\"\n    .appending(\"B\")\n]", [#"let names = [ "A" .appending("B") ]"#]),
        ("targets.append(.target(name: \"C\"\n    .lowercased()))", [#"targets.append(.target(name: "C" .lowercased()))"#]),
        (#"#warning("check")"#, [#"#warning("check")"#]),
        ("#if os(Linux)\n#else targets.removeAll()\n#endif", ["#else targets.removeAll()"]),
        ("#if os(Linux) || os(\n    iOS)\n#endif", ["#if os(Linux) || os( iOS)"]),
        ("#if os(Linux) ||\n    os(iOS)\n#endif", ["#if os(Linux) ||", "os(iOS)"]),
        ("#if os(Linux) /* note */ || os(iOS)\n#endif", ["#if os(Linux) /* note */ || os(iOS)"]),
    ])
    func aStatementOutsideTheGrammarIsReported(statement: String, reported: [String]) {
        let manifests = read(["P": """
            let a: Target = .target(name: "A")
            targets.append(a)
            products.append(.library(name: "Lib", targets: ["A"]))
            \(statement)
            targets.append(.target(name: "B"))
            """])

        #expect(manifests.unreadable == reported.map { "P: \($0)" })
        #expect(manifests.targets["P/B"] != nil)
    }

    @Test("A declaration word written in a shape the reader does not follow is reported, even beside a target it reads in the other branch", arguments: [
        "targets.append(.`target`(name: \"A\", dependencies: [\"B\"]))",
        "targets.append(.target/* note */(name: \"A\", dependencies: [\"B\"]))",
        "let make = Target.target\nmake(name: \"A\", dependencies: [\"B\"])",
    ])
    func aDeclarationWordInAShapeTheReaderDoesNotFollowIsReported(shape: String) {
        let manifests = read(["P": """
            #if os(Linux)
            targets.append(.target(name: "A"))
            #else
            \(shape)
            #endif
            targets.append(.target(name: "B"))
            """])

        #expect(manifests.unreadable == shape.split(separator: "\n").map { "P: \(folded(String($0)))" })
    }

    @Test("A string, a comment, a regex literal, a slash or a backtick the reader does not follow is reported, so no declaration on its line or after it is skipped", arguments: [
        #"let folder = "Sources\\""#,
        ##"let flag = #"a"b"#"##,
        "let note = \"\"\"\n    let say = \"hi\n    \"\"\"",
        #"let note = 1 /* say "hi */"#,
        #"let name = "\(prefix)C""#,
        ##"let pattern = #/a"b"c/#"##,
        #"let pattern = /"/"#,
        #"let first = /"/; targets.append(.target(name: "C")); let second = /"/"#,
        "let half = width / 2",
        #"let `a"b` = 1; targets.append(.target(name: "C")); let `c"d` = 2"#,
        #"let `x//` = 1; targets.append(.target(name: "C"))"#,
    ])
    func aStringOrACommentTheReaderDoesNotFollowIsReported(line: String) {
        let manifests = read(["P": """
            products.append(.library(name: "Lib", targets: ["A"]))
            targets.append(.target(name: "A", dependencies: ["B"]))
            \(line)
            targets.append(.target(name: "B", dependencies: [.product(name: "C", package: "Other")]))
            """])

        for part in line.split(separator: "\n") {
            #expect(manifests.unreadable.contains("P: \(folded(String(part)))"), "\(manifests.unreadable)")
        }
        #expect(manifests.targets["P/B"] != nil)
    }

    @Test("A line with a character outside printable ASCII is reported, so a quote joined to a combining mark hides no declaration", arguments: [
        "let first = \"\u{301}\"; targets.append(.target(name: \"C\")); let second = \"\u{301}\"",
        "targets.append(.target(name: \"C\")) // é",
        "let café = [\"C\"]",
    ])
    func aLineWithACharacterOutsidePrintableASCIIIsReported(line: String) {
        let manifests = read(["P": """
            products.append(.library(name: "Lib", targets: ["A"]))
            targets.append(.target(name: "A", dependencies: ["B"]))
            \(line)
            targets.append(.target(name: "B", dependencies: [.product(name: "C", package: "Other")]))
            """])

        #expect(manifests.unreadable == ["P: \(folded(line))"])
    }

    @Test("The same text reported twice is listed once")
    func aLineFoundByTwoRulesIsReportedOnce() {
        let manifests = read(["P": """
            #if os(Linux)
            targets.append(.target(name: "A", dependencies: [unknownAlias]))
            #else
            targets.append(.target(name: "A", dependencies: [unknownAlias]))
            #endif
            """])

        #expect(manifests.unreadable == ["P: unknownAlias"])
    }
}
