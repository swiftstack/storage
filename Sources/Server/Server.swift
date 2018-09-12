import Log
import File
import Async

import HTTP
import Stream
import Network
import MessagePack

@_exported import Storage

public typealias StoredProcedure = ([String : String]) throws -> Encodable

public class Server {
    let storage: Storage
    var functions: [String: StoredProcedure]

    var binaryServer: Network.Server?
    var httpServer: HTTP.Server?

    public init(
        at path: Path,
        functions: [String: StoredProcedure] = [:]) throws
    {
        self.storage = try Storage(at: path)
        self.functions = functions
        self.httpServer = nil
        self.binaryServer = nil
    }

    public func createBinaryServer(
        at host: String = "localhost",
        on port: Int = 16180) throws
    {
        let server = try Network.Server(host: host, port: port)
        server.onClient = binaryHandler
        server.onError = onError
        binaryServer = server
    }

    public func createHTTPServer(
        at host: String = "localhost",
        on port: Int = 1618) throws
    {
        let server = try HTTP.Server(host: host, port: port)
        server.route(get: "/call/:string", to: httpHandler)
        httpServer = server
    }

    public func registerFunction(
        name: String,
        body: @escaping StoredProcedure)
    {
        functions[name] = body
    }

    func binaryHandler(_ socket: Socket) {
        do {
            let stream = NetworkStream(socket: socket)
            let input = BufferedInputStream(
                baseStream: stream,
                capacity: 4096,
                expandable: true)
            let output = BufferedOutputStream(baseStream: stream)
            try handleBinaryConnection(input: input, output: output)
        } catch {
            onError(error)
        }
    }

    func handleBinaryConnection(
        input: StreamReader,
        output: StreamWriter) throws
    {
        while try input.cache(count: 1) {
            let request = try BinaryProtocol.Request(from: input)
            let response = handle(request)
            try response.encode(to: output)
        }
        try output.flush()
    }

    func handle(_ request: BinaryProtocol.Request) -> BinaryProtocol.Response {
        switch request {
        case .rpc(let name, let arguments):
            switch self.functions[name] {
            case .some(let function):
                return .output { writer in
                    let result = try function(arguments)
                    try MessagePack.encode(encodable: result, to: writer)
                }
            case .none:
                return .error(.functionNotFound)
            }
        }
    }

    func httpHandler(
        request: Request,
        functionName: String) throws -> Response
    {
        guard let function = self.functions[functionName] else {
            throw HTTP.Error.notFound
        }
        let object = try function(request.url.query?.values ?? [:])
        return try Response(body: object)
    }

    public func start() throws {
        async.task { [unowned self] in
            do {
                try self.binaryServer?.start()
            } catch {
                self.onError(error)
            }
        }
        async.task { [unowned self] in
            do {
                try self.httpServer?.start()
            } catch {
                self.onError(error)
            }
        }
    }

    func onError(_ error: Swift.Error) {
        Log.critical(String(describing: error))
    }
}
