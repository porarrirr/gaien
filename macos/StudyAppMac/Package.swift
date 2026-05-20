// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "StudyAppMac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "StudyAppMac", targets: ["StudyAppMac"])
    ],
    targets: [
        .executableTarget(
            name: "StudyAppMac",
            path: "Sources/StudyAppMac"
        )
    ]
)
