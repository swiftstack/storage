import Log
import HTTP

final class HTTPServer {
    var server: HTTP.Server
    var storage: SharedStorage

    init(for storage: SharedStorage, at host: String, on port: Int) throws {
        self.storage = storage
        self.server = try HTTP.Server(host: host, port: port)
        self.server.route(get: "/call/:string", to: httpHandler)
        self.server.route(post: "/call/:string", to: httpHandler)
    }

    func start() async throws {
        try await server.start()
    }

    struct Error: Encodable, Swift.Error {
        let error: String

        init(_ error: CustomStringConvertible) {
            self.error = error.description
        }

        init<T: RawRepresentable>(_ error: T) where T.RawValue == String {
            self.error = error.rawValue
        }
    }

    func httpHandler(
        request: Request,
        function: String
    ) async throws -> Response {
        do {
            let decoder = try await HTTP.Coder.getDecoder(for: request)
            guard let result = try await storage.call(function, using: decoder)
            else {
                return Response(status: .noContent)
            }
            return try Response(body: result)
        } catch {
            return try await handleError(error)
        }
    }

    func handleError(_ error: Swift.Error) async throws -> Response {
        switch error {
        case let error as Storage.Error:
            return try Response(
                status: .badRequest,
                body: Error(error))
        case let error as Storage.ContainerError:
            await Log.error("[http] storage error: \(error)")
            return try Response(
                status: .badRequest,
                body: Error(error))
        case let error as StoredProcedures.Error:
            switch error {
            case .notFound: return Response(status: .noContent)
            case .missingDecoder: return Response(status: .badRequest)
            }
        case let error as DecodingError:
            await Log.error("[http] decoding error: \(error)")
            return Response(status: .badRequest)
        default:
            await Log.error("[http] unhandled exception: \(error)")
            return Response(status: .internalServerError)
        }
    }
}
