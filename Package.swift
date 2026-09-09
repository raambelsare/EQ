// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacEQ",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "MacEQ",
            path: "Sources/MacEQ"
        ),
        .testTarget(
            name: "MacEQTests",
            dependencies: ["MacEQ"],
            path: "Tests/MacEQTests"
        )
    ]
)
