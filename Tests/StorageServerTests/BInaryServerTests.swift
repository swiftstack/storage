import Test
import File
import Fiber
import Stream
import MessagePack

@testable import Async
@testable import Server

final class BinaryServerTests: TestCase {
    let temp = Path(string: "/tmp/BinaryServerTests")

    override func setUp() {
        async.setUp(Fiber.self)
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

                let storage = try Storage(at: self.temp.appending(#function))
                let container = try storage.container(for: Test.self)
                try container.insert(Test(id: "1", name: "test"))
                storage.registerFunction(name: "test") { arguments in
                    guard let name = arguments["username"] else {
                        throw "zero arguments"
                    }
                    return container.first(where: \.name, equals: name)
                }

                let server = try BinaryServer(
                    for: storage,
                    at: "localhost",
                    on: 3001)

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
}
