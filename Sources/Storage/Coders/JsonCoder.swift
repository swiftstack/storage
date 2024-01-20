import JSON
import Stream
import FileSystem

public final class JsonCoder: StreamCoder {
    enum Error: Swift.Error {
        case invalidFormat
    }

    func read<T>(
        from reader: StreamReader,
        _ body: () async throws -> T?
    ) async throws -> T? {
        do {
            let next = try await body()
            guard try await reader.consume(.lf) else {
                throw Error.invalidFormat
            }
            return next
        } catch let error as StreamError where error == .insufficientData {
            return nil
        }
    }

    public func next<T: Decodable>(
        _ type: T.Type,
        from reader: StreamReader
    ) async throws -> T? {
        try await read(from: reader) {
            try await JSON.decode(type, from: reader)
        }
    }

    public func write<T: Encodable>(
        _ record: T,
        to writer: StreamWriter
    ) async throws {
        try await JSON.encode(encodable: record, to: writer)
        try await writer.write(.lf)
    }
}

fileprivate extension UInt8 {
    static let lf = UInt8(ascii: "\n")
}
