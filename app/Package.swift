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
        .executableTarget(name: "SitRep", dependencies: ["SitRepCore"]),
        .testTarget(name: "SitRepCoreTests", dependencies: ["SitRepCore"]),
    ],
    swiftLanguageModes: [.v6]
)
