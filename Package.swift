// swift-tools-version:5.4
import PackageDescription

let package = Package(
    name: "Storage",
    products: [
        .library(
            name: "Server",
            targets: ["Server"]),
        .library(
            name: "Storage",
            targets: ["Storage"]),
    ],
    dependencies: [
        .package(name: "Async"),
        .package(name: "Time"),
        .package(name: "AIO"),
        .package(name: "JSON"),
        .package(name: "MessagePack"),
        .package(name: "Fiber"),
        .package(name: "HTTP"),
        .package(name: "Log"),
        .package(name: "Test")
    ],
    targets: [
        .target(
            name: "Server",
            dependencies: [
                "Storage",
                "Time",
                .product(name: "File", package: "AIO"),
                "Log",
                "HTTP",
                "MessagePack"
            ],
            swiftSettings: [
                .unsafeFlags(["-Xfrontend", "-enable-experimental-concurrency"])
            ]),
        .target(
            name: "Storage",
            dependencies: [
                "Async",
                "Fiber",
                .product(name: "File", package: "AIO"),
                "Time",
                "JSON",
                "MessagePack"
            ],
            swiftSettings: [
                .unsafeFlags(["-Xfrontend", "-enable-experimental-concurrency"])
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
            dependencies: [.init(stringLiteral: target), "Event", "Test"],
            path: "Tests/\(target)/\(name)",
            swiftSettings: [
                .unsafeFlags(["-Xfrontend", "-enable-experimental-concurrency"])
            ]))
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

        static var `default`: Self { .local }

        var baseUrl: String {
            switch self {
            case .local: return "../"
            case .remote: return "https://swiftstack.io/"
            case .github: return "https://github.com/swift-stack/"
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
            : .package(name: name, url: source.url(for: name), .branch("dev"))
    }
}
