import Log
import Async
import FileSystem

@_exported import Storage

public class Server {
    let storage: SharedStorage
    var binaryServer: BinaryServer?
    var httpServer: HTTPServer?

    var onError: (Swift.Error) -> Void = { error in
        Log.critical(String(describing: error))
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

    public func restore() throws {
        try storage.restore()
    }

    public func startBinaryServer(
        at host: String = "127.0.0.1",
        on port: Int = 16180) throws
    {
        guard self.binaryServer == nil else {
            throw Error.binaryServerIsRunning
        }
        let binaryServer = try BinaryServer(for: storage, at: host, on: port)
        async.task { [unowned self] in
            do {
                try binaryServer.start()
            } catch {
                self.onError(error)
            }
        }
        self.binaryServer = binaryServer
    }

    public func startHTTPServer(
        at host: String = "127.0.0.1",
        on port: Int = 1618) throws
    {
        guard self.httpServer == nil else {
            throw Error.httpServerIsRunning
        }
        let httpServer = try HTTPServer(for: storage, at: host, on: port)
        async.task { [unowned self] in
            do {
                try httpServer.start()
            } catch {
                self.onError(error)
            }
        }
        self.httpServer = httpServer
    }
}
