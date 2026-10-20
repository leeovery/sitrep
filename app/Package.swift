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
        .executableTarget(name: "SitRep", dependencies: ["SitRepCore", "SitRepPanel", "SitRepEdge"]),
        .testTarget(name: "SitRepCoreTests", dependencies: ["SitRepCore"]),
        .testTarget(name: "SitRepPanelTests", dependencies: ["SitRepPanel"], resources: [.copy("Recorded")]),
        .testTarget(name: "SitRepEdgeTests", dependencies: ["SitRepEdge", "SitRepCore", "SitRepPanel"]),
        .testTarget(name: "SitRepTests", dependencies: ["SitRep", "SitRepEdge", "SitRepPanel"]),
    ],
    swiftLanguageModes: [.v6]
)
