import File
import Stream

struct Snapshot {
    struct Header: Codable {
        let name: Storage.Key
        let count: Int
    }

    class Reader {
        let stream: StreamReader
        let decoder: StreamDecoder

        init(from stream: StreamReader, decoder: StreamDecoder) throws {
            self.stream = stream
            self.decoder = decoder
        }

        convenience init(from file: File, decoder: StreamDecoder) throws {
            let file = try file.open(flags: .read)
            try self.init(from: file.inputStream, decoder: decoder)
        }

        func readHeader() throws -> Header? {
            return try decoder.next(Header.self, from: stream)
        }

        func readNext(_ type: Decodable.Type) throws -> Decodable? {
            return try decoder.next(type, from: stream)
        }
    }

    class Writer {
        let output: StreamWriter
        let encoder: StreamEncoder

        init(to file: File, encoder: StreamEncoder) throws {
            try file.create()
            let stream = try file.open(flags: [.create, .write]).outputStream
            try stream.seek(to: .end)
            self.output = stream
            self.encoder = encoder
        }

        func write(header: Header) throws {
            try encoder.write(header, to: output)
        }

        func write(_ value: Encodable) throws {
            try encoder.write(value, to: output)
        }

        func flush() throws {
            try output.flush()
        }
    }
}
