import Stream
import MessagePack

enum BinaryProtocol {
    enum Error: UInt8, Swift.Error {
        case invalidRequest = 1
        case invalidRequestType = 2
        case functionNotFound = 3
        case unknown = 4

        init(from stream: StreamReader) throws {
            let type = try stream.read(UInt8.self)
            guard let rawType = Error(rawValue: type) else {
                throw Error.invalidRequest
            }
            self = rawType
        }

        func encode(to stream: StreamWriter) throws {
            try stream.write(self.rawValue)
        }
    }

    enum Request {
        case rpc(name: String, arguments: MessagePack)

        enum RawType: UInt8 {
            case rpc = 1

            init(from stream: StreamReader) throws {
                let type = try stream.read(UInt8.self)
                guard let rawType = RawType(rawValue: type) else {
                    throw Error.invalidRequestType
                }
                self = rawType
            }

            func encode(to stream: StreamWriter) throws {
                try stream.write(rawValue)
            }
        }

        init(from stream: StreamReader) throws {
            let type = try RawType(from: stream)
            switch type {
            case .rpc:
                var reader = MessagePackReader(stream)
                let name = try reader.decode(String.self)
                let arguments = try reader.decode()
                self = .rpc(name: name, arguments: arguments)
            }
        }

        func encode(to stream: StreamWriter) throws {
            switch self {
            case let .rpc(name, arguments):
                try RawType.rpc.encode(to: stream)
                var writer = MessagePackWriter(stream)
                try writer.encode(name)
                try writer.encode(arguments)
            }
        }
    }

    enum Response {
        case error(Error)
        case input(StreamReader)
        case output((StreamWriter) throws -> Void)

        enum RawType: UInt8 {
            case error = 1
            case object = 2

            init(from stream: StreamReader) throws {
                let type = try stream.read(UInt8.self)
                guard let rawType = RawType(rawValue: type) else {
                    throw Error.invalidRequestType
                }
                self = rawType
            }

            func encode(to stream: StreamWriter) throws {
                try stream.write(rawValue)
            }
        }

        init(from stream: StreamReader) throws {
            let type = try RawType(from: stream)
            switch type {
            case .error:
                let error = try Error(from: stream)
                self = .error(error)
            case .object:
                self = .input(stream)
            }
        }

        func encode(to stream: StreamWriter) throws {
            switch self {
            case .error(let error):
                try stream.write(RawType.error.rawValue)
                try error.encode(to: stream)
            case .output(let output):
                try stream.write(RawType.object.rawValue)
                try output(stream)
            default:
                throw Error.invalidRequestType
            }
        }
    }
}
