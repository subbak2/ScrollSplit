// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ScrollSplit",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ScrollSplit",
            path: "Sources/ScrollSplit",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
        .testTarget(
            name: "ScrollSplitTests",
            dependencies: ["ScrollSplit"],
            path: "Tests/ScrollSplitTests"
        ),
    ]
)
