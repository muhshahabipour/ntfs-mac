// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NTFS",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "NTFSCore", targets: ["NTFSCore"]),
    ],
    targets: [
        .target(name: "NTFSCore"),
        .target(name: "NTFSShared"),
        .executableTarget(name: "NTFSHelper", dependencies: ["NTFSCore", "NTFSShared"]),
        .executableTarget(name: "NTFSApp", dependencies: ["NTFSCore", "NTFSShared"]),
        .testTarget(name: "NTFSCoreTests", dependencies: ["NTFSCore"]),
    ]
)
