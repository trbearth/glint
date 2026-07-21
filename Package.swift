// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Glint",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "glint", targets: ["Glint"])],
    targets: [
        .executableTarget(name: "Glint", path: "Sources/Glint"),
        .testTarget(name: "GlintTests", dependencies: ["Glint"], path: "Tests/GlintTests")
    ]
)
