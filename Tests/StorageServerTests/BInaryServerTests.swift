import Test
import Async
import Stream
import FileSystem
import MessagePack

@testable import Server

final class BinaryServerTests: TestCase {
    let temp = try! Path("/tmp/BinaryServerTests")

    override func tearDown() {
        try? Directory.remove(at: temp)
    }

    func testBinaryProtocol() {
        struct Test: Codable, Equatable, Entity {
            let id: String
            let name: String
        }

        async {
            defer { loop.terminate() }
            scope {
                let request: BinaryProtocol.Request = .rpc(
                    name: "test",
                    arguments: ["username":"test"])

                let storage = try Storage(at: self.temp.appending(#function))
                let container = try storage.container(for: Test.self)
                try container.insert(Test(id: "1", name: "test"))

                let shared = SharedStorage(for: storage)

                struct Arguments: Decodable {
                    let username: String
                }

                shared.registerProcedure(
                    name: "test",
                    arguments: Arguments.self,
                    requires: Test.self)
                { arguments, con in
                    let name = arguments.username
                    return container.first(where: \.name, equals: name)
                }



                let server = try BinaryServer(
                    for: shared,
                    at: "127.0.0.1",
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
                expect(user.id == "1")
                expect(user.name == "test")
            }
        }

        loop.run()
    }
}
