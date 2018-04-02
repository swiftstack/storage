import File
import Stream

class DecodingIterator<T: AnyDecodable>: IteratorProtocol {
    let decoder: StreamAnyDecoder
    let source: StreamReader

    init(from file: File, using decoder: StreamAnyDecoder) throws {
        self.decoder = decoder
        self.source = try file.open(flags: [.read]).inputStream
    }

    func next() -> T? {
        do {
            return try decoder.next(from: source)
        } catch {
            return nil
        }
    }
}
