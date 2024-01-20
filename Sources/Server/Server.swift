import Log
import FileSystem

@_exported import Storage

public class Server {
    let storage: SharedStorage
    var binaryServer: BinaryServer?
    var httpServer: HTTPServer?

    var onError: (Swift.Error) async -> Void = { error in
        await Log.critical(String(describing: error))
    }

    enum Error: String, Swift.Error {
        case binaryServerIsRunning = "binary server is already running"
        case httpServerIsRunning = "http server is already running"
    }

    public init(for storage: SharedStorage) throws {
        self.storage = storage
        self.httpServer = nil
        self.binaryServer = nil
    }

    public func restore() async throws {
        try await storage.restore()
    }

    public func startBinaryServer(
        at host: String = "127.0.0.1",
        on port: Int = 16180
    ) async throws {
        guard self.binaryServer == nil else {
            throw Error.binaryServerIsRunning
        }
        let binaryServer = try BinaryServer(for: storage, at: host, on: port)
        _ = Task.detached {
            do {
                try await binaryServer.start()
            } catch {
                await self.onError(error)
            }
        }
        self.binaryServer = binaryServer
    }

    public func startHTTPServer(
        at host: String = "127.0.0.1",
        on port: Int = 1618
    ) async throws {
        guard self.httpServer == nil else {
            throw Error.httpServerIsRunning
        }
        let httpServer = try HTTPServer(for: storage, at: host, on: port)
        _ = Task.detached {
            do {
                try await httpServer.start()
            } catch {
                await self.onError(error)
            }
        }
        self.httpServer = httpServer
    }
}
