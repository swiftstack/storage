import Test
import File
import HTTP
import Fiber
import Stream
import MessagePack
import struct Foundation.UUID

@testable import Async
@testable import Server

extension String: Swift.Error {}

final class ServerTests: TestCase {
    let temp = Path(string: "/tmp/ServerTests")

    override func setUp() {
        async.setUp(Fiber.self)
    }

    func testServer() {
        scope {
            assertNotNil(try Server(at: temp.appending(#function)))
        }
    }

    func testBinaryProtocol() {
        struct Test: Codable, Equatable, Entity {
            let id: String
            let name: String
        }

        async.task {
            defer { async.loop.terminate() }
            scope {
                let request: BinaryProtocol.Request = .rpc(
                    name: "test",
                    arguments: ["username":"test"])

                let server = try Server(at: self.temp.appending(#function))
                let container = try server.storage.container(for: Test.self)
                try container.insert(Test(id: "1", name: "test"))

                server.registerFunction(name: "test") { arguments in
                    guard let name = arguments["username"] else {
                        throw "zero arguments"
                    }
                    return container.first(where: \.name, equals: name)
                }
                let output = OutputByteStream()

                let result = server.handle(request)
                try result.encode(to: output)

                let input = InputByteStream(output.bytes)
                let response = try BinaryProtocol.Response(from: input)
                guard case .input(let stream) = response else {
                    fail("invalid response")
                    return
                }
                let user = try MessagePack.decode(Test.self, from: stream)
                assertEqual(user.id, "1")
                assertEqual(user.name, "test")
            }
        }

        async.loop.run()
    }

    func testHTTPHandler() {
        struct Test: Codable, Equatable, Entity {
            let id: String
            let name: String
        }

        scope {
            let server = try Server(at: temp.appending(#function))
            let container = try server.storage.container(for: Test.self)
            try container.insert(Test(id: "1", name: "test"))

            server.registerFunction(name: "test") { arguments in
                guard let name = arguments["username"] else {
                    throw "zero arguments"
                }
                return container.first(where: \.name, equals: name)
            }

            let request = Request(url: "/call/test?username=test", method: .get)
            let response = try server.httpHandler(
                request: request,
                function: "test")
            assertEqual(response.string, "{\"id\":\"1\",\"name\":\"test\"}")
            let user = try HTTP.Coder.decodeModel(Test.self, from: response)
            assertEqual(user, Test(id: "1", name: "test"))
        }
    }

    func testHTTPFullStask() {
        struct Test: Codable, Equatable, Entity {
            let id: String
            let name: String
        }

        let serverStarted = Channel<Bool>(capacity: 1)

        async.task { [unowned self] in
            scope {
                let server = try Server(at: self.temp.appending(#function))
                try server.createHTTPServer(at: "localhost", on: 2000)

                let container = try server.storage.container(for: Test.self)
                try container.insert(Test(id: "1", name: "test"))

                server.registerFunction(name: "test") { arguments in
                    guard let name = arguments["username"] else {
                        throw "zero arguments"
                    }
                    return container.first(where: \.name, equals: name)
                }

                serverStarted.write(true)

                try server.start()
            }
        }

        async.task {
            defer { async.loop.terminate() }
            _ = serverStarted.read()  
            scope {
                let client = HTTP.Client(host: "localhost", port: 2000)
                let response = try client.get(path: "/call/test?username=test")
                assertEqual(response.string, "{\"id\":\"1\",\"name\":\"test\"}")
                let user = try HTTP.Coder.decodeModel(Test.self, from: response)
                assertEqual(user, Test(id: "1", name: "test"))
            }
        }

        async.loop.run()
    }
}
