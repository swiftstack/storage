import Log
import Stream
import Network
import FileSystem
import MessagePack

final class BinaryServer {
    var server: TCP.Server
    var storage: SharedStorage

    init(for storage: SharedStorage, at host: String, on port: Int) throws {
        self.storage = storage
        self.server = try TCP.Server(host: host, port: port)

    }

    func binaryHandler(_ socket: TCP.Socket) async {
        do {
            let stream = TCP.Stream(socket: socket)
            let input = BufferedInputStream(
                baseStream: stream,
                capacity: 4096,
                expandable: true)
            let output = BufferedOutputStream(baseStream: stream)
            try await handleBinaryConnection(input: input, output: output)
        } catch {
            await onError(error)
        }
    }

    func handleBinaryConnection(
        input: StreamReader,
        output: StreamWriter
    ) async throws {
        while try await input.cache(count: 1) {
            let request = try await BinaryProtocol.Request.decode(from: input)
            let response = await handle(request)
            try await response.encode(to: output)
            try await output.flush()
        }
    }

    func handle(
        _ request: BinaryProtocol.Request
    ) async -> BinaryProtocol.Response {
        do {
            switch request {
            case .rpc(let function, let arguments):
                let decoder = MessagePack.Decoder(arguments)
                let result = try await storage.call(function, using: decoder)
                switch result {
                case .some(let result):
                    return .output({ writer in
                        try await MessagePack.encode(
                            encodable: result,
                            to: writer)
                    })
                case .none:
                    return .error(.functionNotFound)
                }
            }
        } catch {
            return .error(.unknown)
        }
    }

    func start() async throws {
        await server.onClient(binaryHandler)
        await server.onError(onError)
        try await server.start()
    }

    func onError(_ error: Swift.Error) async {
        await Log.critical(String(describing: error))
    }
}
