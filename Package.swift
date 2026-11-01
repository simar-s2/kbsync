// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "kbsync",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "KBSyncCore"),
        .target(name: "KBSyncSystem", dependencies: ["KBSyncCore"]),
        .executableTarget(name: "kbsync", dependencies: ["KBSyncCore", "KBSyncSystem"]),
        .executableTarget(name: "KBSyncApp", dependencies: ["KBSyncCore", "KBSyncSystem"]),
        .testTarget(name: "KBSyncCoreTests", dependencies: ["KBSyncCore"]),
    ]
)
