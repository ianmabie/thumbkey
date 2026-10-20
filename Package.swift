// swift-tools-version: 6.2
import PackageDescription
let package = Package(name: "ThumbKey", platforms: [.macOS(.v14)], products: [.executable(name: "ThumbKey", targets: ["ThumbKey"])], targets: [
    .target(name: "ThumbKeyCore"),
    .executableTarget(name: "ThumbKey", dependencies: ["ThumbKeyCore"]),
    .testTarget(name: "ThumbKeyCoreTests", dependencies: ["ThumbKeyCore"]),
    .testTarget(name: "ThumbKeyRuntimeTests", dependencies: ["ThumbKey", "ThumbKeyCore"])
], swiftLanguageModes: [.v5])
