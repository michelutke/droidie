// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Droidie",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "DroidieCore"),
        .executableTarget(name: "Droidie", dependencies: ["DroidieCore"]),
        .testTarget(name: "DroidieCoreTests", dependencies: ["DroidieCore"]),
    ]
)
