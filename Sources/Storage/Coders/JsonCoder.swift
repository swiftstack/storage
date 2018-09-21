import JSON
import File
import Stream

public final class JsonCoder: StreamCoder {
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

    public func next<T>(
        _ type: T.Type,
        from reader: StreamReader) throws -> T?
        where T: Decodable
    {
        return try read(from: reader) {
            return try JSON.decode(type, from: reader)
        }
    }

    public func write<T>(_ record: T, to writer: StreamWriter) throws
        where T: Encodable
    {
        try JSON.encode(encodable: record, to: writer)
        try writer.write(.lf)
    }
}

fileprivate extension UInt8 {
    static let lf = UInt8(ascii: "\n")
}
