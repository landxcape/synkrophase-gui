// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "SynkroGui",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "SynkroGui",
            targets: ["SynkroGui"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "SynkroGui",
            dependencies: [],
            path: "Sources/SynkroGui"
        ),
        .testTarget(
            name: "SynkroGuiTests",
            dependencies: ["SynkroGui"],
            path: "Tests/SynkroGuiTests"
        )
    ]
)
