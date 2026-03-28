// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "UCBuddy",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "UCBuddy",
            path: "Sources/UCBuddy",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "UCBuddyTests",
            dependencies: ["UCBuddy"],
            path: "Tests/UCBuddyTests"
        )
    ]
)
