// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TranscriptCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "TranscriptCore", targets: ["TranscriptCore"])
    ],
    targets: [
        .target(name: "TranscriptCore"),
        .testTarget(name: "TranscriptCoreTests", dependencies: ["TranscriptCore"])
    ],
    swiftLanguageModes: [.v5]
)
