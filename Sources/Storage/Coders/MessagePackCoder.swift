import File
import Stream
import MessagePack

final class MessagePackCoder: StreamCoder, StreamAnyDecoder {
    var typeAccessor: TypeAccessor

    init(typeAccessor: @escaping TypeAccessor) {
        self.typeAccessor = typeAccessor
    }

    func withDecoder<T>(
        from reader: StreamReader,
        _ body: (Swift.Decoder) throws -> T?) throws -> T?
    {
        do {
            let reader = reader as! BufferedInputStream<File>
            let messagePack = try MessagePack.decode(from: reader)
            let decoder = _MessagePackDecoder(messagePack)
            return try body(decoder)
        } catch let error as StreamError where error == .insufficientData {
            return nil
        }
    }

    func next<T: AnyDecodable>(from reader: StreamReader) throws -> T? {
        return try withDecoder(from: reader) { decoder in
            return try T(from: decoder, typeAccessor: typeAccessor)
        }
    }

    func next<T: Decodable>(
        _ type: T.Type,
        from reader: StreamReader) throws -> T?
    {
        return try withDecoder(from: reader) { decoder in
            return try T(from: decoder)
        }
    }

    func next(
        _ type: Decodable.Type,
        from reader: StreamReader) throws -> Decodable?
    {
        return try withDecoder(from: reader) { decoder in
            try type.init(from: decoder)
        }
    }

    func write(_ record: Encodable, to writer: StreamWriter) throws {
        let encoder = MessagePackEncoder()
        let packed = try encoder.encode(record)
        let writer = writer as! BufferedOutputStream<File>
        try MessagePack.encode(packed, to: writer)
    }
}
