import JSON
import File
import Stream

public final class JsonCoder: StreamCoder, StreamAnyDecoder {
    var typeAccessor: TypeAccessor

    public init(typeAccessor: @escaping TypeAccessor) {
        self.typeAccessor = typeAccessor
    }

    enum Error: Swift.Error {
        case invalidFormat
    }

    func read<T>(
        from reader: StreamReader,
        _ body: () throws -> T?) throws -> T?
    {
        do {
            let next = try body()
            guard try reader.consume(.lf) else {
                throw Error.invalidFormat
            }
            return next
        } catch let error as StreamError where error == .insufficientData {
            return nil
        }
    }

    public func next<T: AnyDecodable>(from reader: StreamReader) throws -> T? {
        return try read(from: reader) {
            return try JSON.withScopedDecoder(using: reader) { decoder in
                return try T(from: decoder, typeAccessor: typeAccessor)
            }
        }
    }

    public func next<T: Decodable>(
        _ type: T.Type,
        from reader: StreamReader) throws -> T?
    {
        return try read(from: reader) {
            return try JSON.decode(type, from: reader)
        }
    }

    public func next(
        _ type: Decodable.Type,
        from reader: StreamReader) throws -> Decodable?
    {
        return try read(from: reader) {
            return try JSON.decode(decodable: type, from: reader)
        }
    }

    public func write(_ record: Encodable, to writer: StreamWriter) throws {
        try JSON.encode(encodable: record, to: writer)
        try writer.write(.lf)
    }
}

fileprivate extension UInt8 {
    static let lf = UInt8(ascii: "\n")
}
