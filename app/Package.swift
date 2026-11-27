// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SitRep",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "SitRep", targets: ["SitRep"]),
        .executable(name: "SitRepNotices", targets: ["SitRepNotices"]),
    ],
    targets: [
        .target(name: "SitRepCore"),
        /// Where a session's windows show on this Mac, and the jump to one: the seat, the multiplexer adapters, the
        /// three states, the terminal drivers and the front.
        .target(name: "SitRepScreen", dependencies: ["SitRepCore"]),
        .target(name: "SitRepPanel"),
        /// The relay between SitRep and its notices helper, which both link.
        .target(name: "SitRepRelay"),
        .target(name: "SitRepEdge", dependencies: ["SitRepCore", "SitRepPanel"]),
        .target(name: "SitRepMenu", dependencies: ["SitRepCore", "SitRepPanel", "SitRepEdge", "SitRepRelay"]),
        .executableTarget(
            name: "SitRep",
            dependencies: ["SitRepCore", "SitRepScreen", "SitRepPanel", "SitRepEdge", "SitRepMenu", "SitRepRelay"]
        ),
        /// The notices helper, inside SitRep.app: macOS's notifications and the relay, and nothing of SitRep's own.
        .executableTarget(name: "SitRepNotices", dependencies: ["SitRepRelay"]),
        /// What the real CLI printed over a board seeded in a scratch folder, for the tests to read.
        .target(name: "SitRepLines", path: "Tests/SitRepLines", resources: [.copy("Printed")]),
        /// What the tests share, of no target of the app's: defaults held in memory, a clock the test moves, the bounded
        /// waits, the backstop every suite carries, the lines of `sitrep watch`, typed, the names no test may use, and
        /// the tag of the tests that lean on this Mac.
        .target(name: "SitRepTestSupport", path: "Tests/SitRepTestSupport"),
        /// `claude plugin`'s lists in the shape this Mac printed them, read-only, for the plugin's setup.
        .testTarget(
            name: "SitRepCoreTests", dependencies: ["SitRepCore", "SitRepLines", "SitRepTestSupport"],
            resources: [.copy("Claude")]
        ),
        .testTarget(
            name: "SitRepPanelTests", dependencies: ["SitRepPanel", "SitRepTestSupport"],
            resources: [.copy("Recorded")]
        ),
        .testTarget(
            name: "SitRepEdgeTests",
            dependencies: [
                "SitRepEdge", "SitRepCore", "SitRepPanel", "SitRepLines", "SitRepTestSupport",
            ]
        ),
        .testTarget(
            name: "SitRepMenuTests",
            dependencies: [
                "SitRepMenu", "SitRepEdge", "SitRepCore", "SitRepPanel", "SitRepRelay", "SitRepLines",
                "SitRepTestSupport",
            ]
        ),
        .testTarget(
            name: "SitRepTests",
            dependencies: [
                "SitRep", "SitRepEdge", "SitRepPanel", "SitRepMenu", "SitRepCore", "SitRepRelay", "SitRepScreen", "SitRepLines",
                "SitRepTestSupport",
            ]
        ),
        .testTarget(name: "SitRepNoticesTests", dependencies: ["SitRepNotices", "SitRepRelay", "SitRepTestSupport"]),
        .testTarget(name: "SitRepScreenTests", dependencies: ["SitRepScreen", "SitRepCore", "SitRepTestSupport"]),
    ],
    swiftLanguageModes: [.v6]
)
