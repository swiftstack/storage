// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Storage",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "Server",
            targets: ["Server"]),
        .library(
            name: "Storage",
            targets: ["Storage"]),
    ],
    dependencies: [
        .package(name: "Event"),
        .package(name: "Time"),
        .package(name: "IPC"),
        .package(name: "FileSystem"),
        .package(name: "MessagePack"),
        .package(name: "JSON"),
        .package(name: "HTTP"),
        .package(name: "Log"),
        .package(name: "Test"),
    ],
    targets: [
        .target(
            name: "Server",
            dependencies: [
                .target(name: "Storage"),
                .product(name: "Event", package: "event"),
                .product(name: "Time", package: "time"),
                .product(name: "FileSystem", package: "filesystem"),
                .product(name: "MessagePack", package: "messagepack"),
                .product(name: "HTTP", package: "http"),
                .product(name: "Log", package: "log"),
            ]),
        .target(
            name: "Storage",
            dependencies: [
                .product(name: "IPC", package: "ipc"),
                .product(name: "FileSystem", package: "filesystem"),
                .product(name: "MessagePack", package: "messagepack"),
                .product(name: "Time", package: "time"),
                .product(name: "JSON", package: "json"),
            ]),
    ]
)

// MARK: - tests

testTarget("Server") { test in
    test("BinaryServer")
    test("HTTPServer")
    test("Server")
}

testTarget("Storage") { test in
    test("Container")
    test("SharedStorage")
    test("Storage")
    test("Persistence")
    test("WAL")
}

func testTarget(_ target: String, task: ((String) -> Void) -> Void) {
    task { test in addTest(target: target, name: test) }
}

func addTest(target: String, name: String) {
    package.targets.append(
        .executableTarget(
            name: "Tests/\(target)/\(name)",
            dependencies: [
                .target(name: "Server"),
                .target(name: "Storage"),
                .product(name: "Event", package: "event"),
                .product(name: "IPC", package: "ipc"),
                .product(name: "Test", package: "test"),
            ],
            path: "Tests/\(target)/\(name)"))
}

// MARK: - custom package source

#if canImport(ObjectiveC)
import Darwin.C
#else
import Glibc
#endif

extension Package.Dependency {
    enum Source: String {
        case local, remote, github

        static var `default`: Self { .github }

        var baseUrl: String {
            switch self {
            case .local: return "../"
            case .remote: return "https://swiftstack.io/"
            case .github: return "https://github.com/swiftstack/"
            }
        }

        func url(for name: String) -> String {
            return self == .local
                ? baseUrl + name.lowercased()
                : baseUrl + name.lowercased() + ".git"
        }
    }

    static func package(name: String) -> Package.Dependency {
        guard let pointer = getenv("SWIFTSTACK") else {
            return .package(name: name, source: .default)
        }
        guard let source = Source(rawValue: String(cString: pointer)) else {
            fatalError("Invalid source. Use local, remote or github")
        }
        return .package(name: name, source: source)
    }

    static func package(name: String, source: Source) -> Package.Dependency {
        return source == .local
            ? .package(name: name, path: source.url(for: name))
            : .package(url: source.url(for: name), branch: "dev")
    }
}
