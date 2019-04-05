// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "Storage",
    products: [
        .library(name: "Server", targets: ["Server"]),
        .library(name: "Storage", targets: ["Storage"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/swift-stack/async.git",
            .branch("master")),
        .package(
            url: "https://github.com/swift-stack/time.git",
            .branch("master")),
        .package(
            url: "https://github.com/swift-stack/aio.git",
            .branch("master")),
        .package(
            url: "https://github.com/swift-stack/json.git",
            .branch("master")),
        .package(
            url: "https://github.com/swift-stack/messagepack.git",
            .branch("master")),
        .package(
            url: "https://github.com/swift-stack/fiber.git",
            .branch("master")),
        .package(
            url: "https://github.com/swift-stack/http.git",
            .branch("master")),
        .package(
            url: "https://github.com/swift-stack/log.git",
            .branch("master")),
        .package(
            url: "https://github.com/swift-stack/test.git",
            .branch("master"))
    ],
    targets: [
        .target(
            name: "Server",
            dependencies: [
                "Storage",
                "Time",
                "File",
                "Log",
                "HTTP",
                "MessagePack"
            ]),
        .target(
            name: "Storage",
            dependencies: [
                "Async",
                "Fiber",
                "File",
                "Time",
                "JSON",
                "MessagePack"
            ]),
        .testTarget(
            name: "StorageServerTests",
            dependencies: ["Test", "Server", "Fiber"]),
        .testTarget(
            name: "StorageTests",
            dependencies: ["Test", "Storage"]),
    ]
)
