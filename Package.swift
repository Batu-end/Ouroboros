// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Ouroboros",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "OuroborosKit"),
        .executableTarget(name: "Ouroboros", dependencies: ["OuroborosKit"]),
        .testTarget(name: "OuroborosKitTests", dependencies: ["OuroborosKit"]),
    ]
)
