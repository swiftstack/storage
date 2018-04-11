// swift-tools-version:4.2
import PackageDescription

let package = Package(
    name: "Storage",
    products: [
        .library(name: "Storage", targets: ["Storage"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/swift-stack/reflection.git",
            .branch("master")),
        .package(
            url: "https://github.com/swift-stack/async.git",
            .branch("master")),
        .package(
            url: "https://github.com/swift-stack/time.git",
            .branch("master")),
        .package(
            url: "https://github.com/swift-stack/file.git",
            .branch("master")),
        .package(
            url: "https://github.com/swift-stack/json.git",
            .branch("master")),
        .package(
            url: "https://github.com/swift-stack/messagepack.git",
            .branch("master")),
        .package(
            url: "https://github.com/swift-stack/test.git",
            .branch("master"))
    ],
    targets: [
        .target(
            name: "Storage",
            dependencies: [
                "Reflection",
                "Async",
                "File",
                "Time",
                "JSON",
                "MessagePack"
            ]),
        .testTarget(
            name: "StorageTests",
            dependencies: ["Test", "Storage"]),
    ]
)
