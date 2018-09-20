import File
import JSON
import Stream

struct WAL {
    struct Record {
        enum Action: String, Codable {
            case upsert
            case remove
        }
        let key: Storage.Key
        let action: Action
        let object: Codable
    }

    enum Error: Swift.Error {
        case closed
        case cantDecode
        case cantEncode
        case cantOpenLog
    }

    class Writer {
        let file: File
        let encoder: StreamEncoder

        var stream: StreamWriter?

        init(to file: File, encoder: StreamEncoder) {
            self.file = file
            self.encoder = encoder
        }

        let types: [Storage.Key : Codable.Type] = [:]

        func open() throws {
            if !Directory.isExists(at: file.location) {
                try Directory.create(at: file.location)
            }
            let stream = try file.open(flags: [.write, .create]).outputStream
            try stream.seek(to: .end)
            self.stream = stream
        }

        func append(_ record: Record) throws {
            guard let stream = stream else {
                throw Error.closed
            }
            try encoder.write(record, to: stream)
        }
    }

    class Reader {
        let file: File
        let decoder: StreamAnyDecoder

        init(from file: File, decoder: StreamAnyDecoder) {
            self.file = file
            self.decoder = decoder
        }

        func makeRecoveryIterator() throws -> DecodingIterator<Record> {
            return try DecodingIterator(from: file, using: decoder)
        }
    }
}
