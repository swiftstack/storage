import Test
import Event
import Stream
import Network
import FileSystem
import MessagePack

@testable import Server

struct Test: Codable, Equatable, Entity {
    let id: String
    let name: String
}

func createStorage(at path: Path) async throws -> SharedStorage {
    let storage = try Storage(at: path)
    let container = try storage.container(for: Test.self)
    try container.insert(Test(id: "1", name: "test"))

    let shared = SharedStorage(for: storage)

    struct Arguments: Decodable {
        let username: String
    }

    await shared.registerProcedure(
        name: "test",
        arguments: Arguments.self,
        requires: Test.self)
    { arguments, con in
        let name = arguments.username
        return container.first(where: \.name, equals: name)
    }
    return shared
}

test.case("BinaryProtocol") {
    asyncTask {
        await scope {
            try await withTempPath(for: "BinaryProtocol") { path in
                let storage = try await createStorage(at: path)

                let server = try BinaryServer(
                    for: storage,
                    at: "127.0.0.1",
                    on: 3001)

                let output = OutputByteStream()

                let request: BinaryProtocol.Request = .rpc(
                    name: "test",
                    arguments: ["username":"test"])
                let result = await server.handle(request)
                try await result.encode(to: output)

                let input = InputByteStream(output.bytes)
                let response = try await BinaryProtocol.Response.decode(from: input)
                guard case .input(let stream) = response else {
                    fail("invalid response")
                    return
                }
                let user = try await MessagePack.decode(Test.self, from: stream)
                expect(user.id == "1")
                expect(user.name == "test")
            }
        }

        await loop.terminate()
    }

    await loop.run()
}

import Darwin

test.case("BinaryFullStack") {
    asyncTask {
        await scope {
            try await withTempPath(for: "BinaryFullStack") { path in
                let storage = try await createStorage(at: path)

                let server = try BinaryServer(
                    for: storage,
                    at: "127.0.0.1",
                    on: 3003)

                try await server.start()
            }
        }
    }

    asyncTask {
        await scope {
            // FIXME:
            usleep(100000)
            let client = Network.Client(host: "127.0.0.1", port: 3003)
            let networkStream = try await client.connect()
            let stream = BufferedStream(baseStream: networkStream)

            let request: BinaryProtocol.Request = .rpc(
                name: "test",
                arguments: ["username":"test"])
            try await request.encode(to: stream)
            try await stream.flush()

            let response = try await BinaryProtocol.Response.decode(from: stream)
            guard case .input(let stream) = response else {
                fail("invalid response")
                return
            }
            let user = try await MessagePack.decode(Test.self, from: stream)
            expect(user == Test(id: "1", name: "test"))
        }

        await loop.terminate()
    }

    await loop.run()
}

test.run()

// FIXME: move to Test
func withTempPath(for case: String, task: (Path) async throws -> Void) async throws {
    let directory = try Directory(at: "/tmp/Tests/Storage/Server/BinaryServer/\(`case`)")
    if directory.isExists {
        try directory.remove()
    }
    try directory.create()
    try await task(directory.path)
    try directory.remove()
}
