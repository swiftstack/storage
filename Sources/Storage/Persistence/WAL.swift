import File
import Stream

struct WAL {
    enum Record<T: Entity>: Equatable {
        enum Action: String, Codable {
            case upsert
            case delete
        }
        case upsert(T)
        case delete(T.Key)
    }

    enum Error: Swift.Error {
        case cantDecode
        case cantEncode
        case cantOpenLog
    }

    class Reader<T: Entity> {
        let stream: StreamReader
        let decoder: StreamDecoder

        init(from stream: StreamReader, decoder: StreamDecoder) {
            self.stream = stream
            self.decoder = decoder
        }

        convenience
        init(from file: File, decoder: StreamDecoder) throws {
            let file = try file.open(flags: .read)
            self.init(from: file.inputStream, decoder: decoder)
        }

        func readNext() throws -> Record<T>? {
            return try decoder.next(Record<T>.self, from: stream)
        }
    }

    class Writer<T: Entity> {
        var stream: StreamWriter
        let encoder: StreamEncoder

        init(to stream: StreamWriter, encoder: StreamEncoder) {
            self.stream = stream
            self.encoder = encoder
        }

        convenience
        init(to file: File, encoder: StreamEncoder) throws {
            if !Directory.isExists(at: file.location) {
                try Directory.create(at: file.location)
            }
            let stream = try file.open(flags: [.write, .create]).outputStream
            try stream.seek(to: .end)
            self.init(to: stream, encoder: encoder)
        }

        func append(_ record: Record<T>) throws {
            try encoder.write(record, to: stream)
        }

        func flush() throws {
            try stream.flush()
        }
    }
}
