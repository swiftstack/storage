import Stream
import FileSystem
import MessagePack

final class MessagePackCoder: StreamCoder {
    func next<T: Decodable>(
        _ type: T.Type,
        from reader: StreamReader
    ) async throws -> T? {
        do {
            return try await MessagePack.decode(type, from: reader)
        } catch let error as StreamError where error == .insufficientData {
            return nil
        }
    }

    func write<T: Encodable>(
        _ record: T,
        to writer: StreamWriter
    ) async throws {
        try await MessagePack.encode(encodable: record, to: writer)
    }
}
