// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Locus",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Locus",
            path: "Sources/Locus"
        ),
        .testTarget(
            name: "LocusTests",
            dependencies: ["Locus"],
            path: "Tests/LocusTests"
        ),
    ]
)
