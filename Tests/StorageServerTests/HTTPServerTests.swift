import Test
import File
import HTTP
import Fiber

@testable import Async
@testable import Server

final class HTTPServerTests: TestCase {
    let temp = Path(string: "/tmp/HTTPServerTests")

    override func setUp() {
        async.setUp(Fiber.self)
    }

    override func tearDown() {
        try? Directory.remove(at: temp)
    }

    func testHTTPHandler() {
        struct Test: Codable, Equatable, Entity {
            let id: String
            let name: String
        }

        async.task { [unowned self] in
            defer { async.loop.terminate() }
            scope {
                let storage = try Storage(at: self.temp.appending(#function))
                let container = try storage.container(for: Test.self)
                try container.insert(Test(id: "1", name: "test"))
                storage.registerFunction(name: "test") { arguments in
                    guard let name = arguments["username"] else {
                        throw "zero arguments"
                    }
                    return container.first(where: \.name, equals: name)
                }
                let server = try HTTPServer(
                    for: storage,
                    at: "localhost",
                    on: 4001)
                let request = Request(
                    url: "/call/test?username=test",
                    method: .get)
                let response = try server.httpHandler(
                    request: request,
                    function: "test")
                assertEqual(response.string, "{\"id\":\"1\",\"name\":\"test\"}")
                let user = try HTTP.Coder.decodeModel(Test.self, from: response)
                assertEqual(user, Test(id: "1", name: "test"))
            }
        }

        async.loop.run()
    }

    func testHTTPFullStask() {
        struct Test: Codable, Equatable, Entity {
            let id: String
            let name: String
        }

        let serverStarted = Channel<Bool>(capacity: 1)

        async.task { [unowned self] in
            scope {
                let storage = try Storage(at: self.temp.appending(#function))
                let container = try storage.container(for: Test.self)
                try container.insert(Test(id: "1", name: "test"))

                storage.registerFunction(name: "test") { arguments in
                    guard let name = arguments["username"] else {
                        throw "zero arguments"
                    }
                    return container.first(where: \.name, equals: name)
                }

                let server = try HTTPServer(
                    for: storage,
                    at: "localhost",
                    on: 4002)

                serverStarted.write(true)

                try server.start()
            }
        }

        async.task {
            defer { async.loop.terminate() }
            _ = serverStarted.read()
            scope {
                let client = HTTP.Client(host: "localhost", port: 4002)
                let response = try client.get(path: "/call/test?username=test")
                assertEqual(response.string, "{\"id\":\"1\",\"name\":\"test\"}")
                let user = try HTTP.Coder.decodeModel(Test.self, from: response)
                assertEqual(user, Test(id: "1", name: "test"))
            }
        }

        async.loop.run()
    }
}
