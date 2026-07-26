// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CleanKit",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "CleanKit", targets: ["CleanKit"]),
        .executable(name: "cruft", targets: ["cruft-cli"]),
        .executable(name: "CruftApp", targets: ["CruftApp"]),
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.1.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
    ],
    targets: [
        .target(
            name: "CleanKit",
            dependencies: ["Yams"],
            resources: [.copy("Rules/Resources/rules.yaml")]
        ),
        .executableTarget(
            name: "cruft-cli",
            dependencies: [
                "CleanKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .executableTarget(
            name: "CruftApp",
            dependencies: ["CleanKit"],
            exclude: ["Info.plist"]
        ),
        .testTarget(name: "CleanKitTests", dependencies: ["CleanKit"]),
        .testTarget(name: "CruftAppTests", dependencies: ["CruftApp"]),
    ]
)
