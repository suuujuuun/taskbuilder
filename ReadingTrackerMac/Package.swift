// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ReadingTrackerMac",
    platforms: [
        .macOS(.v14) // Requires macOS 14 for SwiftData
    ],
    products: [
        .executable(name: "ReadingTrackerMac", targets: ["ReadingTrackerMac"])
    ],
    targets: [
        .executableTarget(
            name: "ReadingTrackerMac",
            path: ".",
            exclude: []
        )
    ]
)
