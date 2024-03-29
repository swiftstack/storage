import Test
import IPC
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
        requires: Test.self
    ) { arguments, _ in
        let name = arguments.username
        return container.first(where: \.name, equals: name)
    }
    return shared
}

test("BinaryProtocol") {
    Task {
        await scope {
            try await withTempPath { path in
                let storage = try await createStorage(at: path)

                let server = try BinaryServer(
                    for: storage,
                    at: "127.0.0.1",
                    on: 3001)

                let output = OutputByteStream()

                let request: BinaryProtocol.Request = .rpc(
                    name: "test",
                    arguments: ["username": "test"])
                let result = await server.handle(request)
                try await result.encode(to: output)

                let input = InputByteStream(output.bytes)
                let response = try await BinaryProtocol.Response
                    .decode(from: input)
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

test("BinaryFullStack") {
    let condition = Condition()

    Task {
        await scope {
            try await withTempPath { path in
                let storage = try await createStorage(at: path)

                let server = try BinaryServer(
                    for: storage,
                    at: "127.0.0.1",
                    on: 3003)

                await condition.notify()

                try await server.start()
            }
        }
    }

    Task {
        await condition.wait()

        await scope {
            let client = TCP.Client(host: "127.0.0.1", port: 3003)
            let networkStream = try await client.connect()
            let stream = BufferedStream(baseStream: networkStream)

            let request: BinaryProtocol.Request = .rpc(
                name: "test",
                arguments: ["username": "test"])
            try await request.encode(to: stream)
            try await stream.flush()

            let response = try await BinaryProtocol.Response
                .decode(from: stream)
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

await run()
