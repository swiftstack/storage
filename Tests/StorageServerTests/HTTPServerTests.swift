import Test
import HTTP
import Fiber
import FileSystem

@testable import Async
@testable import Server

final class HTTPServerTests: TestCase {
    let temp = try! Path("/tmp/HTTPServerTests")

    override func setUp() {
        async.setUp(Fiber.self)
    }

    override func tearDown() {
        try? Directory.remove(at: temp)
    }

    struct Test: Codable, Equatable, Entity {
        let id: String
        let name: String
    }

    func createStorage(at path: Path) throws -> SharedStorage {
        let storage = try Storage(at: path)
        let container = try storage.container(for: Test.self)
        try container.insert(Test(id: "1", name: "test"))

        struct Arguments: Decodable {
            let username: String
        }
        let shared = SharedStorage(for: storage)
        shared.registerProcedure(
            name: "test",
            arguments: Arguments.self,
            requires: Test.self)
        { arguments, container in
            let name = arguments.username
            return container.first(where: \.name, equals: name)
        }
        return shared
    }

    func testHTTPHandler() {
        async.task { [unowned self] in
            defer { async.loop.terminate() }
            scope {
                let path = try self.temp.appending(#function)
                let storage = try self.createStorage(at: path)

                let server = try HTTPServer(
                    for: storage,
                    at: "127.0.0.1",
                    on: 4001)
                let request = Request(
                    url: "/call/test?username=test",
                    method: .get)
                let response = try server.httpHandler(
                    request: request,
                    function: "test")
                expect(response.string == "{\"id\":\"1\",\"name\":\"test\"}")
                let user = try HTTP.Coder.decode(Test.self, from: response)
                expect(user == Test(id: "1", name: "test"))
            }
        }

        async.loop.run()
    }

    func testHTTPFullStask() {
        let serverStarted = Channel<Bool>(capacity: 1)

        async.task { [unowned self] in
            scope {
                let path = try self.temp.appending(#function)
                let storage = try self.createStorage(at: path)

                let server = try HTTPServer(
                    for: storage,
                    at: "127.0.0.1",
                    on: 4002)

                serverStarted.write(true)

                try server.start()
            }
        }

        async.task {
            defer { async.loop.terminate() }
            _ = serverStarted.read()
            scope {
                let client = HTTP.Client(host: "127.0.0.1", port: 4002)
                let response = try client.get(path: "/call/test?username=test")
                expect(response.string == "{\"id\":\"1\",\"name\":\"test\"}")
                let user = try HTTP.Coder.decode(Test.self, from: response)
                expect(user == Test(id: "1", name: "test"))
            }
        }

        async.loop.run()
    }
}
