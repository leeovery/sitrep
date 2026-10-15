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
        .executableTarget(name: "SitRep", dependencies: ["SitRepCore", "SitRepPanel"]),
        .testTarget(name: "SitRepCoreTests", dependencies: ["SitRepCore"]),
        .testTarget(name: "SitRepPanelTests", dependencies: ["SitRepPanel"]),
    ],
    swiftLanguageModes: [.v6]
)
