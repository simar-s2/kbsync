// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "kbsync",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "KBSyncCore"),
        .executableTarget(name: "kbsync", dependencies: ["KBSyncCore"]),
        .testTarget(name: "KBSyncCoreTests", dependencies: ["KBSyncCore"]),
    ]
)
