import Test
import IPC
import HTTP
import Event
import FileSystem

@testable import Server

struct Test: Codable, Equatable, Entity {
    let id: String
    let name: String
}

func createStorage(at path: Path) async throws -> SharedStorage {
    let storage = try Storage(at: path)
    let container = try storage.container(for: Test.self)
    try container.insert(Test(id: "1", name: "test"))

    struct Arguments: Decodable {
        let username: String
    }

    let shared = SharedStorage(for: storage)
    await shared.registerProcedure(
        name: "test",
        arguments: Arguments.self,
        requires: Test.self
    ) { arguments, container in
        let name = arguments.username
        return container.first(where: \.name, equals: name)
    }
    return shared
}

test("HTTPHandler") {
    Task {
        await scope {
            try await withTempPath { path in
                let storage = try await createStorage(at: path)

                let server = try HTTPServer(
                    for: storage,
                    at: "127.0.0.1",
                    on: 4001)
                let request = Request(
                    url: "/call/test?username=test",
                    method: .get)
                let response = try await server.httpHandler(
                    request: request,
                    function: "test")
                let body = try await response.readBody(as: UTF8.self)
                expect(body == "{\"id\":\"1\",\"name\":\"test\"}")
                let user = try await HTTP.Coder
                    .decode(Test.self, from: response)
                expect(user == Test(id: "1", name: "test"))
            }
        }

        await loop.terminate()
    }

    await loop.run()
}

test("HTTPFullStask") {
    let condition = Condition()

    Task {
        await scope {
            try await withTempPath { path in
                let storage = try await createStorage(at: path)

                let server = try HTTPServer(
                    for: storage,
                    at: "127.0.0.1",
                    on: 4002)

                await condition.notify()

                try await server.start()
            }
        }
    }

    Task {
        await condition.wait()

        await scope {
            let client = HTTP.Client(host: "127.0.0.1", port: 4002)
            let response = try await client
                .get(path: "/call/test?username=test")
            let body = try await response.readBody(as: UTF8.self)
            expect(body == "{\"id\":\"1\",\"name\":\"test\"}")
            let user = try await HTTP.Coder
                .decode(Test.self, from: response)
            expect(user == Test(id: "1", name: "test"))
        }

        await loop.terminate()
    }

    await loop.run()
}

await run()
