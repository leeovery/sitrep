// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SitRep",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "SitRep", targets: ["SitRep"]),
    ],
    targets: [
        .target(name: "SitRepCore"),
        .target(name: "SitRepPanel"),
        .target(name: "SitRepEdge", dependencies: ["SitRepCore", "SitRepPanel"]),
        .target(name: "SitRepMenu", dependencies: ["SitRepCore", "SitRepPanel", "SitRepEdge"]),
        .target(name: "SitRepWindow", dependencies: ["SitRepCore", "SitRepPanel", "SitRepEdge"]),
        .executableTarget(
            name: "SitRep", dependencies: ["SitRepCore", "SitRepPanel", "SitRepEdge", "SitRepMenu", "SitRepWindow"]
        ),
        /// What the real CLI printed over a board seeded in a scratch folder, for the tests to read.
        .target(name: "SitRepLines", path: "Tests/SitRepLines", resources: [.copy("Printed")]),
        /// What the real `claude plugin` printed on this Mac, read-only, for the plugin's setup.
        .testTarget(name: "SitRepCoreTests", dependencies: ["SitRepCore", "SitRepLines"], resources: [.copy("Claude")]),
        .testTarget(name: "SitRepPanelTests", dependencies: ["SitRepPanel"], resources: [.copy("Recorded")]),
        .testTarget(name: "SitRepEdgeTests", dependencies: ["SitRepEdge", "SitRepCore", "SitRepPanel", "SitRepLines"]),
        .testTarget(
            name: "SitRepMenuTests", dependencies: ["SitRepMenu", "SitRepEdge", "SitRepCore", "SitRepPanel", "SitRepLines"]
        ),
        .testTarget(
            name: "SitRepWindowTests", dependencies: ["SitRepWindow", "SitRepCore", "SitRepPanel", "SitRepLines"]
        ),
        .testTarget(
            name: "SitRepTests",
            dependencies: ["SitRep", "SitRepEdge", "SitRepPanel", "SitRepMenu", "SitRepWindow", "SitRepCore", "SitRepLines"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
