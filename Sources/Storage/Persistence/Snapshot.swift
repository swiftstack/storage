import Stream
import FileSystem

struct Snapshot {
    struct Header: Codable {
        let name: Storage.Key
        let count: Int
    }

    class Reader<T: Entity> {
        let stream: StreamReader
        let decoder: StreamDecoder

        init(from stream: StreamReader, decoder: StreamDecoder) throws {
            self.stream = stream
            self.decoder = decoder
        }

        convenience
        init(from file: File, decoder: StreamDecoder) throws {
            let file = try file.open(flags: .read)
            try self.init(from: file.inputStream, decoder: decoder)
        }

        func readHeader() async throws -> Header? {
            try await decoder.next(Header.self, from: stream)
        }

        func readNext() async throws -> T? {
            try await decoder.next(T.self, from: stream)
        }
    }

    class Writer<T: Entity> {
        let stream: StreamWriter
        let encoder: StreamEncoder

        init(to stream: StreamWriter, encoder: StreamEncoder) {
            self.stream = stream
            self.encoder = encoder
        }

        convenience
        init(to file: File, encoder: StreamEncoder) throws {
            try file.create()
            let stream = try file.open(flags: [.create, .write]).outputStream
            self.init(to: stream, encoder: encoder)
        }

        func write(header: Header) async throws {
            try await encoder.write(header, to: stream)
        }

        func write(_ value: T) async throws {
            try await encoder.write(value, to: stream)
        }

        func flush() async throws {
            try await stream.flush()
        }
    }
}
