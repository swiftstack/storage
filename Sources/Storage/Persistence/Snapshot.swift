import File
import Stream

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

        func readHeader() throws -> Header? {
            return try decoder.next(Header.self, from: stream)
        }

        func readNext() throws -> T? {
            return try decoder.next(T.self, from: stream)
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

        func write(header: Header) throws {
            try encoder.write(header, to: stream)
        }

        func write(_ value: T) throws {
            try encoder.write(value, to: stream)
        }

        func flush() throws {
            try stream.flush()
        }
    }
}
