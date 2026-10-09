// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Times",
    platforms: [.macOS("15.0")],
    targets: [
        .executableTarget(name: "Times", path: "Sources/Times")
    ]
)
