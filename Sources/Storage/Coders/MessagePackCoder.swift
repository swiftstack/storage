import Stream
import FileSystem
import MessagePack

final class MessagePackCoder: StreamCoder {
    func next<T>(_ type: T.Type, from reader: StreamReader) async throws -> T?
        where T: Decodable
    {
        do {
            return try await MessagePack.decode(type, from: reader)
        } catch let error as StreamError where error == .insufficientData {
            return nil
        }
    }

    func write<T>(_ record: T, to writer: StreamWriter) async throws
        where T: Encodable
    {
        try await MessagePack.encode(encodable: record, to: writer)
    }
}
