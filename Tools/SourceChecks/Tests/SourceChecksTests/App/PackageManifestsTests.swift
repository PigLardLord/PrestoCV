import Testing

// MARK: - Reading package manifests

/// The reader behind the release checks: what it does not follow must fail those checks, never shrink what they scan.
@Suite("Package manifests")
struct PackageManifestsTests {

    private func read(_ manifests: [String: String]) -> PackageManifests {
        PackageManifests(packages: manifests.keys.sorted()) { manifests[$0] ?? "" }
    }

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
            "Other": #"products.append(.library(name: "Drafting", targets: ["D"])); targets.append(.target(name: "D"))"#,
            "Logs": #"let products = [.library(name: "Log", targets: ["L"]), .library(name: "Trace", targets: ["L"])]; .target(name: "L")"#,
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
            .library(name: "Lib", targets: ["A"])
            .target(name: "A", dependencies: [
                .product(
                    name: "Missing",
                    package: "Nowhere"
                ),
            ])
            """])

        #expect(manifests.reached(from: [.init(name: "Lib", package: "P")]).unresolved == [.init(name: "Missing", package: "Nowhere")])
    }

    @Test("A shape the reader does not follow is reported, so the checks fail instead of scanning less")
    func shapesTheReaderDoesNotFollowAreReported() {
        let manifests = read(["P": """
            let shared = [Target.Dependency.target(name: "B")]
            .library(name: libraryName, targets: ["A"])
            .target(name: "A", dependencies: [unknownAlias, .product(name: productName, package: "Other"), "B"])
            .target(name: "B", dependencies: shared)
            .target(name: names[2])
            """])

        #expect(manifests.unreadable.count == 5, "\(manifests.unreadable)")
        #expect(manifests.unreadable.contains { $0.contains("unknownAlias") })
        #expect(manifests.unreadable.contains { $0.contains("productName") })
        #expect(manifests.unreadable.contains { $0.contains("libraryName") })
        #expect(manifests.unreadable.contains { $0.contains("names[2]") })
        #expect(manifests.targets["P/A"]?.targets == ["B"], "What it does follow is still read")
        #expect(manifests.targets["P/B"] != nil, "A target whose dependencies it cannot read is still scanned")
    }

    @Test("A target named as a dependency inside another declaration does not replace the target's own declaration")
    func aTargetNamedAsADependencyIsNotADeclaration() {
        let manifests = read(["P": """
            .target(name: "A", dependencies: ["B"])
            .testTarget(name: "ATests", dependencies: [.target(name: "A"), .target(name: "Fixtures")])
            .target(name: "B")
            """])

        #expect(Set(manifests.targets.keys) == ["P/A", "P/B"])
        #expect(manifests.targets["P/A"]?.targets == ["B"])
    }

    @Test("A target declared in both branches of a condition keeps the dependencies of both")
    func aTargetDeclaredTwiceKeepsBothDependencies() {
        let manifests = read(["P": """
            #if os(Linux)
            targets.append(.target(name: "A", dependencies: ["B"]))
            #else
            targets.append(.target(name: "A", dependencies: ["C", .target(name: "D", condition: .when(platforms: [.iOS]))]))
            #endif
            """])

        #expect(manifests.targets["P/A"]?.targets == ["B", "C", "D"])
        #expect(manifests.unreadable.isEmpty, "\(manifests.unreadable)")
    }
}
