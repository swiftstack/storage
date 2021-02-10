import Stream
import MessagePack

enum BinaryProtocol {
    enum Error: UInt8, Swift.Error {
        case invalidRequest = 1
        case invalidRequestType = 2
        case functionNotFound = 3
        case unknown = 4

        static func decode(from stream: StreamReader) async throws -> Self {
            let type = try await stream.read(UInt8.self)
            guard let rawType = Error(rawValue: type) else {
                throw Error.invalidRequest
            }
            return rawType
        }

        func encode(to stream: StreamWriter) async throws {
            try await stream.write(self.rawValue)
        }
    }

    enum Request {
        case rpc(name: String, arguments: MessagePack)

        enum RawType: UInt8 {
            case rpc = 1

            static func decode(from stream: StreamReader) async throws -> Self {
                let type = try await stream.read(UInt8.self)
                guard let rawType = RawType(rawValue: type) else {
                    throw Error.invalidRequestType
                }
                return rawType
            }

            func encode(to stream: StreamWriter) async throws {
                try await stream.write(rawValue)
            }
        }

        static func decode(from stream: StreamReader) async throws -> Self {
            let type = try await RawType.decode(from: stream)
            switch type {
            case .rpc:
                var reader = MessagePackReader(stream)
                let name = try await reader.decode(String.self)
                let arguments = try await reader.decode()
                return .rpc(name: name, arguments: arguments)
            }
        }

        func encode(to stream: StreamWriter) async throws {
            switch self {
            case let .rpc(name, arguments):
                try await RawType.rpc.encode(to: stream)
                var writer = MessagePackWriter(stream)
                try await writer.encode(name)
                try await writer.encode(arguments)
            }
        }
    }

    enum Response {
        case error(Error)
        case input(StreamReader)
        case output((StreamWriter) async throws -> Void)

        enum RawType: UInt8 {
            case error = 1
            case object = 2

            static func decode(from stream: StreamReader) async throws -> Self {
                let type = try await stream.read(UInt8.self)
                guard let rawType = RawType(rawValue: type) else {
                    throw Error.invalidRequestType
                }
                return rawType
            }

            func encode(to stream: StreamWriter) async throws {
                try await stream.write(rawValue)
            }
        }

        static func decode(from stream: StreamReader) async throws -> Self {
            let type = try await RawType.decode(from: stream)
            switch type {
            case .error:
                let error = try await Error.decode(from: stream)
                return .error(error)
            case .object:
                return .input(stream)
            }
        }

        func encode(to stream: StreamWriter) async throws {
            switch self {
            case .error(let error):
                try await stream.write(RawType.error.rawValue)
                try await error.encode(to: stream)
            case .output(let output):
                try await stream.write(RawType.object.rawValue)
                try await output(stream)
            default:
                throw Error.invalidRequestType
            }
        }
    }
}
